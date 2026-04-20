# frozen_string_literal: true

# Standalone schedule for terminal summary (motd).
# Install:  bundle exec whenever --load-file config/motd.rb --update-crontab --identifier motd
# Remove:   bundle exec whenever --load-file config/motd.rb --clear-crontab  --identifier motd

set :output, 'log/cron.log'
set :environment, ENV.fetch('RAILS_ENV', 'development')

every 1.hour do
  command 'bin/devtool sync'
end
