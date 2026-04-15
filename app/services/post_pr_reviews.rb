# frozen_string_literal: true

class PostPrReviews
  AI_REVIEWED_LABEL = 'ai-reviewed'

  def initialize(github_repo:, github_token:, pr_number: nil, config: nil, pastel: Pastel.new,
                 spinner_factory: method(:default_spinner))
    @github_repo     = github_repo
    @github_token    = github_token
    @pr_number       = pr_number
    @config          = config
    @pastel          = pastel
    @spinner_factory = spinner_factory
  end

  def call
    raise ArgumentError, '--github-token is required (or set it via `bin/devtool config`)' if @github_token.blank?

    pending = PrReview.for_repo(@github_repo).for_config(@config).pending_submission
    pending = pending.where(pr_number: @pr_number) if @pr_number

    if pending.empty?
      Rails.logger.debug @pastel.yellow('No reviews ready to post.')
      return
    end

    client  = Octokit::Client.new(access_token: @github_token)
    posted  = 0

    ensure_label_exists(client)

    pending.each do |review|
      spinner = @spinner_factory.call("Posting review for PR ##{review.pr_number}: #{review.pr_title&.truncate(50)}...")
      spinner.auto_spin

      begin
        result = client.create_pull_request_review(
          @github_repo,
          review.pr_number,
          body: review.review_body,
          event: 'COMMENT',
          comments: review.inline_comments
        )

        client.add_labels_to_an_issue(@github_repo, review.pr_number, [AI_REVIEWED_LABEL])

        review.update!(review_url: result.html_url, submitted_at: Time.current)
        posted += 1
        spinner.success(@pastel.green("Posted: #{result.html_url}"))
      rescue StandardError => e
        spinner.error(@pastel.red("Failed PR ##{review.pr_number}: #{e.message}"))
      end
    end

    Rails.logger.debug @pastel.bold.green("\n#{posted} PR review(s) posted.\n")
  end

  private

  def ensure_label_exists(client)
    client.label(@github_repo, AI_REVIEWED_LABEL)
  rescue Octokit::NotFound
    client.add_label(@github_repo, AI_REVIEWED_LABEL, '0075ca')
  end

  def default_spinner(msg)
    TTY::Spinner.new("[:spinner] #{msg}", format: :dots)
  end
end
