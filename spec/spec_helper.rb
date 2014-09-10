# Notice there is a .rspec file in the root folder. It defines rspec arguments

# Modify load path so you can require logstasher directly.
$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))

require 'rubygems'
require 'bundler/setup'

Bundler.require(:default, :development, :test)

require 'logstasher'

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
end
