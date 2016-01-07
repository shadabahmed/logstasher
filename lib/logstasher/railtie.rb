require 'rails/railtie'
require 'action_view/log_subscriber'
require 'action_controller/log_subscriber'
require 'socket'

module LogStasher
  class Railtie < Rails::Railtie
    config.logstasher = ::ActiveSupport::OrderedOptions.new
    config.logstasher.enabled = false

    # Set up the default logging options
    config.logstasher.controller_enabled = true
    config.logstasher.mailer_enabled = true
    config.logstasher.record_enabled = false
    config.logstasher.view_enabled = true

    # Try loading the config/logstasher.yml if present
    env = Rails.env || 'development'
    config_file = File.expand_path "./config/logstasher.yml"

    # Load and ERB templating of YAML files
    LOGSTASHER = File.exists?(config_file) ? YAML.load(ERB.new(File.read(config_file)).result)[env].symbolize_keys : nil

    initializer :logstasher, :before => :load_config_initializers do |app|
      if LOGSTASHER.present?
        # Enable the logstasher logs for the current environment
        app.config.logstasher.enabled = LOGSTASHER[:enabled] if LOGSTASHER.key? :enabled
        app.config.logstasher.controller_enabled = LOGSTASHER[:controller_enabled] if LOGSTASHER.key? :controller_enabled
        app.config.logstasher.mailer_enabled = LOGSTASHER[:mailer_enabled] if LOGSTASHER.key? :mailer_enabled
        app.config.logstasher.record_enabled = LOGSTASHER[:record_enabled] if LOGSTASHER.key? :record_enabled
        app.config.logstasher.view_enabled = LOGSTASHER[:view_enabled] if LOGSTASHER.key? :view_enabled
        #
        # # This line is optional if you do not want to suppress app logs in your <environment>.log
        app.config.logstasher.suppress_app_log = LOGSTASHER[:suppress_app_log] if LOGSTASHER.key? :suppress_app_log
        #
        # # This line is optional, it allows you to set a custom value for the @source field of the log event
        app.config.logstasher.source = LOGSTASHER[:source].present? ? LOGSTASHER[:source] : IPSocket.getaddress(Socket.gethostname)
      end

      app.config.action_dispatch.rack_cache[:verbose] = false if app.config.action_dispatch.rack_cache
      LogStasher.setup_before(app.config.logstasher) if app.config.logstasher.enabled
    end

    initializer :logstasher do
      config.after_initialize do
        LogStasher.setup(config.logstasher) if config.logstasher.enabled
      end
    end
  end
end
