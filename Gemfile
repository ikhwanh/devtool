# frozen_string_literal: true

source 'https://rubygems.org'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 8.1.2'
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem 'propshaft'
# Use sqlite3 as the database for Active Record
gem 'sqlite3', '>= 2.1'
# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '>= 5.0'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[windows jruby]

# CLI
gem 'thor'

# GitHub API client (@octokit/rest replacement)
gem 'octokit'

# Faraday retry middleware
gem 'faraday-retry'

# Interactive terminal prompts (inquirer replacement)
gem 'tty-prompt'

# Terminal spinner (ora replacement)
gem 'tty-spinner'

# Terminal colors (chalk replacement)
gem 'pastel'

# Cron scheduling (node-cron replacement)
gem 'whenever', require: false

group :development do
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
end

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'

  gem 'factory_bot_rails'
  gem 'rspec-rails'
  gem 'webmock'
end
