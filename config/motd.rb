# frozen_string_literal: true

# Standalone schedule for terminal summary (motd).
# Install:  bundle exec whenever --load-file config/motd.rb --update-crontab
# Remove:   bundle exec whenever --load-file config/motd.rb --clear-crontab

set :output, 'log/cron.log'
set :environment, ENV.fetch('RAILS_ENV', 'development')

every 30.minutes do
  command 'bin/devtool sync'
end
