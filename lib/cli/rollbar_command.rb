# frozen_string_literal: true

module CLI
  class RollbarCommand < Thor
    desc 'analyze', 'Fetch Rollbar items, tag severity via Claude, then select items for issue creation'

    method_option :days_ago,      type: :numeric, default: 7, aliases: '--days-ago',
                                  desc: 'How many days back to fetch items'
    method_option :autoselect,    type: :boolean, default: false,
                                  desc: 'Automatically select all items without prompting'
    method_option :severity,      type: :string,                   aliases: '-s',
                                  desc: 'Auto-select only items of this severity (high/medium/low)'
    method_option :rollbar_token, type: :string,                   aliases: '--rollbar-token',
                                  desc: 'Rollbar API token (falls back to ROLLBAR_TOKEN env var)'

    def analyze
      pastel = Pastel.new
      severity = options[:severity]&.downcase

      if severity && RollbarItem::SEVERITIES.exclude?(severity)
        say pastel.red("Invalid --severity \"#{severity}\". Must be one of: #{RollbarItem::SEVERITIES.join(', ')}")
        exit 1
      end

      rollbar_token = options[:rollbar_token] || ENV.fetch('ROLLBAR_TOKEN', nil)

      say pastel.bold("\nRollbar Issue Analyzer\n")
      say pastel.dim("  days-ago:   #{options[:days_ago]}")
      say pastel.dim("  autoselect: #{options[:autoselect]}")
      say pastel.dim("  severity:   #{severity}") if severity
      say ''

      # Step 1: Fetch
      say pastel.bold("\nStep 1/3 — Fetch Rollbar items...\n")
      result = FetchRollbar.new(token: rollbar_token, days_ago: options[:days_ago]).call

      unless result[:changed]
        say pastel.yellow("No new or updated items since last run. Skipping.\n")
        exit 0
      end

      # Step 2: Tag severity via Claude
      say pastel.bold("\nStep 2/3 — Tagging severity...\n")
      RunSkill.new.call('.claude/commands/tag-severity.md')

      # Step 3: Select items
      say pastel.bold("\nStep 3/3 — Selecting items...\n")
      SelectItems.new(
        token: rollbar_token,
        autoselect: options[:autoselect],
        severity: severity
      ).call
    end
  end
end
