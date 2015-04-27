require 'active_support/notifications'
require 'action_view/log_subscriber'

module LogStasher
  module ActionView
    class LogSubscriber < ::ActionView::LogSubscriber
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
        data.merge! store
        data.merge! extract_custom_fields(data)

        ls_event = LogStash::Event.new(data.merge('source' => LogStasher.source))
        if ls_event
          logger << ls_event.to_json + "\n"
        end
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

      def extract_custom_fields(data)
        custom_fields = (!LogStasher.custom_fields.empty? && data.extract!(*LogStasher.custom_fields)) || {}
        LogStasher.custom_fields.clear
        custom_fields
      end
    end
  end
end
