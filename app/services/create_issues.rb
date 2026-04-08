# frozen_string_literal: true

class CreateIssues
  RETENTION_PERIOD = 30.days

  def initialize(github_repo:, github_token: nil, pastel: Pastel.new, spinner_factory: method(:default_spinner))
    @github_repo = github_repo
    @github_token = github_token || ENV.fetch('GITHUB_TOKEN', nil)
    @pastel = pastel
    @spinner_factory = spinner_factory
  end

  def call
    raise ArgumentError, 'GITHUB_TOKEN env var or --github-token is required' if @github_token.blank?

    owner, repo = @github_repo.split('/')
    raise ArgumentError, "Invalid --github-repo \"#{@github_repo}\". Expected format: owner/repo" unless owner && repo

    # Trim old submitted issues on every run
    GithubIssue.submitted.older_than(RETENTION_PERIOD).destroy_all

    pending = GithubIssue.pending_submission.includes(:rollbar_item)

    if pending.empty?
      Rails.logger.debug @pastel.yellow('No new issues to create (all already submitted to GitHub).')
      return
    end

    client = Octokit::Client.new(access_token: @github_token)
    created = 0

    pending.each do |issue|
      spinner = @spinner_factory.call("Creating: #{issue.title.truncate(60)}...")
      spinner.auto_spin

      begin
        result = client.create_issue(
          "#{owner}/#{repo}",
          issue.title,
          issue.body,
          labels: issue.labels.join(',')
        )

        issue.update!(
          github_issue_url: result.html_url,
          github_issue_number: result.number,
          submitted_at: Time.current
        )
        created += 1
        spinner.success(@pastel.green("Created ##{result.number}: #{result.html_url}"))
      rescue StandardError => e
        spinner.error(@pastel.red("Failed: #{e.message}"))
      end
    end

    Rails.logger.debug @pastel.bold.green("\n#{created} GitHub issue(s) created.\n")
  end

  private

  def default_spinner(msg)
    TTY::Spinner.new("[:spinner] #{msg}", format: :dots)
  end
end
