# frozen_string_literal: true

# Use whenever gem to generate cron entries.
# Run: bundle exec whenever --update-crontab
# Remove: bundle exec whenever --clear-crontab

set :output, 'log/cron.log'
set :environment, ENV.fetch('RAILS_ENV', 'development')

# Every 2 hours: fetch Rollbar items (last 1 day) then create GitHub issues
every 2.hours do
  command "cd #{path} && bin/devtool rollbar fetch --days-ago 1 >> log/cron.log 2>&1"
  command "cd #{path} && bin/devtool issues create --severity high --autoselect >> log/cron.log 2>&1"
end

# Every hour: review new or updated pull requests
every 1.hour do
  command "cd #{path} && bin/devtool pr review --days-ago 7 >> log/cron.log 2>&1"
end
