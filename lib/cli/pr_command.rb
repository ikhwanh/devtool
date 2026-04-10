# frozen_string_literal: true

module CLI
  class PrCommand < Thor
    desc 'review', 'Fetch open PRs, review them via Claude, then post reviews to GitHub'

    method_option :github_repo,      type: :string,  aliases: '--github-repo',
                                     desc: 'GitHub repo in owner/repo format (falls back to config)'
    method_option :github_token,     type: :string,  aliases: '--github-token',
                                     desc: 'GitHub token (falls back to config)'
    method_option :local_repository, type: :string,  aliases: '--local-repository',
                                     desc: 'Path to local repo for source-context enrichment'
    method_option :config,           type: :string,  aliases: '-c',
                                     desc: 'Project config to use (defaults to the project marked as default)'
    method_option :days_ago,         type: :numeric, default: 7,    aliases: '--days-ago',
                                     desc: 'Only review PRs created within this many days (default: 7)'
    method_option :skip_post,        type: :boolean, default: false, aliases: '--skip-post',
                                     desc: 'Generate reviews but do not post them to GitHub'

    def review
      pastel = Pastel.new
      cfg    = load_project_config(options[:config])

      github_repo  = options[:github_repo]      || cfg['github_repo']
      github_token = options[:github_token]     || cfg['github_token']
      local_repo   = options[:local_repository] || cfg['local_repository']

      unless github_repo
        say pastel.red('Error: --github-repo is required (or set it via `bin/devtool config`)')
        exit 1
      end

      say pastel.bold("\nPR Reviewer\n")
      say pastel.dim("  config:      #{options[:config] || Config.default_project || '(none)'}")
      say pastel.dim("  github-repo: #{github_repo}")
      say pastel.dim("  days-ago:    #{options[:days_ago]}")
      say pastel.dim("  local-repo:  #{local_repo}") if local_repo
      say ''

      # Step 1: Fetch open PRs and queue new ones for review
      say pastel.bold("\nStep 1/3 — Fetching open pull requests...\n")
      FetchPullRequests.new(github_repo: github_repo, github_token: github_token, days_ago: options[:days_ago]).call

      has_pending_review      = PrReview.for_repo(github_repo).pending_review.exists?
      has_pending_submission  = PrReview.for_repo(github_repo).pending_submission.exists?

      unless has_pending_review || has_pending_submission
        say pastel.yellow("No pending PR reviews. Skipping.\n")
        exit 0
      end

      # Step 2: Review via Claude (only if there are unreviewed PRs)
      if has_pending_review
        say pastel.bold("\nStep 2/3 — Reviewing pull requests...\n")
        RunSkill.new.call('.claude/commands/review-pr.md', local_repo.to_s)
      else
        say pastel.bold("\nStep 2/3 — Skipping (no unreviewed PRs)\n")
      end

      # Step 3: Post reviews to GitHub
      if options[:skip_post]
        say pastel.bold("\nStep 3/3 — Skipping post (--skip-post)\n")
      else
        say pastel.bold("\nStep 3/3 — Posting reviews to GitHub...\n")
        PostPrReviews.new(github_repo: github_repo, github_token: github_token).call
      end
    end

    private

    def load_project_config(project_name)
      project = project_name || Config.default_project
      return {} unless project

      Config.project_config(project)
    end
  end
end
