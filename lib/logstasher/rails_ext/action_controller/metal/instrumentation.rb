::ActionController::Instrumentation.class_eval do
  def process_action_with_logstasher(*args)
    payload = {
        :controller => self.class.name,
        :action     => self.action_name,
        :params     => request.filtered_parameters,
        :format     => request.format.try(:ref),
        :method     => request.method,
        :path       => (request.fullpath rescue "unknown")
    }

    LogStasher.add_default_fields_to_payload(payload, request)

    LogStasher.clear_request_context
    LogStasher.add_default_fields_to_request_context(request)

    process_action_without_logstasher(*args)
  end

  alias_method :process_action_without_logstasher, :process_action
  alias_method :process_action, :process_action_with_logstasher

  def append_info_to_payload_with_logstasher(payload)
    result = append_info_to_payload_without_logstasher(payload)

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

    LogStasher.store.each do |key, value|
      payload[key] = value
    end

    LogStasher.request_context.each do |key, value|
      payload[key] = value
    end
    result
  end

  alias_method :append_info_to_payload_without_logstasher, :append_info_to_payload
  alias_method :append_info_to_payload, :append_info_to_payload_with_logstasher
end
