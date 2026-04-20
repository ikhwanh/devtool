# frozen_string_literal: true

module CLI
  class IssuesCommand < Thor
    desc 'create', 'Generate GitHub issue content via Claude then create the issues'

    method_option :skip_generate,    type: :boolean, default: false, aliases: '--skip-generate',
                                     desc: 'Skip Claude issue generation step'
    method_option :autoselect,       type: :boolean, default: false,
                                     desc: 'Automatically select all items without prompting'
    method_option :severity,         type: :string,                  aliases: '-s',
                                     desc: 'Auto-select only items of this severity (high/medium/low)'
    method_option :local_repository, type: :string,                  aliases: '--local-repository',
                                     desc: 'Path to local repo for source-context enrichment'
    method_option :rollbar_token,    type: :string,                  aliases: '--rollbar-token',
                                     desc: 'Rollbar API token (falls back to config/ROLLBAR_TOKEN env var)'
    method_option :github_repo,      type: :string,                  aliases: '--github-repo',
                                     desc: 'GitHub repo in owner/repo format (falls back to config/GITHUB_REPO env var)'
    method_option :github_token,     type: :string,                  aliases: '--github-token',
                                     desc: 'GitHub token (falls back to config/GITHUB_TOKEN env var)'
    method_option :config,           type: :string,                  aliases: '-c',
                                     desc: 'Project config to use (defaults to the project marked as default)'

    def create
      pastel = Pastel.new
      cfg    = load_project_config(options[:config])

      rollbar_token = options[:rollbar_token] || cfg['rollbar_token']
      github_repo   = options[:github_repo]   || cfg['github_repo']
      github_token  = options[:github_token]  || cfg['github_token'] || ENV['GITHUB_TOKEN']
      local_repo    = options[:local_repository] || cfg['local_repository']
      config_name   = options[:config] || Config.default_project
      severity      = options[:severity]&.downcase

      if severity && RollbarItem::SEVERITIES.exclude?(severity)
        say pastel.red("Invalid --severity \"#{severity}\". Must be one of: #{RollbarItem::SEVERITIES.join(', ')}")
        exit 1
      end

      unless github_repo
        say pastel.red('Error: --github-repo is required (or set it via `bin/devtool config`)')
        exit 1
      end

      say pastel.bold("\nGitHub Issue Creator\n")
      say pastel.dim("  config:      #{config_name || '(none)'}")
      say pastel.dim("  github-repo: #{github_repo}")
      say pastel.dim("  local-repo:  #{local_repo}") if local_repo
      say pastel.dim("  autoselect:  #{options[:autoselect]}")
      say pastel.dim("  severity:    #{severity}") if severity
      say ''

      # Step 1: Generate issue content via Claude (includes severity tagging)
      if options[:skip_generate]
        say pastel.bold("\nStep 1/3 — Skipping issue generation (--skip-generate)\n")
      else
        say pastel.bold("\nStep 1/3 — Generating issue content...\n")
        RunSkill.new.call('.claude/commands/generate-issues.md', config_name)
      end

      # Step 2: Select items
      say pastel.bold("\nStep 2/3 — Selecting items...\n")
      SelectItems.new(
        token: rollbar_token,
        autoselect: options[:autoselect],
        severity: severity,
        config: config_name
      ).call

      # Step 3: Create GitHub issues
      say pastel.bold("\nStep 3/3 — Creating GitHub issues...\n")
      CreateIssues.new(github_repo: github_repo, github_token: github_token, config: config_name).call
    end

    # ──────────────────────────────────────────────────────────────────────────

    desc 'resolve', 'Resolve Rollbar items whose linked GitHub issues are closed'

    method_option :rollbar_token, type: :string, aliases: '--rollbar-token',
                                  desc: 'Rollbar API write token (falls back to config/ROLLBAR_TOKEN env var)'
    method_option :github_repo,   type: :string, aliases: '--github-repo',
                                  desc: 'GitHub repo in owner/repo format (falls back to config/GITHUB_REPO env var)'
    method_option :github_token,  type: :string, aliases: '--github-token',
                                  desc: 'GitHub token (falls back to config/GITHUB_TOKEN env var)'
    method_option :config,        type: :string, aliases: '-c',
                                  desc: 'Project config to use (defaults to the project marked as default)'
    method_option :dry_run,       type: :boolean, default: false, aliases: '--dry-run',
                                  desc: 'Preview which items would be resolved without making any changes'

    def resolve
      pastel = Pastel.new
      cfg    = load_project_config(options[:config])

      rollbar_token = options[:rollbar_token] || cfg['rollbar_token']
      github_repo   = options[:github_repo]   || cfg['github_repo']
      github_token  = options[:github_token]  || cfg['github_token'] || ENV['GITHUB_TOKEN']
      config_name   = options[:config] || Config.default_project

      unless github_repo
        say pastel.red('Error: --github-repo is required (or set it via `bin/devtool config`)')
        exit 1
      end

      say pastel.bold("\nRollbar Issue Resolver#{options[:dry_run] ? pastel.yellow(' [dry-run]') : ''}\n")
      say pastel.dim("  config:      #{config_name || '(none)'}")
      say pastel.dim("  github-repo: #{github_repo}")
      say ''

      result = ResolveRollbarItems.new(
        github_repo:   github_repo,
        github_token:  github_token,
        rollbar_token: rollbar_token,
        config:        config_name,
        dry_run:       options[:dry_run]
      ).call

      say pastel.bold.green("\n#{result[:resolved]} item(s) resolved, #{result[:skipped]} skipped.\n")
    end

    private

    def load_project_config(project_name)
      project = project_name || Config.default_project
      return {} unless project

      Config.project_config(project)
    end
  end
end
