source "https://rubygems.org"

# Specify your gem's dependencies in logstasher.gemspec
gemspec

group :test do
  gem 'rb-fsevent', '~> 0.9'
  gem 'guard'
  gem 'guard-rspec'
  gem 'growl'
  gem 'simplecov', :platforms => :mri_19, :require => false
  gem 'rcov', :platforms => :mri_18
  gem 'rails', "~> #{ENV["RAILS_VERSION"] || "3.2.0"}"
end
