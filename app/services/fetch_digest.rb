# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

class FetchDigest
  ROLLBAR_API = 'https://api.rollbar.com/api/1'
  MAX_PAGES   = 20

  def initialize(days_ago: 1, pastel: Pastel.new, spinner_factory: method(:default_spinner))
    @days_ago        = days_ago
    @pastel          = pastel
    @spinner_factory = spinner_factory
  end

  # Returns { project_name => { rollbar_items: [...], github_issues: [...], assigned_prs: [...] } }
  def call
    projects = Config.all.group_by(&:project).transform_values do |rows|
      rows.to_h { |r| [r.key, r.value] }
    end

    raise 'No projects configured. Run: bin/devtool config --project NAME ...' if projects.empty?

    projects.each_with_object({}) do |(name, cfg), result|
      spinner = @spinner_factory.call("Fetching digest data for #{name}...")
      spinner.auto_spin

      begin
        data           = fetch_project(cfg)
        result[name]   = data
        spinner.success(@pastel.green(
                          "#{name}: #{data[:rollbar_items].size} rollbar item(s), " \
                          "#{data[:github_issues].size} issue(s), " \
                          "#{data[:assigned_prs].size} assigned PR(s)"
                        ))
      rescue StandardError => e
        spinner.error(@pastel.red("#{name}: #{e.message}"))
        result[name] = { error: e.message, rollbar_items: [], github_issues: [], assigned_prs: [] }
      end
    end
  end

  private

  def fetch_project(cfg)
    client = github_client(cfg)
    {
      rollbar_items: fetch_rollbar(cfg),
      github_issues: fetch_github_issues(cfg, client),
      assigned_prs: fetch_assigned_prs(cfg, client)
    }
  end

  # ── Rollbar ──────────────────────────────────────────────────────────────────

  def fetch_rollbar(cfg)
    token = cfg['rollbar_token']
    return [] if token.blank?

    cutoff_ts = @days_ago.days.ago.to_i
    items     = []
    done      = false

    (1..MAX_PAGES).each do |page|
      break if done

      batch = rollbar_get(token, '/items', status: 'active', order: 'desc', per_page: 100, page: page)['items'] || []
      break if batch.empty?

      batch.each do |item|
        if item['last_occurrence_timestamp'] < cutoff_ts
          done = true
          break
        end

        items << {
          id: item['id'],
          title: item['title'],
          environment: item['environment'],
          total_occurrences: item['total_occurrences'],
          last_occurrence_at: Time.zone.at(item['last_occurrence_timestamp']).iso8601
        }
      end
    end

    items
  end

  def rollbar_get(token, path, params = {})
    uri       = URI("#{ROLLBAR_API}#{path}")
    uri.query = URI.encode_www_form(params)
    req       = Net::HTTP::Get.new(uri)
    req['X-Rollbar-Access-Token'] = token

    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
    raise "Rollbar API error: #{res.code} #{res.message}" unless res.is_a?(Net::HTTPSuccess)

    body = JSON.parse(res.body)
    raise "Rollbar API error: #{body['message']}" if body['err'] != 0

    body['result']
  end

  # ── GitHub issues ─────────────────────────────────────────────────────────────

  def fetch_github_issues(cfg, client)
    return [] unless client

    repo   = cfg['github_repo']
    cutoff = @days_ago.days.ago

    client.list_issues(repo, state: 'open', since: cutoff.iso8601, sort: 'updated', direction: 'desc')
          .reject(&:pull_request)
          .map do |i|
            {
              number: i.number,
              title: i.title,
              body: i.body&.truncate(500),
              labels: i.labels.map(&:name),
              url: i.html_url,
              created_at: i.created_at.iso8601,
              updated_at: i.updated_at.iso8601
            }
          end
  rescue Octokit::Error => e
    raise "GitHub issues fetch failed: #{e.message}"
  end

  # ── Assigned PRs ─────────────────────────────────────────────────────────────

  def fetch_assigned_prs(cfg, client)
    return [] unless client

    repo         = cfg['github_repo']
    current_user = client.user.login

    client.pull_requests(repo, state: 'open')
          .select { |pr| pr.requested_reviewers.map(&:login).include?(current_user) }
          .map do |pr|
            {
              number: pr.number,
              title: pr.title,
              author: pr.user.login,
              url: pr.html_url,
              created_at: pr.created_at.iso8601
            }
          end
  rescue Octokit::Error => e
    raise "GitHub PRs fetch failed: #{e.message}"
  end

  # ── Helpers ───────────────────────────────────────────────────────────────────

  def github_client(cfg)
    token = cfg['github_token']
    repo  = cfg['github_repo']
    return nil if token.blank? || repo.blank?

    Octokit::Client.new(access_token: token)
  end

  def default_spinner(msg)
    TTY::Spinner.new("[:spinner] #{msg}", format: :dots)
  end
end
