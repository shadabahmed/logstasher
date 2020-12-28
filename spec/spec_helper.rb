# frozen_string_literal: true

# Notice there is a .rspec file in the root folder. It defines rspec arguments
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    # Remove the spec folder from coverage. By default all code files are included. For more config options see
    # https://github.com/colszowka/simplecov
    add_filter File.expand_path('../spec', __dir__)
  end
end

# Set rails env as test
ENV['RAILS_ENV'] = 'test'

# This will require me all the gems automatically for the groups. If I do only .setup then I will have to require gems
# manually. Note that you have still have to require some gems if they are part of bigger gem like ActiveRecord which is
# part of Rails. You can say :require => false in gemfile to always use explicit requiring
Bundler.require(:default, :test)
require 'active_support/testing/assertions'
Dir[File.join('./spec/support/**/*.rb')].sort.each { |f| require f }

# Set Rails environment as test
$test_timestamp = '1970-01-01T00:00:00.000Z'

RSpec.configure do |config|
  config.include(ActiveSupport::Testing::Assertions)
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  ActiveJob::Base.queue_adapter = :test
end
