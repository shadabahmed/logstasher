require 'active_support/core_ext/class/attribute'
require 'active_support/log_subscriber'
require 'logstasher/custom_fields'

module LogStasher
  module ActiveSupport
    class LogSubscriber < ::ActiveSupport::LogSubscriber
      include CustomFields::LogSubscriber

      def process_action(event)
        payload = event.payload

        data      = extract_request(payload)
        data.merge! extract_status(payload)
        data.merge! runtimes(event)
        data.merge! location(event)
        data.merge! extract_exception(payload)
        data.merge! LogStasher.store
        data.merge! extract_custom_fields(payload)

        tags = ['request']
        tags.push('exception') if payload[:exception]
        logger << LogStasher.build_logstash_event(data, tags).to_json + "\n"
      end

      def redirect_to(event)
        Thread.current[:logstasher_location] = event.payload[:location]
      end

      def logger
        LogStasher.logger
      end

      private

      def extract_request(payload)
        {
          method: payload[:method],
          path: extract_path(payload),
          format: extract_format(payload),
          controller: payload[:params]['controller'],
          action: payload[:params]['action']
        }
      end

      def extract_path(payload)
        payload[:path].split("?").first
      end

      def extract_format(payload)
        if ::ActionPack::VERSION::MAJOR == 3 && ::ActionPack::VERSION::MINOR == 0
          payload[:formats].first
        else
          payload[:format]
        end
      end

      def extract_status(payload)
        if payload[:status]
          { :status => payload[:status].to_i }
        else
          { :status => 0 }
        end
      end

      def runtimes(event)
        {
          :duration => event.duration,
          :view => event.payload[:view_runtime],
          :db => event.payload[:db_runtime]
        }.inject({}) do |runtimes, (name, runtime)|
          runtimes[name] = runtime.to_f.round(2) if runtime
          runtimes
        end
      end

      def location(event)
        if location = Thread.current[:logstasher_location]
          Thread.current[:logstasher_location] = nil
          { :location => location }
        else
          {}
        end
      end

      # Monkey patching to enable exception logging
      def extract_exception(payload)
        if payload[:exception]
          exception, message = payload[:exception]
          status = ::ActionDispatch::ExceptionWrapper.status_code_for_exception(exception)
          if LogStasher.backtrace
            backtrace = $!.backtrace.join("\n")
          else
            backtrace = $!.backtrace.first
          end
          message = "#{exception}\n#{message}\n#{backtrace}"
          { :status => status, :error => message }
        else
          {}
        end
      end
    end
  end
end
