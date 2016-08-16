require 'active_support/notifications'
require 'action_view/log_subscriber'
require 'logstasher/custom_fields'

module LogStasher
  module ActionView
    class LogSubscriber < ::ActionView::LogSubscriber
      include CustomFields::LogSubscriber

      def render_template(event)
        logstash_event(event)
      end
      alias :render_partial :render_template
      alias :render_collection :render_template

      def logger
        LogStasher.logger
      end

      private

      def logstash_event(event)
        data = event.payload

        data.merge! event_data(event)
        data.merge! runtimes(event)
        data.merge! extract_data(data)
        data.merge! request_context
        data.merge! LogStasher.store
        data.merge! extract_custom_fields(data)

        tags = []
        tags.push('exception') if data[:exception]
        logger << LogStasher.build_logstash_event(data, tags).to_json + "\n"
      end

      def extract_data(data)
        {  identifier: from_rails_root(data[:identifier]) }
      end

      def request_context
        LogStasher.request_context
      end

      def store
        LogStasher.store
      end

      def event_data(event)
        {
          name: event.name,
          transaction_id: event.transaction_id,
        }
      end

      def runtimes(event)
        {
          duration: event.duration,
        }.inject({}) do |runtimes, (name, runtime)|
          runtimes[name] = runtime.to_f.round(2) if runtime
          runtimes
        end
      end
    end
  end
end
