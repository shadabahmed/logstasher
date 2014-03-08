module LogStasher
  class Railtie < ::Rails::Railtie
    config.logstasher = ::ActiveSupport::OrderedOptions.new
    config.logstasher.enabled = false
    config.logstasher.include_parameters = true
    config.logstasher.silence_standard_logging = false
    config.logstasher.logger = nil
    config.logstasher.log_level = ::Logger::INFO

    initializer 'logstasher.configure' do
      options = config.logstasher

      ::LogStasher.enabled                  = options.enabled
      ::LogStasher.include_parameters       = options.include_parameters
      ::LogStasher.silence_standard_logging = options.silence_standard_logging
      ::LogStasher.logger                   = options.logger || default_logger
      ::LogStasher.logger.level             = options.log_level
    end

    initializer 'logstasher.load' do
      if ::LogStasher.enabled?
        ::ActiveSupport.on_load(:action_controller) do
          require 'logstasher/log_subscriber'
          require 'logstasher/context_wrapper'

          include ::LogStasher::ContextWrapper
        end

        silence_standard_logging if ::LogStasher.silence_standard_logging?
      end
    end

    def default_logger
      path = ::Rails.root.join('log', "logstash_#{::Rails.env}.log")

      ::FileUtils.touch(path) # prevent autocreate messages in log
      ::Logger.new(path)
    end

    def silence_standard_logging
      ::Rails::Rack::Logger.logger = ::Logger.new('/dev/null')
      ::Rails::Rack::Logger.logger.level = ::Logger::UNKNOWN

      ::ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
        case subscriber.class.name
        when 'ActionView::LogSubscriber'
          unsubscribe('action_view', subscriber)
        when 'ActionController::LogSubscriber'
          unsubscribe('action_controller', subscriber)
        end
      end
    end

    def unsubscribe(namespace, subscriber)
      notifier  = ::ActiveSupport::Notifications.notifier

      subscriber.public_methods(false).each do |event|
        next if event.to_s == 'call'

        notifier.listeners_for("#{event}.#{namespace}").each do |listener|
          if listener.instance_variable_get('@delegate') === subscriber
            notifier.unsubscribe(listener)
          end
        end
      end
    end
  end
end
