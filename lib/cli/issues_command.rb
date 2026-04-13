# frozen_string_literal: true

module CLI
  class IssuesCommand < Thor
    desc 'create', 'Generate GitHub issue content via Claude then create the issues'

    method_option :skip_generate,    type: :boolean, default: false, aliases: '--skip-generate',
                                     desc: 'Skip Claude issue generation step'
    method_option :local_repository, type: :string,                  aliases: '--local-repository',
                                     desc: 'Path to local repo for source-context enrichment'
    method_option :github_repo,      type: :string,                  aliases: '--github-repo',
                                     desc: 'GitHub repo in owner/repo format (falls back to config/GITHUB_REPO env var)'
    method_option :github_token,     type: :string,                  aliases: '--github-token',
                                     desc: 'GitHub token (falls back to config/GITHUB_TOKEN env var)'
    method_option :config,           type: :string,                  aliases: '-c',
                                     desc: 'Project config to use (defaults to the project marked as default)'

    def create
      pastel = Pastel.new
      cfg    = load_project_config(options[:config])

      github_repo  = options[:github_repo]      || cfg['github_repo']
      github_token = options[:github_token]     || cfg['github_token'] || ENV['GITHUB_TOKEN']
      local_repo   = options[:local_repository] || cfg['local_repository']

      unless github_repo
        say pastel.red('Error: --github-repo is required (or set it via `bin/devtool config`)')
        exit 1
      end

      say pastel.bold("\nGitHub Issue Creator\n")
      say pastel.dim("  config:      #{options[:config] || Config.default_project || '(none)'}")
      say pastel.dim("  github-repo: #{github_repo}")
      say pastel.dim("  local-repo:  #{local_repo}") if local_repo
      say ''

      # Step 1: Generate issue content via Claude
      if options[:skip_generate]
        say pastel.bold("\nStep 1/2 — Skipping issue generation (--skip-generate)\n")
      else
        say pastel.bold("\nStep 1/2 — Generating issue content...\n")
        RunSkill.new.call('.claude/commands/generate-issues.md', local_repo || '')
      end

      # Step 2: Create GitHub issues
      say pastel.bold("\nStep 2/2 — Creating GitHub issues...\n")
      CreateIssues.new(github_repo: github_repo, github_token: github_token).call
    end

    private

    def load_project_config(project_name)
      project = project_name || Config.default_project
      return {} unless project

      Config.project_config(project)
    end
  end
end
