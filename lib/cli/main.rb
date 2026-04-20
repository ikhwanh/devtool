# frozen_string_literal: true

require_relative 'rollbar_command'
require_relative 'issues_command'
require_relative 'pr_command'

module CLI
  class Main < Thor
    package_name 'devtool'

    # ── config ────────────────────────────────────────────────────────────────

    desc 'config', 'Manage project configuration (CRUD)'
    method_option :project,          type: :string,  aliases: '-p',
                                     desc: 'Project name'
    method_option :rollbar_token,    type: :string,  aliases: '--rollbar-token',
                                     desc: 'Rollbar API token'
    method_option :rollbar_account,  type: :string,  aliases: '--rollbar-account',
                                     desc: 'Rollbar account name (org slug in the URL)'
    method_option :github_token,     type: :string,  aliases: '--github-token',
                                     desc: 'GitHub personal access token'
    method_option :github_repo,      type: :string,  aliases: '--github-repo',
                                     desc: 'GitHub repo in owner/repo format'
    method_option :local_repository, type: :string,  aliases: '--local-repository',
                                     desc: 'Path to local repository'
    method_option :default,          type: :boolean, default: false,
                                     desc: 'Mark this project as the default'
    method_option :delete,           type: :boolean, default: false,
                                     desc: 'Delete the project (requires --project)'
    method_option :unset,            type: :string,  aliases: '--unset',
                                     desc: 'Remove a specific key from the project (requires --project)'
    def config(*args)
      if args.include?('help')
        help('config')
        return
      end

      pastel  = Pastel.new
      project = options[:project]

      # No --project: list all configured projects
      if project.nil?
        projects = Config.all.group_by(&:project)

        if projects.empty?
          say pastel.yellow('No projects configured yet.')
          say pastel.dim('  Run: bin/devtool config --project NAME --github-repo owner/repo')
          say ''
          return
        end

        default_project = Config.default_project
        say pastel.bold("\nConfigured projects:\n")
        projects.each do |name, rows|
          label = name == default_project ? pastel.green(' (default)') : ''
          say pastel.bold("  #{name}#{label}")
          rows.each do |row|
            masked = mask(row.value)
            say pastel.dim("    #{row.key}: #{masked}")
          end
        end
        say ''
        return
      end

      # DELETE: remove entire project
      if options[:delete]
        deleted = Config.delete_project(project)
        if deleted.any?
          say pastel.red("Project '#{project}' deleted.")
        else
          say pastel.yellow("Project '#{project}' not found.")
        end
        say ''
        return
      end

      # UNSET: remove a single key from the project
      if (key = options[:unset])
        if Config.delete_key(project, key)
          say pastel.yellow("Key '#{key}' removed from project '#{project}'.")
        else
          say pastel.yellow("Key '#{key}' not found in project '#{project}'.")
        end
        say ''
        return
      end

      key_options = {
        rollbar_token: options[:rollbar_token],
        rollbar_account: options[:rollbar_account],
        github_token: options[:github_token],
        github_repo: options[:github_repo],
        local_repository: options[:local_repository]
      }
      has_keys = key_options.values.any?

      # READ: show config for a specific project (no keys given)
      unless has_keys || options[:default]
        cfg = Config.project_config(project)
        if cfg.empty?
          say pastel.yellow("No config found for project '#{project}'.")
          say pastel.dim("  Run: bin/devtool config --project #{project} --github-repo owner/repo")
        else
          default_project = Config.default_project
          label = project == default_project ? pastel.green(' (default)') : ''
          say pastel.bold("\n#{project}#{label}")
          cfg.each do |k, value|
            say pastel.dim("  #{k}: #{mask(value)}")
          end
        end
        say ''
        return
      end

      # CREATE / UPDATE: upsert provided keys
      Config.upsert_project(project: project, set_default: options[:default], **key_options)

      label = options[:default] ? pastel.green(' (default)') : ''
      say pastel.bold("\nProject '#{project}' configured#{label}")
      Config.project_config(project).each do |key, value|
        say pastel.dim("  #{key}: #{mask(value)}")
      end
      say ''
    end

    # ── rollbar / issues ───────────────────────────────────────────────────────

    desc 'rollbar COMMAND', 'Rollbar item commands'
    subcommand 'rollbar', RollbarCommand

    desc 'issues COMMAND', 'GitHub issue commands'
    subcommand 'issues', IssuesCommand

    desc 'pr COMMAND', 'Pull request commands'
    subcommand 'pr', PrCommand

    # ── sync ───────────────────────────────────────────────────────────────────

    desc 'sync', 'Fetch PRs and Rollbar items for all projects and update the pending summary'
    def sync
      pastel        = Pastel.new
      pending_file  = Rails.root.join('tmp/devtool_pending')
      pr_lines      = []
      rollbar_lines = []

      say pastel.bold("\nSync — All Projects\n")

      Config.all.group_by(&:project).each_key do |project_name|
        cfg           = Config.project_config(project_name)
        github_repo   = cfg['github_repo']
        github_token  = cfg['github_token'] || ENV.fetch('GITHUB_TOKEN', nil)
        rollbar_token = cfg['rollbar_token']

        if github_repo && github_token.present?
          FetchPullRequests.new(github_repo: github_repo, github_token: github_token, config: project_name).call
          count = PrReview.for_config(project_name).pending_review.count
          pr_lines << "  #{project_name}: #{count} PR(s)" if count.positive?
        end

        if rollbar_token.present?
          FetchRollbar.new(token: rollbar_token, config: project_name).call
          count = RollbarItem.for_config(project_name).unselected.count
          rollbar_lines << "  #{project_name}: #{count} item(s)" if count.positive?
        end
      end

      if pr_lines.empty? && rollbar_lines.empty?
        FileUtils.rm_f(pending_file)
        say pastel.dim("Nothing pending.\n")
      else
        lines = ["[devtool #{Time.current.strftime('%b %d %H:%M')}]"]
        lines << 'PRs pending review:' if pr_lines.any?
        lines.concat(pr_lines)
        lines << 'Rollbar items:' if rollbar_lines.any?
        lines.concat(rollbar_lines)
        File.write(pending_file, "#{lines.join("\n")}\n")
        say pastel.green("Pending summary written to #{pending_file}\n")
      end
    end

    # ── work ───────────────────────────────────────────────────────────────────

    desc 'work', 'Review pending PRs and create Rollbar issues for all projects'
    def work
      pastel = Pastel.new
      say pastel.bold("\nWork — All Projects\n")

      Config.all.group_by(&:project).each_key do |project_name|
        cfg           = Config.project_config(project_name)
        github_repo   = cfg['github_repo']
        rollbar_token = cfg['rollbar_token']

        if github_repo
          system("bin/devtool pr review --config #{Shellwords.escape(project_name)}")
        else
          say pastel.dim("[#{project_name}] Skipping PR review — no github_repo configured")
        end

        if rollbar_token
          system("bin/devtool issues create --config #{Shellwords.escape(project_name)} --autoselect")
        else
          say pastel.dim("[#{project_name}] Skipping issue creation — no rollbar_token configured")
        end
      end
    end

    # ── digest ─────────────────────────────────────────────────────────────────

    desc 'digest', 'Generate a daily digest of Rollbar items, GitHub issues, and assigned PRs'
    method_option :days_ago, type: :numeric, default: 1, aliases: '--days-ago',
                             desc: 'How many days back to look for Rollbar items and GitHub issues (default: 1)'
    def digest
      pastel   = Pastel.new
      tmp_path = nil

      say pastel.bold("\nDevtool Daily Digest\n")
      say pastel.dim("  days-ago: #{options[:days_ago]}")
      say ''

      # Step 1: Fetch data across all projects
      say pastel.bold("Step 1/2 — Fetching data...\n")
      data = FetchDigest.new(days_ago: options[:days_ago]).call

      tmp_path = Rails.root.join('tmp', "digest_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json")
      File.write(tmp_path, JSON.generate(data))

      # Step 2: Generate digest via Claude
      say pastel.bold("\nStep 2/2 — Generating digest...\n")
      output_file = Rails.root.join('digest', "#{Time.current.strftime('%Y-%m-%d')}.md").to_s
      RunSkill.new.call('.claude/commands/digest.md', tmp_path.to_s, output_file: output_file)
      say pastel.dim("\nSaved to #{output_file}\n")
    ensure
      File.delete(tmp_path) if tmp_path && File.exist?(tmp_path)
    end

    def self.exit_on_failure?
      true
    end

    private

    def mask(value)
      value.length > 8 ? "#{value[0..3]}#{'*' * (value.length - 4)}" : '****'
    end
  end
end
