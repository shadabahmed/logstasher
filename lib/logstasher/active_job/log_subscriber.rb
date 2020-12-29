# frozen_string_literal: true

# For Rails 6.0 or below, require the logging module which contains LogSubscriber
if ActiveJob::VERSION::MAJOR < 6 || (ActiveJob::VERSION::MAJOR == 6 && ActiveJob::VERSION::MINOR.zero?)
  require 'active_job/logging'
else
  require 'active_job/log_subscriber'
end

module LogStasher
  module ActiveJob
    BASE_SUBSCRIBER = if defined?(::ActiveJob::LogSubscriber)
                        ::ActiveJob::LogSubscriber
                      else
                        ::ActiveJob::Logging::LogSubscriber
                      end

    class LogSubscriber < BASE_SUBSCRIBER
      def enqueue(event)
        process_event(event, 'enqueue')
      end

      def enqueue_at(event)
        process_event(event, 'enqueue_at')
      end

      def perform(event)
        process_event(event, 'perform')

        # Revert the request id back, in the event that the inline adapter is being used or a
        # perform_now was used.
        LogStasher.request_context[:request_id] = Thread.current[:old_request_id]
        Thread.current[:old_request_id] = nil
      end

      def perform_start(event)
        # Use the job_id as the request id, so that any custom logging done for a job
        # shares a request id, and has the job id in each log line.
        #
        # It's not being set when the job is enqueued, so enqueuing a job will have it's default
        # request_id. In a lot of cases, it will be because of a web request.
        #
        # Hang onto the old request id, so we can revert after the job is done being performed.
        Thread.current[:old_request_id] = LogStasher.request_context[:request_id]
        LogStasher.request_context[:request_id] = event.payload[:job].job_id

        process_event(event, 'perform_start')
      end

      def logger
        LogStasher.logger
      end

      private

      def process_event(event, type)
        data = extract_metadata(event)
        data.merge! extract_exception(event)
        data.merge! extract_scheduled_at(event) if type == 'enqueue_at'
        data.merge! extract_duration(event) if type == 'perform'
        data.merge! request_context

        tags = ['job', type]
        tags.push('exception') if data[:exception]
        logger << "#{LogStasher.build_logstash_event(data, tags).to_json}\n"
      end

      def extract_metadata(event)
        {
          job_id: event.payload[:job].job_id,
          queue_name: queue_name(event),
          job_class: event.payload[:job].class.to_s,
          job_args: args_info(event.payload[:job])
        }
      end

      def extract_duration(event)
        { duration: event.duration.to_f.round(2) }
      end

      def extract_exception(event)
        event.payload.slice(:exception)
      end

      def extract_scheduled_at(event)
        { scheduled_at: scheduled_at(event) }
      end

      def request_context
        LogStasher.request_context
      end

      # The default args_info makes a string. We need objects to turn into JSON.
      def args_info(job)
        ::ActiveJob::Arguments.serialize(job.arguments)
      end
    end
  end
end
