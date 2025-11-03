# frozen_string_literal: true

module LogStasher
  module CustomFields
    module LogSubscriber
      def extract_custom_fields(data)
        # Don't mutate the original payload; slice the requested fields instead
        fields = CustomFields.custom_fields
        return {} if fields.empty?
        data.respond_to?(:slice) ? data.slice(*fields) : fields.each_with_object({}) { |k, h| h[k] = data[k] if data.key?(k) }
      end
    end

    def self.clear
      Thread.current[:logstasher_custom_fields] = []
    end

    def self.add(*fields)
      custom_fields.concat(fields).uniq!
    end

    def self.custom_fields
      Thread.current[:logstasher_custom_fields] ||= []
    end

    def self.custom_fields=(val)
      Thread.current[:logstasher_custom_fields] = val
    end
  end
end
