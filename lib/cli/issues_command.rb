# frozen_string_literal: true

module CLI
  class IssuesCommand < Thor
    desc 'create', 'Generate GitHub issue content via Claude then create the issues'

    method_option :skip_generate,     type: :boolean, default: false, aliases: '--skip-generate',
                                      desc: 'Skip Claude issue generation step'
    method_option :local_repository,  type: :string,                  aliases: '--local-repository',
                                      desc: 'Path to local repo for source-context enrichment'
    method_option :github_repo,       type: :string, required: true, aliases: '--github-repo',
                                      desc: 'GitHub repo in owner/repo format'
    method_option :github_token,      type: :string,                  aliases: '--github-token',
                                      desc: 'GitHub token (falls back to GITHUB_TOKEN env var)'

    def create
      pastel = Pastel.new
      github_repo  = options[:github_repo]  || ENV.fetch('GITHUB_REPO', nil)
      github_token = options[:github_token] || ENV.fetch('GITHUB_TOKEN', nil)
      local_repo   = options[:local_repository] || ENV.fetch('LOCAL_REPOSITORY', nil)

      unless github_repo
        say pastel.red('Error: --github-repo is required')
        exit 1
      end

      say pastel.bold("\nGitHub Issue Creator\n")
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
  end
end
