module LogStasher
  module Device
    def self.factory(config)
      config = stringify_keys(config)
      type   = config.delete('type') or fail ArgumentError, 'No "type" given'

      case type
      when 'redis', :redis then
        require 'logstasher/device/redis'
        ::LogStasher::Device::Redis.new(config)
      when "syslog", :syslog then
        require 'logstasher/device/syslog'
        ::LogStasher::Device::Syslog.new(config)
      else
        fail ArgumentError, "Unknown type: #{type}"
      end
    end

    def stringify_keys(hash)
      hash.inject({}) do |stringified_hash, (key, value)|
        stringified_hash[key.to_s] = value
        stringified_hash
      end
    end
    module_function :stringify_keys
  end
end
