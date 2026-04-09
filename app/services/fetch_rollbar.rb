# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

class FetchRollbar
  ROLLBAR_API = 'https://api.rollbar.com/api/1'
  MAX_PAGES = 20

  def initialize(token:, days_ago: 7, pastel: Pastel.new, spinner_factory: method(:default_spinner))
    @token = token
    @days_ago = days_ago
    @pastel = pastel
    @spinner_factory = spinner_factory
  end

  # Returns { changed: true/false }
  def call
    raise ArgumentError, '--rollbar-token is required' if @token.blank?

    spinner = @spinner_factory.call("Fetching Rollbar items, last #{@days_ago} days ...")
    spinner.auto_spin

    @rollbar_project ||= rollbar_get('/project')['name']

    cutoff = @days_ago.days.ago
    fetched = fetch_pages(cutoff)
    deduped = deduplicate(fetched)
    changed = persist(deduped, cutoff)

    spinner.success(@pastel.green("Fetched #{deduped.size} items (#{RollbarItem.count} total stored, deduplicated by title)"))
    { changed: changed }
  rescue StandardError => e
    spinner&.error(@pastel.red("Failed: #{e.message}"))
    raise
  end

  private

  def fetch_pages(cutoff)
    cutoff_ts = cutoff.to_i
    fetched = []
    done = false

    (1..MAX_PAGES).each do |page|
      break if done

      items = rollbar_get('/items', status: 'active', order: 'desc', per_page: 100, page: page)['items'] || []
      break if items.empty?

      items.each do |item|
        if item['last_occurrence_timestamp'] < cutoff_ts
          done = true
          break
        end
        fetched << item
      end
    end

    fetched
  end

  def deduplicate(items)
    seen = {}
    items.each do |item|
      existing = seen[item['title']]
      seen[item['title']] = item if existing.nil? || item['last_occurrence_timestamp'] > existing['last_occurrence_timestamp']
    end
    seen.values
  end

  def persist(deduped, cutoff)
    cutoff.to_i
    changed = false

    deduped.each do |raw|
      record = RollbarItem.find_or_initialize_by(rollbar_id: raw['id'])
      old_ts = record.last_occurrence_at&.to_i

      record.assign_attributes(
        title: raw['title'],
        environment: raw['environment'],
        total_occurrences: raw['total_occurrences'],
        last_occurrence_at: Time.zone.at(raw['last_occurrence_timestamp']),
        project: @rollbar_project
      )

      changed = true if record.new_record? || old_ts != raw['last_occurrence_timestamp']
      record.save!
    end

    # Trim records outside the current window
    RollbarItem.where(last_occurrence_at: ...cutoff).destroy_all

    changed
  end

  def rollbar_get(path, params = {})
    uri = URI("#{ROLLBAR_API}#{path}")
    uri.query = URI.encode_www_form(params)
    req = Net::HTTP::Get.new(uri)
    req['X-Rollbar-Access-Token'] = @token

    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
    raise "Rollbar API error: #{res.code} #{res.message}" unless res.is_a?(Net::HTTPSuccess)

    body = JSON.parse(res.body)
    raise "Rollbar API error: #{body['message']}" if body['err'] != 0

    body['result']
  end

  def default_spinner(msg)
    TTY::Spinner.new("[:spinner] #{msg}", format: :dots)
  end
end
