# frozen_string_literal: true

require_relative 'rollbar_command'
require_relative 'issues_command'

module CLI
  class Main < Thor
    desc 'rollbar COMMAND', 'Rollbar item commands'
    subcommand 'rollbar', RollbarCommand

    desc 'issues COMMAND', 'GitHub issue commands'
    subcommand 'issues', IssuesCommand

    def self.exit_on_failure?
      true
    end
  end
end
