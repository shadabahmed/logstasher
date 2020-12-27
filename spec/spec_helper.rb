# Notice there is a .rspec file in the root folder. It defines rspec arguments
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    # Remove the spec folder from coverage. By default all code files are included. For more config options see
    # https://github.com/colszowka/simplecov
    add_filter File.expand_path('../spec', __dir__)
  end
end

# Modify load path so you can require 'logstasher directly.
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'rubygems'
# Loads bundler setup tasks. Now if I run spec without installing gems then it would say gem not installed and
# do bundle install instead of ugly load error on require.
require 'bundler/setup'

require 'active_record'
require 'active_job'
require 'action_view'

# This will require me all the gems automatically for the groups. If I do only .setup then I will have to require gems
# manually. Note that you have still have to require some gems if they are part of bigger gem like ActiveRecord which is
# part of Rails. You can say :require => false in gemfile to always use explicit requiring
Bundler.require(:default, :test)

Dir[File.join('./spec/support/**/*.rb')].each { |f| require f }

# Set Rails environment as test
ENV['RAILS_ENV'] = 'test'

$test_timestamp = case Rails.version
                  when /^3\./
                    '1970-01-01T00:00:00Z'
                  else
                    '1970-01-01T00:00:00.000Z'
                  end

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  ActiveJob::Base.queue_adapter = :test
end
