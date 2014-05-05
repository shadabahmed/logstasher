require 'logstasher/version'
require 'logstasher/log_subscriber'
require 'request_store'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/string/inflections'
require 'active_support/ordered_options'

module LogStasher
  extend self
  STORE_KEY = :logstasher_data

  attr_accessor :logger, :enabled, :log_controller_parameters, :source
  # Setting the default to 'unknown' to define the default behaviour
  @source = 'unknown'

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

  def add_default_fields_to_payload(payload, request)
    payload[:ip] = request.remote_ip
    payload[:route] = "#{request.params[:controller]}##{request.params[:action]}"
    self.custom_fields += [:ip, :route]
    if self.log_controller_parameters
      payload[:parameters] = payload[:params].except(*ActionController::LogSubscriber::INTERNAL_PARAMS)
      self.custom_fields += [:parameters]
    end
  end

  def add_custom_fields(&block)
    wrapped_block = lambda do |fields|
      LogStasher.custom_fields.concat(LogStasher.store.keys)
      block.call(fields)
    end
    ActionController::Metal.send(:define_method, :logtasher_add_custom_fields_to_payload, &wrapped_block)
    ActionController::Base.send(:define_method, :logtasher_add_custom_fields_to_payload, &wrapped_block)
  end

  def setup(app)
    app.config.action_dispatch.rack_cache[:verbose] = false if app.config.action_dispatch.rack_cache
    # Path instrumentation class to insert our hook
    require 'logstasher/rails_ext/action_controller/metal/instrumentation'
    require 'logstash-event'
    self.suppress_app_logs(app)
    LogStasher::RequestLogSubscriber.attach_to :action_controller
    self.logger = app.config.logstasher.logger || new_logger("#{Rails.root}/log/logstash_#{Rails.env}.log")
    self.logger.level = app.config.logstasher.log_level || Logger::WARN
    self.source = app.config.logstasher.source unless app.config.logstasher.source.nil?
    self.enabled = true
    self.log_controller_parameters = !! app.config.logstasher.log_controller_parameters
  end

  def suppress_app_logs(app)
    if configured_to_suppress_app_logs?(app)
      require 'logstasher/rails_ext/rack/logger'
      LogStasher.remove_existing_log_subscriptions
    end
  end

  def configured_to_suppress_app_logs?(app)
    # This supports both spellings: "suppress_app_log" and "supress_app_log"
    !!(app.config.logstasher.suppress_app_log.nil? ? app.config.logstasher.supress_app_log : app.config.logstasher.suppress_app_log)
  end

  def custom_fields
    Thread.current[:logstasher_custom_fields] ||= []
  end

  def custom_fields=(val)
    Thread.current[:logstasher_custom_fields] = val
  end

  def log(severity, msg)
    if self.logger && self.logger.send("#{severity}?")
      event = LogStash::Event.new('@source' => self.source, '@fields' => {:message => msg, :level => severity}, '@tags' => ['log'])
      self.logger.send severity, event.to_json
    end
  end

  def store
    if RequestStore.store[STORE_KEY].nil?
      # Get each store it's own private Hash instance.
      RequestStore.store[STORE_KEY] = Hash.new { |hash, key| hash[key] = {} }
    end
    RequestStore.store[STORE_KEY]
  end

  def watch(event, opts = {}, &block)
    event_group = opts[:event_group] || event
    ActiveSupport::Notifications.subscribe(event) do |*args|
      # Calling the processing block with the Notification args and the store
      block.call(*args, store[event_group])
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

require 'logstasher/railtie' if defined?(Rails)
