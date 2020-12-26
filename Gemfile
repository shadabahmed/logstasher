source "https://rubygems.org"

# Specify your gem's dependencies in logstasher.gemspec
gemspec

group :test do
  gem 'rails', "~> #{ENV["RAILS_VERSION"] || "5.2.0"}"
  gem 'rb-fsevent', '~> 0.9'
  gem 'simplecov', :require => false
  gem "byebug"
end

group :guard do
  gem 'growl'
  gem 'guard'
  gem 'guard-rspec'
end
