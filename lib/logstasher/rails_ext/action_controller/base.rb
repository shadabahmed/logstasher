module LogStasher
  module ActionController
    module Instrumentation
      def process_action(*args)
        add_custom_fields_to_store
        LogStasher.clear_request_context
        LogStasher.add_default_fields_to_request_context(request)

        super(*args)
        LogStasher::CustomFields.clear
      end
      
      private

      # this method is called from within super of process_action.
      def append_info_to_payload(payload) #:nodoc:
        LogStasher.add_default_fields_to_payload(payload, request)
        if self.respond_to?(:logstasher_add_custom_fields_to_request_context)
          logstasher_add_custom_fields_to_request_context(LogStasher.request_context)
        end

        if self.respond_to?(:logstasher_add_custom_fields_to_payload)
          before_keys = payload.keys.clone
          logstasher_add_custom_fields_to_payload(payload)
          after_keys = payload.keys
          # Store all extra keys added to payload hash in payload itself. This is a thread safe way
          LogStasher::CustomFields.add(*(after_keys - before_keys))
        end

        payload[:status] = response.status
        super(payload)

        LogStasher.store.each do |key, value|
          payload[key] = value
        end

        LogStasher.request_context.each do |key, value|
          payload[key] = value
        end
      end
      
      def add_custom_fields_to_store
        LogStasher.store[:ip] = request.remote_ip
        LogStasher.store[:route] = "#{request.params[:controller]}##{request.params[:action]}"
        LogStasher.request_context[:request_id] = request.env['action_dispatch.request_id']
      end
    end
  end
end
