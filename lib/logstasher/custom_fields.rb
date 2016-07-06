module LogStasher
  module CustomFields
    module LogSubscriber
      def extract_custom_fields(data)
        (!CustomFields.custom_fields.empty? && data.extract!(*CustomFields.custom_fields)) || {}
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
