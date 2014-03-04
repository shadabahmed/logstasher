require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/string/inflections'
require 'active_support/log_subscriber'
require 'active_support/notifications'
require 'active_support/ordered_options'
require 'action_controller/log_subscriber'
require 'action_controller/metal/logstasher'
require 'logstash/event'

require 'logstasher/version'
require 'logstasher/log_subscriber'

module LogStasher
  extend self
  attr_accessor :logger, :enabled, :log_controller_parameters
  attr_reader :custom_fields_callback

  def remove_existing_log_subscriptions
    ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
      case subscriber
        when ActionView::LogSubscriber
          unsubscribe(:action_view, subscriber)
        when ActionController::LogSubscriber
          unsubscribe(:action_controller, subscriber)
      end
    end
  end

  def unsubscribe(component, subscriber)
    events = subscriber.public_methods(false).reject{ |method| method.to_s == 'call' }
    events.each do |event|
      ActiveSupport::Notifications.notifier.listeners_for("#{event}.#{component}").each do |listener|
        if listener.instance_variable_get('@delegate') == subscriber
          ActiveSupport::Notifications.unsubscribe listener
        end
      end
    end
  end

  def add_custom_fields(&block)
    @custom_fields_callback = block
  end

  def setup(app)
    app.config.action_dispatch.rack_cache[:verbose] = false if app.config.action_dispatch.rack_cache
    self.suppress_app_logs(app)
    self.logger = app.config.logstasher.logger || new_logger("#{Rails.root}/log/logstash_#{Rails.env}.log")
    self.logger.level = app.config.logstasher.log_level || Logger::WARN
    self.enabled = true
    self.log_controller_parameters = !! app.config.logstasher.log_controller_parameters

    ActionController::Base.send(:include, ActionController::LogStasher)
    LogStasher::LogSubscriber.attach_to :action_controller
  end

  def suppress_app_logs(app)
    if configured_to_suppress_app_logs?(app)
      LogStasher.remove_existing_log_subscriptions
      Rails::Rack::Logger.logger = ::Logger.new('/dev/null')
    end
  end

  def configured_to_suppress_app_logs?(app)
    # This supports both spellings: "suppress_app_log" and "supress_app_log"
    !!(app.config.logstasher.suppress_app_log.nil? ? app.config.logstasher.supress_app_log : app.config.logstasher.suppress_app_log)
  end

  def log(severity, msg)
    if self.logger && self.logger.send("#{severity}?")
      event = LogStash::Event.new(:message => msg, :level => severity, :tags => ['log'])
      self.logger.send severity, event.to_json
    end
  end

  %w( fatal error warn info debug unknown ).each do |severity|
    eval <<-EOM, nil, __FILE__, __LINE__ + 1
      def #{severity}(msg)
        self.log(:#{severity}, msg)
      end
    EOM
  end

  private

  def new_logger(path)
    FileUtils.touch path # prevent autocreate messages in log
    Logger.new path
  end
end

class LogStash::Event
  def to_json
    return JSON.generate(@data)
  end
end

require 'logstasher/railtie' if defined?(Rails)
