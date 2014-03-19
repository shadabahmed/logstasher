require 'logger'

module LogStasher
  class << self
    attr_reader :append_fields_callback
    attr_writer :enabled
    attr_writer :include_parameters
    attr_writer :silence_standard_logging

    def append_fields(&block)
      @append_fields_callback = block
    end

    def enabled?
      @enabled ||= false
    end

    def include_parameters?
      if @include_parameters.nil?
        @include_parameters = true
      else
        @include_parameters
      end
    end

    def initialize_logger(device = $stdout, level = ::Logger::INFO)
      ::Logger.new(device).tap do |new_logger|
        new_logger.level = level
      end
    end

    def logger
      @logger ||= initialize_logger
    end

    def logger=(log)
      @logger = log
    end

    def silence_standard_logging?
      if @silence_standard_logging.nil?
        @silence_standard_logging = false
      else
        @silence_standard_logging
      end
    end
  end
end

require 'logstash/event'
class LogStash::Event
  def to_json
    return JSON.generate(@data)
  end
end

require 'logstasher/railtie' if defined?(Rails)
