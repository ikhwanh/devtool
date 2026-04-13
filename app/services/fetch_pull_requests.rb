# frozen_string_literal: true

class FetchPullRequests
  def initialize(github_repo:, github_token:, days_ago: 7, pastel: Pastel.new, spinner_factory: method(:default_spinner))
    @github_repo     = github_repo
    @github_token    = github_token
    @days_ago        = days_ago
    @pastel          = pastel
    @spinner_factory = spinner_factory
  end

  # Returns { changed: true/false }
  def call
    raise ArgumentError, '--github-token is required (or set it via `bin/devtool config`)' if @github_token.blank?

    client = Octokit::Client.new(access_token: @github_token)
    cutoff = @days_ago.days.ago

    spinner = @spinner_factory.call("Fetching open pull requests (last #{@days_ago} days)...")
    spinner.auto_spin

    prs = client.pull_requests(@github_repo, state: 'open').select { |pr| pr.created_at >= cutoff }

    queued  = 0
    skipped = 0
    prs.each do |pr|
      if not_ready_for_review?(pr)
        skipped += 1
        next
      end
      next if PrReview.already_reviewed?(repo: @github_repo, pr_number: pr.number, head_sha: pr.head.sha)

      files = client.pull_request_files(@github_repo, pr.number)
      diff_json = files.map { |f| { filename: f.filename, status: f.status, patch: f.patch } }.to_json

      linked_issues_json = fetch_linked_issues(client, pr.body).to_json

      PrReview.create!(
        github_repo:        @github_repo,
        pr_number:          pr.number,
        pr_title:           pr.title,
        pr_body:            pr.body,
        head_sha:           pr.head.sha,
        diff_json:          diff_json,
        linked_issues_json: linked_issues_json
      )
      queued += 1
    end

    # Trim old submitted reviews
    PrReview.for_repo(@github_repo).submitted.older_than(PrReview::RETENTION_PERIOD).destroy_all

    msg = "#{prs.size} open PR(s) found, #{queued} queued for review"
    msg += ", #{skipped} skipped (draft/WIP)" if skipped.positive?
    spinner.success(@pastel.green(msg))
    { changed: queued.positive? }
  rescue StandardError => e
    spinner&.error(@pastel.red("Failed: #{e.message}"))
    raise
  end

  private

  def fetch_linked_issues(client, pr_body)
    return [] if pr_body.blank?

    issue_numbers = pr_body.scan(/(?:closes?|fixes?|resolves?)\s+#(\d+)/i).flatten.map(&:to_i).uniq
    issue_numbers.filter_map do |number|
      issue = client.issue(@github_repo, number)
      { number: issue.number, title: issue.title, body: issue.body }
    rescue Octokit::NotFound
      nil
    end
  end

  def not_ready_for_review?(pr)
    return true if pr.draft
    return true if pr.title.match?(/\A\s*(\[?WIP\]?|WIP:|draft:|bump\s)/i)

    false
  end

  def default_spinner(msg)
    TTY::Spinner.new("[:spinner] #{msg}", format: :dots)
  end
end
