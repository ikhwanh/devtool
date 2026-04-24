# frozen_string_literal: true

# Use whenever gem to generate cron entries.
# Install:  bundle exec whenever --update-crontab
# Remove:   bundle exec whenever --clear-crontab
# See also: config/motd.rb for the terminal summary schedule

set :output, 'log/cron.log'
set :environment, ENV.fetch('RAILS_ENV', 'development')

every 30.minutes do
  command 'bin/devtool sync'
  command 'bin/devtool work'
end
