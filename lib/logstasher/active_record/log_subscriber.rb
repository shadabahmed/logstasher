require 'active_support/notifications'
require 'active_record/log_subscriber'
require 'logstasher/custom_fields'

module LogStasher
  module ActiveRecord
    class LogSubscriber < ::ActiveRecord::LogSubscriber
      include CustomFields::LogSubscriber

      def identity(event)
        lsevent = logstash_event(event)
        if logger && lsevent
          logger << lsevent.to_json + "\n"
        end
      end
      alias :sql :identity

      def logger
        LogStasher.logger
      end

      private

      def logstash_event(event)
        data = event.payload

        return if 'SCHEMA' == data[:name]

        data.merge! runtimes(event)
        data.merge! extract_sql(data)
        data.merge! request_context
        data.merge! LogStasher.store
        data.merge! extract_custom_fields(data)

        tags = [ 'request' ]
        tags.push('exception') if data[:exception]
        LogStasher.build_logstash_event(data, tags)
      end

      def request_context
        LogStasher.request_context
      end

      def runtimes(event)
        if event.duration
          { duration: event.duration.to_f.round(2) }
        else
          {  }
        end
      end

      def extract_sql(data)
        { sql: data[:sql].squeeze(' ') }
      end
    end
  end
end
