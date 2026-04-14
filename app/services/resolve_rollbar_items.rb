# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

class ResolveRollbarItems
  ROLLBAR_API = 'https://api.rollbar.com/api/1'

  def initialize(github_repo:, github_token:, rollbar_token:, dry_run: false,
                 pastel: Pastel.new, spinner_factory: method(:default_spinner))
    @github_repo     = github_repo
    @github_token    = github_token
    @rollbar_token   = rollbar_token
    @dry_run         = dry_run
    @pastel          = pastel
    @spinner_factory = spinner_factory
  end

  def call
    raise ArgumentError, '--rollbar-token is required' if @rollbar_token.blank?
    raise ArgumentError, '--github-token is required'  if @github_token.blank?
    raise ArgumentError, '--github-repo is required'   if @github_repo.blank?

    owner, repo = @github_repo.split('/')
    raise ArgumentError, "Invalid --github-repo \"#{@github_repo}\". Expected format: owner/repo" unless owner && repo

    client = Octokit::Client.new(access_token: @github_token)

    submitted = GithubIssue.submitted.includes(:rollbar_item)

    if submitted.empty?
      Rails.logger.debug @pastel.yellow('No submitted GitHub issues found.')
      return { resolved: 0, skipped: 0 }
    end

    resolved = 0
    skipped  = 0

    submitted.group_by(&:rollbar_item).each do |rollbar_item, issues|
      any_closed = issues.any? do |issue|
        client.issue("#{owner}/#{repo}", issue.github_issue_number).state == 'closed'
      rescue StandardError
        false
      end

      unless any_closed
        skipped += 1
        next
      end

      if @dry_run
        Rails.logger.debug @pastel.dim("[dry-run] Would resolve: #{rollbar_item.title}")
        resolved += 1
        next
      end

      spinner = @spinner_factory.call("Resolving: #{rollbar_item.title.truncate(60)}...")
      spinner.auto_spin

      begin
        rollbar_patch("/item/#{rollbar_item.rollbar_id}", item: { status: 'resolved' })
        resolved += 1
        spinner.success(@pastel.green("Resolved ##{rollbar_item.rollbar_id}: #{rollbar_item.title.truncate(60)}"))
      rescue StandardError => e
        spinner.error(@pastel.red("Failed: #{e.message}"))
      end
    end

    { resolved: resolved, skipped: skipped }
  end

  private

  def rollbar_patch(path, body)
    uri = URI("#{ROLLBAR_API}#{path}")
    req = Net::HTTP::Patch.new(uri)
    req['X-Rollbar-Access-Token'] = @rollbar_token
    req['Content-Type']           = 'application/json'
    req.body                      = JSON.generate(body)

    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
    raise "Rollbar API error: #{res.code} #{res.message}" unless res.is_a?(Net::HTTPSuccess)

    parsed = JSON.parse(res.body)
    raise "Rollbar API error: #{parsed['message']}" if parsed['err'] != 0

    parsed['result']
  end

  def default_spinner(msg)
    TTY::Spinner.new("[:spinner] #{msg}", format: :dots)
  end
end
