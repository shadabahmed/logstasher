# frozen_string_literal: true

require 'active_support/core_ext/class/attribute'
require 'active_support/log_subscriber'

module LogStasher
  module ActiveSupport
    class MailerLogSubscriber < ::ActiveSupport::LogSubscriber
      MAILER_FIELDS = %i[mailer action message_id from to].freeze

      def deliver(event)
        process_event(event, %w[mailer deliver])
      end

      # This method will only be invoked on Rails 6.0 and prior.
      # Starting in Rails 6.0 the receive method was deprecated in
      # favor of ActionMailbox.  The receive method was removed
      # from ActionMailer in Rails 6.1, and there doesn't appear to
      # be corresponding instrumentation for ActionMailbox.
      def receive(event)
        process_event(event, %w[mailer receive])
      end

      def process(event)
        process_event(event, %w[mailer process])
      end

      def logger
        LogStasher.logger
      end

      private

      def process_event(event, tags)
        data = LogStasher.request_context.merge(extract_metadata(event.payload))
        logger << "#{LogStasher.build_logstash_event(data, tags).to_json}\n"
      end

      def extract_metadata(payload)
        payload.slice(*MAILER_FIELDS)
      end
    end
  end
end
