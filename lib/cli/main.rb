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

    def self.exit_on_failure?
      true
    end

    private

    def mask(value)
      value.length > 8 ? "#{value[0..3]}#{'*' * (value.length - 4)}" : '****'
    end
  end
end
