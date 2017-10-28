require 'logstasher/version'
require 'logstasher/active_support/log_subscriber'
require 'logstasher/active_support/mailer_log_subscriber'
require 'logstasher/active_record/log_subscriber' if defined?(ActiveRecord)
require 'logstasher/action_view/log_subscriber' if defined?(ActionView)
require 'logstasher/active_job/log_subscriber' if defined?(ActiveJob)
require 'logstasher/rails_ext/action_controller/base'
require 'logstasher/custom_fields'
require 'request_store'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/string/inflections'
require 'active_support/ordered_options'

module LogStasher
  extend self
  STORE_KEY = :logstasher_data
  REQUEST_CONTEXT_KEY = :logstasher_request_context

  attr_accessor :logger, :logger_path, :enabled, :log_controller_parameters, :source, :backtrace,
    :controller_monkey_patch, :field_renaming
  # Setting the default to 'unknown' to define the default behaviour
  @source = 'unknown'
  # By default log the backtrace of exceptions
  @backtrace = true

  def remove_existing_log_subscriptions
    ::ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
      case subscriber.class.name
        when 'ActionView::LogSubscriber'
          unsubscribe(:action_view, subscriber)
        when 'ActionController::LogSubscriber'
          unsubscribe(:action_controller, subscriber)
        when 'ActionMailer::LogSubscriber'
          unsubscribe(:action_mailer, subscriber)
        when 'ActiveRecord::LogSubscriber'
          unsubscribe(:active_record, subscriber)
        when 'ActiveJob::Logging::LogSubscriber'
          unsubscribe(:active_job, subscriber)
      end
    end
  end

  def unsubscribe(component, subscriber)
    events = subscriber.public_methods(false).reject{ |method| method.to_s == 'call' }
    events.each do |event|
      ::ActiveSupport::Notifications.notifier.listeners_for("#{event}.#{component}").each do |listener|
        if listener.instance_variable_get('@delegate') == subscriber
          ::ActiveSupport::Notifications.unsubscribe listener
        end
      end
    end
  end

  def add_default_fields_to_payload(payload, request)
    payload[:ip] = request.remote_ip
    payload[:route] = "#{request.params[:controller]}##{request.params[:action]}"
    payload[:request_id] = request.env['action_dispatch.request_id']
    LogStasher::CustomFields.add(:ip, :route, :request_id)
    if self.log_controller_parameters
      payload[:parameters] = payload[:params].except(*::ActionController::LogSubscriber::INTERNAL_PARAMS)
      LogStasher::CustomFields.add(:parameters)
    end
  end

  def add_custom_fields(&block)
    wrapped_block = Proc.new do |fields|
      LogStasher::CustomFields.add(*LogStasher.store.keys)
      instance_exec(fields, &block)
    end
    ::ActionController::Metal.send(:define_method, :logstasher_add_custom_fields_to_payload, &wrapped_block)
    ::ActionController::Base.send(:define_method, :logstasher_add_custom_fields_to_payload, &wrapped_block)
  end

  def add_custom_fields_to_request_context(&block)
    wrapped_block = Proc.new do |fields|
      instance_exec(fields, &block)
      LogStasher::CustomFields.add(*fields.keys)
    end
    ::ActionController::Metal.send(:define_method, :logstasher_add_custom_fields_to_request_context, &wrapped_block)
    ::ActionController::Base.send(:define_method, :logstasher_add_custom_fields_to_request_context, &wrapped_block)
  end

  def add_default_fields_to_request_context(request)
    request_context[:request_id] = request.env['action_dispatch.request_id']
  end

  def clear_request_context
    request_context.clear
  end

  def setup_before(config)
    require 'logstash-event'
    self.enabled = config.enabled
    LogStasher::ActiveSupport::LogSubscriber.attach_to :action_controller if config.controller_enabled
    LogStasher::ActiveSupport::MailerLogSubscriber.attach_to :action_mailer if config.mailer_enabled
    LogStasher::ActiveRecord::LogSubscriber.attach_to :active_record if config.record_enabled
    LogStasher::ActionView::LogSubscriber.attach_to :action_view if config.view_enabled
    LogStasher::ActiveJob::LogSubscriber.attach_to :active_job if has_active_job? && config.job_enabled
  end

  def setup(config)
    # Path instrumentation class to insert our hook
    if (! config.controller_monkey_patch && config.controller_monkey_patch != false) || config.controller_monkey_patch == true
      require 'logstasher/rails_ext/action_controller/metal/instrumentation'
    end
    self.suppress_app_logs(config)
    self.logger_path = config.logger_path || "#{Rails.root}/log/logstash_#{Rails.env}.log"
    self.logger = config.logger || new_logger(self.logger_path)
    self.logger.level = config.log_level || Logger::WARN
    self.source = config.source unless config.source.nil?
    self.log_controller_parameters = !! config.log_controller_parameters
    self.backtrace = !! config.backtrace unless config.backtrace.nil?
    self.set_data_for_rake
    self.set_data_for_console
    self.field_renaming = Hash(config.field_renaming)
  end

  def set_data_for_rake
    self.request_context['request_id'] = ::Rake.application.top_level_tasks if self.called_as_rake?
  end

  def set_data_for_console
    self.request_context['request_id'] = "#{Process.pid}" if self.called_as_console?
  end

  def called_as_rake?
    File.basename($0) == 'rake'
  end

  def called_as_console?
    defined?(Rails::Console) && true || false
  end

  def has_active_job?
    defined?(ActiveJob)
  end

  def suppress_app_logs(config)
    if configured_to_suppress_app_logs?(config)
      require 'logstasher/rails_ext/rack/logger'
      LogStasher.remove_existing_log_subscriptions
    end
  end

  def configured_to_suppress_app_logs?(config)
    # This supports both spellings: "suppress_app_log" and "supress_app_log"
    !!(config.suppress_app_log.nil? ? config.supress_app_log : config.suppress_app_log)
  end

  # Log an arbitrary message.
  #
  # Usually invoked by the level-based wrapper methods defined below.
  #
  # Examples
  #
  #   LogStasher.info("message")
  #   LogStasher.info("message", tags:"tag1")
  #   LogStasher.info("message", tags:["tag1", "tag2"])
  #   LogStasher.info("message", timing:1234)
  #   LogStasher.info(custom1:"yes", custom2:"no")
  def log(severity, message, additional_fields={})
    if self.logger && self.logger.send("#{severity}?")

      data = {'level' => severity}
      if message.respond_to?(:to_hash)
        data.merge!(message.to_hash)
      else
        data['message'] = message
      end

      # tags get special handling
      tags = Array(additional_fields.delete(:tags) || 'log')

      data.merge!(additional_fields)
      self.logger << build_logstash_event(data, tags).to_json + "\n"

    end
  end

  def build_logstash_event(data, tags)
    field_renaming.each do |old_name, new_name|
        data[new_name] = data.delete(old_name) if data.key?(old_name)
    end
    ::LogStash::Event.new(data.merge('source' => self.source, 'tags' => tags))
  end

  def store
    if RequestStore.store[STORE_KEY].nil?
      # Get each store it's own private Hash instance.
      RequestStore.store[STORE_KEY] = Hash.new { |hash, key| hash[key] = {} }
    end
    RequestStore.store[STORE_KEY]
  end

  def request_context
    RequestStore.store[REQUEST_CONTEXT_KEY] ||= {}
  end

  def watch(event, opts = {}, &block)
    event_group = opts[:event_group] || event
    ::ActiveSupport::Notifications.subscribe(event) do |*args|
      # Calling the processing block with the Notification args and the store
      block.call(*args, store[event_group])
    end
  end

  %w( fatal error warn info debug unknown ).each do |severity|
    eval <<-EOM, nil, __FILE__, __LINE__ + 1
      def #{severity}(message=nil, additional_fields={})
        self.log(:#{severity}, message, additional_fields)
      end
    EOM
  end

  def enabled?
    self.enabled || false
  end

  private

  def new_logger(path)
    if path.is_a? String
      FileUtils.touch path # prevent autocreate messages in log
    end
    Logger.new path
  end
end

require 'logstasher/railtie' if defined?(Rails)
