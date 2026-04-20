# frozen_string_literal: true

module CLI
  class PrCommand < Thor
    desc 'fetch', 'Fetch open PRs from GitHub and queue them for review'

    method_option :github_repo,  type: :string,  aliases: '--github-repo',
                                 desc: 'GitHub repo in owner/repo format (falls back to config)'
    method_option :github_token, type: :string,  aliases: '--github-token',
                                 desc: 'GitHub token (falls back to config/GITHUB_TOKEN env var)'
    method_option :config,       type: :string,  aliases: '-c',
                                 desc: 'Project config to use (defaults to the project marked as default)'
    method_option :days_ago,     type: :numeric, default: 7, aliases: '--days-ago',
                                 desc: 'Only fetch PRs created within this many days (default: 7)'
    method_option :id,           type: :numeric, aliases: '--id',
                                 desc: 'Only fetch this PR number'
    method_option :force,        type: :boolean, default: false, aliases: '--force',
                                 desc: 'Re-fetch even if already queued (requires --id)'

    def fetch
      pastel = Pastel.new
      cfg    = load_project_config(options[:config])

      github_repo  = options[:github_repo]  || cfg['github_repo']
      github_token = options[:github_token] || cfg['github_token'] || ENV.fetch('GITHUB_TOKEN', nil)
      pr_id        = options[:id]
      config_name  = options[:config] || Config.default_project

      unless github_repo
        say pastel.red('Error: --github-repo is required (or set it via `bin/devtool config`)')
        exit 1
      end

      if options[:force] && pr_id.nil?
        say pastel.red('Error: --force requires --id')
        exit 1
      end

      say pastel.bold("\nPR Fetch\n")
      say pastel.dim("  config:      #{config_name || '(none)'}")
      say pastel.dim("  github-repo: #{github_repo}")
      say pastel.dim("  days-ago:    #{options[:days_ago]}")
      say pastel.dim("  pr-id:       #{pr_id}") if pr_id
      say ''

      if options[:force]
        destroyed = PrReview.for_repo(github_repo).for_config(config_name).where(pr_number: pr_id).destroy_all
        say pastel.yellow("  Cleared #{destroyed.size} existing record(s) for PR ##{pr_id}\n") if destroyed.any?
      end

      FetchPullRequests.new(github_repo: github_repo, github_token: github_token, days_ago: options[:days_ago],
                            pr_number: pr_id, config: config_name).call
    end

    desc 'review', 'Review fetched PRs via Claude and post reviews to GitHub'

    method_option :github_repo,      type: :string,  aliases: '--github-repo',
                                     desc: 'GitHub repo in owner/repo format (falls back to config)'
    method_option :github_token,     type: :string,  aliases: '--github-token',
                                     desc: 'GitHub token (falls back to config/GITHUB_TOKEN env var)'
    method_option :local_repository, type: :string,  aliases: '--local-repository',
                                     desc: 'Path to local repo for source-context enrichment'
    method_option :config,           type: :string,  aliases: '-c',
                                     desc: 'Project config to use (defaults to the project marked as default)'
    method_option :skip_post,        type: :boolean, default: false, aliases: '--skip-post',
                                     desc: 'Generate reviews but do not post them to GitHub'
    method_option :id,               type: :numeric, aliases: '--id',
                                     desc: 'Only review this PR number'
    method_option :force,            type: :boolean, default: false, aliases: '--force',
                                     desc: 'Force re-review even if already reviewed (requires --id)'

    def review
      pastel = Pastel.new
      cfg    = load_project_config(options[:config])

      github_repo  = options[:github_repo]      || cfg['github_repo']
      github_token = options[:github_token]     || cfg['github_token'] || ENV.fetch('GITHUB_TOKEN', nil)
      local_repo   = options[:local_repository] || cfg['local_repository']
      pr_id        = options[:id]
      config_name  = options[:config] || Config.default_project

      unless github_repo
        say pastel.red('Error: --github-repo is required (or set it via `bin/devtool config`)')
        exit 1
      end

      if options[:force] && pr_id.nil?
        say pastel.red('Error: --force requires --id')
        exit 1
      end

      say pastel.bold("\nPR Reviewer\n")
      say pastel.dim("  config:      #{config_name || '(none)'}")
      say pastel.dim("  github-repo: #{github_repo}")
      say pastel.dim("  pr-id:       #{pr_id}") if pr_id
      say pastel.dim("  local-repo:  #{local_repo}") if local_repo
      say ''

      # --force: reset the review so it goes through the full pipeline again without re-fetching
      if options[:force]
        reset = PrReview.for_repo(github_repo).for_config(config_name).where(pr_number: pr_id)
                        .update_all(review_body: nil, comments_json: nil, review_url: nil, submitted_at: nil)
        say pastel.yellow("  Reset #{reset} existing review(s) for PR ##{pr_id}\n") if reset.positive?
      end

      scope                  = PrReview.for_repo(github_repo).for_config(config_name)
      scope                  = scope.where(pr_number: pr_id) if pr_id
      has_pending_review     = scope.pending_review.exists?
      has_pending_submission = scope.pending_submission.exists?

      unless has_pending_review || has_pending_submission
        say pastel.yellow("No fetched PRs pending review. Run `bin/devtool pr fetch` first.\n")
        exit 0
      end

      # Step 1: Review via Claude (only if there are unreviewed PRs)
      if has_pending_review
        say pastel.bold("\nStep 1/2 — Reviewing pull requests...\n")
        RunSkill.new.call('.claude/commands/review-pr.md', local_repo.to_s, pr_number: pr_id, config: config_name)
      else
        say pastel.bold("\nStep 1/2 — Skipping (no unreviewed PRs)\n")
      end

      # Step 2: Post reviews to GitHub
      if options[:skip_post]
        say pastel.bold("\nStep 2/2 — Skipping post (--skip-post)\n")
      else
        say pastel.bold("\nStep 2/2 — Posting reviews to GitHub...\n")
        PostPrReviews.new(github_repo: github_repo, github_token: github_token, pr_number: pr_id,
                          config: config_name).call
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
