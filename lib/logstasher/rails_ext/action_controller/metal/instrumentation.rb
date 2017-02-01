module ActionController
  module Instrumentation
    alias :orig_process_action :process_action
    def process_action(*args)
      raw_payload = {
          :controller => self.class.name,
          :action     => self.action_name,
          :params     => request.filtered_parameters,
          :format     => request.format.try(:ref),
          :method     => request.method,
          :path       => (request.fullpath rescue "unknown")
      }

      LogStasher.add_default_fields_to_payload(raw_payload, request)

      LogStasher.clear_request_context
      LogStasher.add_default_fields_to_request_context(request)

      ActiveSupport::Notifications.instrument("start_processing.action_controller", raw_payload.dup)

      ActiveSupport::Notifications.instrument("process_action.action_controller", raw_payload) do |payload|
        if self.respond_to?(:logstasher_add_custom_fields_to_request_context)
          logstasher_add_custom_fields_to_request_context(LogStasher.request_context)
        end

        if self.respond_to?(:logstasher_add_custom_fields_to_payload)
          before_keys = raw_payload.keys.clone
          logstasher_add_custom_fields_to_payload(raw_payload)
          after_keys = raw_payload.keys
          # Store all extra keys added to payload hash in payload itself. This is a thread safe way
          LogStasher::CustomFields.add(*(after_keys - before_keys))
        end

        result = super

        payload[:status] = response.status
        append_info_to_payload(payload)
        LogStasher.store.each do |key, value|
          payload[key] = value
        end

        LogStasher.request_context.each do |key, value|
          payload[key] = value
        end
        result
      end
    end
    alias :logstasher_process_action :process_action
  end
end
