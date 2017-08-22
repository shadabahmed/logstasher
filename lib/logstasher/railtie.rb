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
    config.logstasher.job_enabled = true

    # Try loading the config/logstasher.yml if present
    env = Rails.env.to_sym || :development
    config_file = File.expand_path "./config/logstasher.yml"

    # Load and ERB templating of YAML files
    LOGSTASHER = File.exists?(config_file) ? YAML.load(ERB.new(File.read(config_file)).result).symbolize_keys : nil

    initializer :logstasher, :before => :load_config_initializers do |app|
      if LOGSTASHER.present?
        # process common configs
        LogStasher.process_config(app.config.logstasher, LOGSTASHER)
        # process environment specific configs
        LogStasher.process_config(app.config.logstasher, LOGSTASHER[env].symbolize_keys) if LOGSTASHER.key? env
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

  def default_source
    case RUBY_PLATFORM
    when /darwin/
      # NOTE: MacOS Sierra and later are setting `.local`
      # hostnames that even as real hostnames without the `.local` part,
      # are still unresolvable. One reliable way to get an IP is to
      # get all available IP address lists and use the first one.
      # This will always be `127.0.0.1`.
      address_info = Socket.ip_address_list.first
      address_info && address_info.ip_address
    else
      IPSocket.getaddress(Socket.gethostname)
    end
  end

  def process_config(config, yml_config)
    # Enable the logstasher logs for the current environment
    config.enabled = yml_config[:enabled] if yml_config.key? :enabled
    config.controller_enabled = yml_config[:controller_enabled] if yml_config.key? :controller_enabled
    config.mailer_enabled = yml_config[:mailer_enabled] if yml_config.key? :mailer_enabled
    config.record_enabled = yml_config[:record_enabled] if yml_config.key? :record_enabled
    config.view_enabled = yml_config[:view_enabled] if yml_config.key? :view_enabled
    config.job_enabled = yml_config[:job_enabled] if yml_config.key? :job_enabled

    # This line is optional if you do not want to suppress app logs in your <environment>.log
    config.suppress_app_log = yml_config[:suppress_app_log] if yml_config.key? :suppress_app_log

    # This line is optional, it allows you to set a custom value for the @source field of the log event
    config.source = yml_config.key?(:source) ? yml_config[:source] : default_source

    config.backtrace = yml_config[:backtrace] if yml_config.key? :backtrace
    config.logger_path = yml_config[:logger_path] if yml_config.key? :logger_path
    config.log_level = yml_config[:log_level] if yml_config.key? :log_level
    config.log_controller_parameters = yml_config[:log_controller_parameters] if yml_config.key? :log_controller_parameters
  end
end
