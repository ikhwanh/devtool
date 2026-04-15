# frozen_string_literal: true

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.

# Load .env file into ENV (does not override existing env vars)
dotenv_path = File.expand_path('../.env', __dir__)
if File.exist?(dotenv_path)
  File.foreach(dotenv_path) do |line|
    line = line.strip
    next if line.empty? || line.start_with?('#')

    key, value = line.split('=', 2)
    ENV[key] ||= value if key && value
  end
end
