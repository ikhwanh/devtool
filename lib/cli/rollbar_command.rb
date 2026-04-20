# frozen_string_literal: true

module CLI
  class RollbarCommand < Thor
    desc 'list', 'List stored Rollbar items'

    method_option :severity, type: :string, aliases: '-s',
                             desc: 'Filter by severity (high/medium/low)'
    method_option :selected, type: :boolean,
                             desc: 'Filter by selected status'
    method_option :env,      type: :string,  aliases: '-e',
                             desc: 'Filter by environment'
    method_option :limit,    type: :numeric, default: 50, aliases: '-n',
                             desc: 'Maximum number of items to display'
    method_option :config,   type: :string,  aliases: '-c',
                             desc: 'Project config to use (defaults to the project marked as default)'

    def list
      pastel   = Pastel.new
      severity = options[:severity]&.downcase

      if severity && RollbarItem::SEVERITIES.exclude?(severity)
        say pastel.red("Invalid --severity \"#{severity}\". Must be one of: #{RollbarItem::SEVERITIES.join(', ')}")
        exit 1
      end

      config_name = options[:config] || Config.default_project

      scope = RollbarItem.for_config(config_name).recent_first
      scope = scope.with_severity(severity)                unless severity.nil?
      scope = scope.where(selected: options[:selected])    unless options[:selected].nil?
      scope = scope.where(environment: options[:env])      if options[:env]
      scope = scope.limit(options[:limit])

      items = scope.to_a

      if items.empty?
        say pastel.yellow('No Rollbar items found.')
        return
      end

      say pastel.bold("\nRollbar Items (#{items.size})\n")

      severity_color = { 'high' => :red, 'medium' => :yellow, 'low' => :cyan }

      items.each do |item|
        sev_label = if item.severity
                      color = severity_color[item.severity] || :white
                      pastel.decorate("[#{item.severity.upcase}]", color)
                    else
                      pastel.dim('[-----]')
                    end

        selected_label = item.selected ? pastel.green(' [selected]') : ''
        github_label   = item.submitted_to_github? ? pastel.blue(' [gh]') : ''
        occ_label      = pastel.dim("(#{item.total_occurrences}x)")
        env_label      = item.environment ? pastel.dim(" [#{item.environment}]") : ''
        date_label     = item.last_occurrence_at ? pastel.dim(" #{item.last_occurrence_at.strftime('%Y-%m-%d')}") : ''

        say "  #{sev_label} #{occ_label}#{env_label}#{date_label}#{selected_label}#{github_label} #{item.title}"
      end

      say ''
    end

    # ──────────────────────────────────────────────────────────────────────────

    desc 'fetch', 'Fetch Rollbar items'

    method_option :days_ago,      type: :numeric, default: 7, aliases: '--days-ago',
                                  desc: 'How many days back to fetch items'
    method_option :rollbar_token, type: :string,               aliases: '--rollbar-token',
                                  desc: 'Rollbar API token (falls back to config/ROLLBAR_TOKEN env var)'
    method_option :config,        type: :string,               aliases: '-c',
                                  desc: 'Project config to use (defaults to the project marked as default)'

    def fetch
      pastel = Pastel.new
      cfg    = load_project_config(options[:config])
      rollbar_token = options[:rollbar_token] || cfg['rollbar_token']
      config_name   = options[:config] || Config.default_project

      say pastel.bold("\nRollbar Issue Analyzer\n")
      say pastel.dim("  config:   #{config_name || '(none)'}")
      say pastel.dim("  days-ago: #{options[:days_ago]}")
      say ''

      say pastel.bold("\nFetching Rollbar items...\n")
      result = FetchRollbar.new(token: rollbar_token, days_ago: options[:days_ago], config: config_name).call

      return if result[:changed]

      say pastel.yellow("No new or updated items since last run. Skipping.\n")
      exit 0
    end

    private

    def load_project_config(project_name)
      project = project_name || Config.default_project
      return {} unless project

      Config.project_config(project)
    end
  end
end
