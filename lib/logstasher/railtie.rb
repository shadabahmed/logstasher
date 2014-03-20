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
      end
    end

    config.after_initialize do
      if ::LogStasher.enabled? && ::LogStasher.silence_standard_logging?
        require 'logstasher/silent_logger'

        ::Rails::Rack::Logger.send(:include, ::LogStasher::SilentLogger)

        ::ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
          subscriber.class.send(:include, ::LogStasher::SilentLogger)
        end
      end
    end

    def default_logger
      unless @default_logger
        path = ::Rails.root.join('log', "logstash_#{::Rails.env}.log")
        ::FileUtils.touch(path) # prevent autocreate messages in log

        @default_logger =  ::Logger.new(path)
      end

      @default_logger
    end

  end
end
