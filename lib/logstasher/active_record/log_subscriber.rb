require 'active_support/notifications'
require 'active_record/log_subscriber'

module LogStasher
  module ActiveRecord
    class LogSubscriber < ::ActiveRecord::LogSubscriber
      def identity(event)
        event = logstash_event(event)
        if event
          logger << event.to_json + "\n"
        end
      end
      alias :sql :identity

      def logger
        LogStasher.logger
      end

      private

      def logstash_event(event)
        data = event.payload

        return unless LogStasher.logger.debug?
        return if 'SCHEMA' == data[:name]

        data.merge! runtimes(event)
        data.merge! extract_sql(data)
        data.merge! request_context
        data.merge! extract_custom_fields(data)

        ::LogStash::Event.new(data.merge('source' => LogStasher.source))
      end

      def request_context
        LogStasher.request_context
      end

      def runtimes(event)
        {
          :duration => event.duration,
        }.inject({}) do |runtimes, (name, runtime)|
          runtimes[name] = runtime.to_f.round(2) if runtime
          runtimes
        end
      end

      def extract_sql(data)
        { sql: data[:sql].squeeze(' ') }
      end

      def extract_custom_fields(data)
        custom_fields = (!LogStasher.custom_fields.empty? && data.extract!(*LogStasher.custom_fields)) || {}
        LogStasher.custom_fields.clear
        custom_fields
      end
    end
  end
end
