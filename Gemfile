source "https://rubygems.org"

# Specify your gem's dependencies in logstasher.gemspec
gemspec

group :test do
  gem 'rails', "~> #{ENV["RAILS_VERSION"] || "6.0.3.4"}"
  gem 'rb-fsevent'
  gem 'redis', require: false
  gem 'simplecov', require: false
end

group :guard do
  gem 'growl'
  gem 'guard'
  gem 'guard-rspec'
end
