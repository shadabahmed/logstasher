module ActionController
  module Instrumentation
    def process_action(*args)
      raw_payload = {
          :controller => self.class.name,
          :action     => self.action_name,
          :params     => request.filtered_parameters,
          :format     => request.format.try(:ref),
          :method     => request.method,
          :path       => (request.fullpath rescue "unknown")
      }

      if Logstasher.payload_appender
        before_keys = raw_payload.keys.clone
        Logstasher.payload_appender.call(self, request, raw_payload)
        after_keys = raw_payload.keys
        raw_payload[:log_stasher_appended_param_keys] = after_keys - before_keys
      end

      ActiveSupport::Notifications.instrument("start_processing.action_controller", raw_payload.dup)

      ActiveSupport::Notifications.instrument("process_action.action_controller", raw_payload) do |payload|
        result = super
        payload[:status] = response.status
        append_info_to_payload(payload)
        result
      end
    end

  end
end