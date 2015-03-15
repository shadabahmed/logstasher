# Notice there is a .rspec file in the root folder. It defines rspec arguments

# Ruby 1.9 uses simplecov. The ENV['COVERAGE'] is set when rake coverage is run in ruby 1.9
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    # Remove the spec folder from coverage. By default all code files are included. For more config options see
    # https://github.com/colszowka/simplecov
    add_filter File.expand_path('../../spec', __FILE__)
  end
end

# Modify load path so you can require 'ogstasher directly.
$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))

require 'rubygems'
# Loads bundler setup tasks. Now if I run spec without installing gems then it would say gem not installed and
# do bundle install instead of ugly load error on require.
require 'bundler/setup'

# This will require me all the gems automatically for the groups. If I do only .setup then I will have to require gems
# manually. Note that you have still have to require some gems if they are part of bigger gem like ActiveRecord which is
# part of Rails. You can say :require => false in gemfile to always use explicit requiring
Bundler.require(:default, :test)

Dir[File.join("./spec/support/**/*.rb")].each { |f| require f }

# Set Rails environment as test
ENV['RAILS_ENV'] = 'test'

require 'action_pack'
require 'action_controller'
require 'logstasher'
require 'active_support/notifications'
require 'active_support/core_ext/string'
require 'active_support/log_subscriber'
require 'action_controller/log_subscriber'
require 'action_view/log_subscriber'
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/string'
require 'active_support/core_ext/time/zones'
require 'abstract_controller/base'
require 'action_mailer'
require 'logger'
require 'logstash-event'


$test_timestamp = case Rails.version
when /^3\./
  '1970-01-01T00:00:00Z'
else
  '1970-01-01T00:00:00.000Z'
end

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
end
