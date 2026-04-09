# frozen_string_literal: true

# Use whenever gem to generate cron entries.
# Run: bundle exec whenever --update-crontab
# Remove: bundle exec whenever --clear-crontab

set :output, 'log/cron.log'
set :environment, ENV.fetch('RAILS_ENV', 'development')

# Every 2 hours: analyze Rollbar (high severity, last 1 day) then create GitHub issues
every 2.hours do
  command "cd #{path} && bin/devtool rollbar analyze --severity high --days-ago 1 --autoselect >> log/cron.log 2>&1"
  command "cd #{path} && bin/devtool issues create >> log/cron.log 2>&1"
end
