# frozen_string_literal: true

require 'redis'

module LogStasher
  module Device
    class Redis
      attr_reader :options, :redis

      def initialize(options = {})
        @options = default_options.merge(options)
        validate_options
        configure_redis
      end

      def data_type
        options[:data_type]
      end

      def key
        options[:key]
      end

      def redis_options
        unless @redis_options
          default_keys = default_options.keys
          @redis_options = options.reject { |k, _v| default_keys.include?(k) }
        end

        @redis_options
      end

      def write(log)
        case data_type
        when 'list'
          redis.rpush(key, log)
        when 'channel'
          redis.publish(key, log)
        else
          raise "Unknown data type #{data_type}"
        end
      end

      def close
        redis.quit
      end

      private

      def configure_redis
        @redis = ::Redis.new(redis_options)
      end

      def default_options
        { key: 'logstash', data_type: 'list' }
      end

      def validate_options
        unless %w[list channel].include?(options[:data_type])
          raise 'Expected :data_type to be either "list" or "channel"'
        end
      end
    end
  end
end
