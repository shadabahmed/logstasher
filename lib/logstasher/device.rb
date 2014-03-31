module LogStasher
  module Device
    def self.factory(config)
      config = config.dup
      type   = config.delete(:type) or fail ArgumentError, "No :type given"

      case type
      when "redis", :redis then
        require "logstasher/device/redis"

        ::LogStasher::Device::Redis.new(config)
      when "syslog", :syslog then
        require "logstasher/device/syslog"

        ::LogStasher::Device::Syslog.new(config)
      else
        fail ArgumentError, "Unknown type: #{type}"
      end
    end
  end
end
