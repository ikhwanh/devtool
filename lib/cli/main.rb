# frozen_string_literal: true

require_relative 'rollbar_command'
require_relative 'issues_command'

module CLI
  class Main < Thor
    package_name 'devtool'

    # ── config ────────────────────────────────────────────────────────────────

    desc 'config', 'Set configuration for a project'
    method_option :project,          type: :string,  required: true, aliases: '-p',
                                     desc: 'Project name'
    method_option :rollbar_token,    type: :string,  aliases: '--rollbar-token',
                                     desc: 'Rollbar API token'
    method_option :github_token,     type: :string,  aliases: '--github-token',
                                     desc: 'GitHub personal access token'
    method_option :github_repo,      type: :string,  aliases: '--github-repo',
                                     desc: 'GitHub repo in owner/repo format'
    method_option :local_repository, type: :string,  aliases: '--local-repository',
                                     desc: 'Path to local repository'
    method_option :default,          type: :boolean, default: false,
                                     desc: 'Mark this project as the default'
    def config
      pastel  = Pastel.new
      project = options[:project]

      Config.upsert_project(
        project:          project,
        set_default:      options[:default],
        rollbar_token:    options[:rollbar_token],
        github_token:     options[:github_token],
        github_repo:      options[:github_repo],
        local_repository: options[:local_repository]
      )

      label = options[:default] ? pastel.green('(default)') : ''
      say pastel.bold("\nProject '#{project}' configured #{label}").strip
      Config.project_config(project).each do |key, value|
        masked = value.length > 8 ? "#{value[0..3]}#{'*' * (value.length - 4)}" : '****'
        say pastel.dim("  #{key}: #{masked}")
      end
      say ''
    end

    # ── rollbar / issues ───────────────────────────────────────────────────────

    desc 'rollbar COMMAND', 'Rollbar item commands'
    subcommand 'rollbar', RollbarCommand

    desc 'issues COMMAND', 'GitHub issue commands'
    subcommand 'issues', IssuesCommand

    def self.exit_on_failure?
      true
    end
  end
end
