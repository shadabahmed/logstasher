source "https://rubygems.org"

# Specify your gem's dependencies in logstasher.gemspec
gemspec

group :test do
  gem 'rails', "~> #{ENV["RAILS_VERSION"] || "4.2.0"}"
  gem 'rb-fsevent', '~> 0.9'
  gem 'rcov', :platforms => :mri_18
  gem 'redis', :require => false
  gem 'simplecov', :require => false
  gem "byebug"
end

group :guard do
  gem 'growl'
  gem 'guard'
  gem 'guard-rspec'
  
end
