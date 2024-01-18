require 'logger'
require 'logstash-event'

module LogStasher
  class << self
    attr_reader :append_fields_callback
    attr_writer :enabled
    attr_writer :include_parameters
    attr_writer :serialize_parameters
    attr_writer :silence_standard_logging
    attr_accessor :metadata
    attr_accessor :default_device

    def load_from_config(config)
      ::LogStasher.logger = ::Logger.new("/dev/null")

      config.each do |key,value|
        key = key.to_s
        case key
        when 'metadata'
          ::LogStasher.metadata = value
        when 'device'
          ::LogStasher.default_device = ::LogStasher::Device.factory(value)
          ::LogStasher.logger = ::Logger.new(::LogStasher.default_device)
        when 'include_parameters'
          ::LogStasher.include_parameters = value
        when 'serialize_parameters'
          ::LogStasher.serialize_parameters = value
        when 'silence_standard_logging'
          ::LogStasher.silence_standard_logging = value
        end
      end
    end

    def append_fields(&block)
      @append_fields_callback = block
    end

    def enabled?
      if @enabled.nil?
        @enabled = false
      end

      @enabled
    end

    def include_parameters?
      if @include_parameters.nil?
        @include_parameters = true
      end

      @include_parameters
    end

    def serialize_parameters?
      if @serialize_parameters.nil?
        @serialize_parameters = true
      end

      @serialize_parameters
    end

    def initialize_logger(device = $stdout, level = ::Logger::INFO)
      ::Logger.new(device).tap do |new_logger|
        new_logger.level = level
      end
    end

    def log_as_json(payload, as_logstash_event: false)
      payload = payload.dup

      # Merge in metadata if configured. This supports a Hash and a fully formed
      # LogStash::Event.
      if !metadata.empty?
        payload.merge!(:metadata => metadata) if payload.is_a?(::Hash)
        payload.append(:metadata => metadata) if payload.is_a?(::LogStash::Event)
      end

      # Wrap the hash in a logstash event if the caller wishes for a specific
      # formatting applied to the hash. This is used by log subscriber, for
      # example.
      payload = ::LogStash::Event.new(payload) if as_logstash_event

      logger << payload.to_json + $INPUT_RECORD_SEPARATOR
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
      end

      @silence_standard_logging
    end
  end
end

require 'logstasher/railtie' if defined?(Rails)
