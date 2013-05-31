require 'logstasher/version'
require 'logstasher/log_subscriber'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/string/inflections'
require 'active_support/ordered_options'

module LogStasher
  # Logger for the logstash logs
  mattr_accessor :logger, :enabled

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

  def self.add_default_fields_to_payload(payload, request)
    payload[:ip] = request.remote_ip
    payload[:route] = "#{request.params[:controller]}##{request.params[:action]}"
    payload[:parameters] = payload[:params].except(*ActionController::LogSubscriber::INTERNAL_PARAMS).inject(""){|s,(k,v)|
      s+="#{k}=#{v}\n"}
    self.custom_fields += [:ip, :route, :parameters]
  end

  def self.add_custom_fields(&block)
    ActionController::Metal.send(:define_method, :logtasher_add_custom_fields_to_payload, &block)
    ActionController::Base.send(:define_method, :logtasher_add_custom_fields_to_payload, &block)
  end

  def self.setup(app)
    app.config.action_dispatch.rack_cache[:verbose] = false if app.config.action_dispatch.rack_cache
    # Path instrumentation class to insert our hook
    require 'logstasher/rails_ext/action_controller/metal/instrumentation'
    require 'logstash/event'
    self.suppress_app_logs(app)
    LogStasher::RequestLogSubscriber.attach_to :action_controller
    self.logger = app.config.logstasher.logger || Logger.new("#{Rails.root}/log/logstash_#{Rails.env}.log")
    self.logger.level = app.config.logstasher.log_level || Logger::WARN
    self.enabled = true
  end

  def self.suppress_app_logs(app)
    if app.config.logstasher.supress_app_log.nil? || app.config.logstasher.supress_app_log
      require 'logstasher/rails_ext/rack/logger'
      LogStasher.remove_existing_log_subscriptions
    end
  end

  def self.custom_fields
    Thread.current[:logstasher_custom_fields] ||= []
  end

  def self.custom_fields=(val)
    Thread.current[:logstasher_custom_fields] = val
  end


  def self.log(severity, msg)
    if self.logger && self.logger.send("#{severity}?")
      event = LogStash::Event.new('@fields' => {:message => msg, :level => severity},'@tags' => ['log'])
      self.logger.send severity, event.to_json
    end
  end

  class << self
    %w( fatal error warn info debug unknown ).each do |severity|
      eval <<-EOM, nil, __FILE__, __LINE__ + 1
        def #{severity}(msg)
          self.log(:#{severity}, msg)
        end
      EOM
    end
  end
end

require 'logstasher/railtie' if defined?(Rails)
