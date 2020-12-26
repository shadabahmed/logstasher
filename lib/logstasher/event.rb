require "json"
require "time"
require "date"

module LogStasher
  class Event

    def initialize(data={})
      @cancelled = false

      @data = data
      if data.include?("@timestamp")
        t = data["@timestamp"]
        if t.is_a?(String)
          data["@timestamp"] = Time.parse(t).gmtime
        end
      else
        data["@timestamp"] = ::Time.now.utc 
      end
      data["@version"] = "1" if !@data.include?("@version")
    end 

    def to_s
      to_json.to_s
    end
    
    def to_json(*args)
      return @data.to_json(*args) 
    end

    def [](key)
      @data[key]
    end
  end
end
