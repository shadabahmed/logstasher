require 'rails/railtie'
require 'action_view/log_subscriber'
require 'action_controller/log_subscriber'

module LogStasher
  class Railtie < Rails::Railtie
    config.logstasher = ::ActiveSupport::OrderedOptions.new
    config.logstasher.enabled = false

    initializer :logstasher, :before => :load_config_initializers do |app|
      app.config.action_dispatch.rack_cache[:verbose] = false if rack_cache_hashlike?(app)
      LogStasher.setup_before(app.config.logstasher) if app.config.logstasher.enabled
    end

    initializer :logstasher do
      config.after_initialize do
        LogStasher.setup(config.logstasher) if config.logstasher.enabled
      end
    end

    def rack_cache_hashlike?(app)
      app.config.action_dispatch.rack_cache && app.config.action_dispatch.rack_cache.respond_to?(:[]=)
    end
  end
end
