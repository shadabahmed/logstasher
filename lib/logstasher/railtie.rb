require 'rails/railtie'
require 'action_view/log_subscriber'
require 'action_controller/log_subscriber'

module Logstasher
  class Railtie < Rails::Railtie
    config.logstasher = ActiveSupport::OrderedOptions.new
    config.logstasher.enabled = false

    initializer :logstasher do |app|
      Logstasher.setup(app) if app.config.logstasher.enabled
    end
  end
end
