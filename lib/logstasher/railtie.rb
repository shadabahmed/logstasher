module LogStasher
  class Railtie < ::Rails::Railtie
    config.logstasher = ::ActiveSupport::OrderedOptions.new
    config.logstasher.enabled = false
    config.logstasher.include_parameters = true
    config.logstasher.serialize_parameters = true
    config.logstasher.silence_standard_logging = false
    config.logstasher.silence_creation_message = true
    config.logstasher.logger = nil
    config.logstasher.log_level = ::Logger::INFO

    config.logstasher.metadata  = {}
    config.before_initialize do
      options = config.logstasher

      ::LogStasher.enabled                  = options.enabled
      ::LogStasher.include_parameters       = options.include_parameters
      ::LogStasher.serialize_parameters     = options.serialize_parameters
      ::LogStasher.silence_standard_logging = options.silence_standard_logging
      ::LogStasher.logger                   = options.logger || default_logger
      ::LogStasher.logger.level             = options.log_level
      ::LogStasher.metadata                 = options.metadata
    end

    initializer 'logstasher.load' do
      if ::LogStasher.enabled?
        ::ActiveSupport.on_load(:action_controller) do
          require 'logstasher/log_subscriber'
          require 'logstasher/context_wrapper'

          include ::LogStasher::ContextWrapper
        end
      end
    end

    config.after_initialize do
      if ::LogStasher.enabled? && ::LogStasher.silence_standard_logging?
        require 'logstasher/silent_logger'

        ::Rails::Rack::Logger.send(:include, ::LogStasher::SilentLogger)

        ::ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
          if subscriber.is_a?(::ActiveSupport::LogSubscriber)
            subscriber.class.send(:include, ::LogStasher::SilentLogger)
          end
        end
      end
    end

    def default_logger
      unless @default_logger
        path = ::Rails.root.join('log', "logstash_#{::Rails.env}.log")
        if config.logstasher.silence_creation_message
          ::FileUtils.touch(path) # prevent autocreate messages in log
        end

        @default_logger =  ::Logger.new(path)
      end

      @default_logger
    end
  end
end
