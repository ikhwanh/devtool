# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

class SelectItems
  SEVERITY_COLORS = { 'high' => :red, 'medium' => :yellow, 'low' => :cyan }.freeze

  def initialize(token: nil, autoselect: false, severity: nil, pastel: Pastel.new,
                 prompt: TTY::Prompt.new, spinner_factory: method(:default_spinner))
    @token = token
    @autoselect = autoselect
    @severity = severity
    @pastel = pastel
    @prompt = prompt
    @spinner_factory = spinner_factory
  end

  def call
    items = RollbarItem.where.not(severity: nil).recent_first.to_a
    display_items(items)
    selected = choose_items(items)

    selected = filter_already_submitted(selected)
    selected = enrich_with_occurrences(selected) if @token.present?

    RollbarItem.transaction do
      RollbarItem.update_all(selected: false)
      RollbarItem.where(id: selected.map(&:id)).update_all(selected: true)
    end
  end

  private

  def display_items(items)
    Rails.logger.debug @pastel.bold("Rollbar Items:\n")

    items.each_with_index do |item, i|
      color = SEVERITY_COLORS.fetch(item.severity, :white)
      date = item.last_occurrence_at&.strftime('%m/%d/%Y') || 'unknown'
      num = @pastel.bold(format('%3d', i + 1))
      badge = @pastel.send(color, "[#{item.severity.upcase}]")
      meta = @pastel.dim("occurrences: #{item.total_occurrences}  env: #{item.environment}  last: #{date}")
      Rails.logger.debug { "  #{num}  #{badge} #{item.title}" }
      Rails.logger.debug { "        #{meta}\n" }
    end
  end

  def choose_items(items)
    if @severity
      selected = items.select { |i| i.severity == @severity }
      Rails.logger.debug @pastel.green("Auto-selected #{selected.size} item(s) with severity \"#{@severity}\".\n")
      selected
    elsif @autoselect
      Rails.logger.debug @pastel.green("Auto-selected all #{items.size} items.\n")
      items
    else
      interactive_select(items)
    end
  end

  def interactive_select(items)
    input = @prompt.ask('Enter item numbers to process (comma-separated, e.g. 1,2,4):') do |q|
      q.validate(
        lambda { |val|
          return true if val.strip.empty?

          nums = val.split(',').map { |s| Integer(s.strip, exception: false) }
          nums.none?(&:nil?) && nums.all? { |n| n.between?(1, items.size) }
        },
        "Please enter valid numbers between 1 and #{items.size}"
      )
    end

    if input.nil? || input.strip.empty?
      Rails.logger.debug @pastel.green("No selection — using all #{items.size} items.\n")
      items
    else
      indices = input.split(',').map { |s| s.strip.to_i - 1 }
      selected = indices.map { |i| items[i] }
      Rails.logger.debug @pastel.green("\nSelected #{selected.size} item(s).\n")
      selected
    end
  end

  def filter_already_submitted(selected)
    before = selected.size
    unsubmitted = selected.reject(&:submitted_to_github?)
    skipped = before - unsubmitted.size
    Rails.logger.debug @pastel.dim("Skipping #{skipped} item(s) already submitted to GitHub.\n") if skipped.positive?
    unsubmitted
  end

  def enrich_with_occurrences(selected)
    spinner = @spinner_factory.call("Fetching occurrence details for #{selected.size} item(s)...")
    spinner.auto_spin

    enriched = selected.map do |item|
      occurrence = fetch_occurrence(item.rollbar_id)
      item.update!(occurrence_data: occurrence) if occurrence
      item
    rescue StandardError => e
      warn "Failed to fetch occurrence for item #{item.rollbar_id}: #{e.message}"
      item
    end

    spinner.success(@pastel.green("Fetched occurrence details for #{selected.size} item(s)."))
    enriched
  end

  def fetch_occurrence(item_id)
    uri = URI('https://api.rollbar.com/api/1/instances')
    uri.query = URI.encode_www_form(item_id: item_id, per_page: 1, order: 'desc')
    req = Net::HTTP::Get.new(uri)
    req['X-Rollbar-Access-Token'] = @token

    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
    return nil unless res.is_a?(Net::HTTPSuccess)

    body = JSON.parse(res.body)
    body.dig('result', 'instances', 0, 'data')
  end

  def default_spinner(msg)
    TTY::Spinner.new("[:spinner] #{msg}", format: :dots)
  end
end
