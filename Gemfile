# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in logstasher.gemspec
gemspec

if Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new("3.1")
  gem 'net-smtp', require: false
  gem 'net-imap', require: false
  gem 'net-pop', require: false
end

group :test do
  gem 'byebug'
  gem 'rails', "~> #{ENV['RAILS_VERSION'] || '6.1.0'}"
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
