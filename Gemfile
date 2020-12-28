# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in logstasher.gemspec
gemspec

group :test do
  gem 'byebug'
  gem 'rails', "~> #{ENV['RAILS_VERSION'] || '5.2.0'}"
  gem 'rb-fsevent', '~> 0.9'
  gem 'redis', require: false
  gem 'simplecov', require: false
end

group :lint, optional: true do
  gem 'rubocop'
end

group :guard, optional: true do
  gem 'growl'
  gem 'guard'
  gem 'guard-rspec'
end
