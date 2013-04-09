require 'rails/railtie'
require 'action_view/log_subscriber'
require 'action_controller/log_subscriber'

module LogStasher
  class Railtie < Rails::Railtie
    config.logstasher = ActiveSupport::OrderedOptions.new
    config.logstasher.enabled = false

    initializer :logstasher do |app|
      LogStasher.setup(app) if app.config.logstasher.enabled
    end
  end
end
