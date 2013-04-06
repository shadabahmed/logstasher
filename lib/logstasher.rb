require 'logstasher/version'
require 'logstasher/log_subscriber'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/string/inflections'
require 'active_support/ordered_options'

module Logstasher
  # Logger for the logstash logs
  mattr_accessor :logger, :enabled

  # Set the options for the adding cutom data to payload
  mattr_accessor :payload_appender

  def self.append_payload(&block)
    self.payload_appender = block
  end

  def self.remove_existing_log_subscriptions
    ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
      case subscriber
      when ActionView::LogSubscriber
        unsubscribe(:action_view, subscriber)
      when ActionController::LogSubscriber
        unsubscribe(:action_controller, subscriber)
      end
    end
  end

  def self.unsubscribe(component, subscriber)
    events = subscriber.public_methods(false).reject{ |method| method.to_s == 'call' }
    events.each do |event|
      ActiveSupport::Notifications.notifier.listeners_for("#{event}.#{component}").each do |listener|
        if listener.instance_variable_get('@delegate') == subscriber
          ActiveSupport::Notifications.unsubscribe listener
        end
      end
    end
  end

  def self.setup(app)
    Logstasher.enabled = true
    app.config.action_dispatch.rack_cache[:verbose] = false if app.config.action_dispatch.rack_cache
    require 'logstasher/rails_ext/rack/logger'
    require 'logstasher/rails_ext/action_controller/metal/instrumentation'
    require 'logstash/event'
    Logstasher.remove_existing_log_subscriptions
    Logstasher::RequestLogSubscriber.attach_to :action_controller
    self.logger = app.config.logstasher.logger || Logger.new("#{Rails.root}/log/logstash.log")
  end
end

require 'logstasher/railtie' if defined?(Rails)
