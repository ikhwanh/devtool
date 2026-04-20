# frozen_string_literal: true

# Use whenever gem to generate cron entries.
# Install:  bundle exec whenever --update-crontab
# Remove:   bundle exec whenever --clear-crontab
# See also: config/motd.rb for the terminal summary schedule

set :output, 'log/cron.log'
set :environment, ENV.fetch('RAILS_ENV', 'development')

every 1.hour do
  rake 'scheduled:pr_review_all'
  rake 'scheduled:rollbar_issues_all'
end

