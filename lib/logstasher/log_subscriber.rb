require 'active_support/core_ext/class/attribute'
require 'active_support/log_subscriber'

module Logstasher
  class RequestLogSubscriber < ActiveSupport::LogSubscriber
    def process_action(event)
      payload = event.payload

      data      = extract_request(payload)
      data.merge! extract_status(payload)
      data.merge! runtimes(event)
      data.merge! location(event)
      data.merge! extract_exception(payload)
      data.merge! extract_appended_params(payload)

      event = LogStash::Event.new('@fields' => data, '@tags' => ['request'])
      event.tags << 'exception' if payload[:exception]
      Logstasher.logger.unknown event.to_json
    end

    def redirect_to(event)
      Thread.current[:logstasher_location] = event.payload[:location]
    end

    private

    def extract_request(payload)
      {
        :method => payload[:method],
        :path => extract_path(payload),
        :format => extract_format(payload),
        :controller => payload[:params][:controller],
        :action => payload[:params][:action]
      }
    end

    def extract_path(payload)
      payload[:path].split("?").first
    end

    def extract_format(payload)
      if ::ActionPack::VERSION::MAJOR == 3 && ::ActionPack::VERSION::MINOR == 0
        payload[:formats].first
      else
        payload[:format]
      end
    end

    def extract_status(payload)
      if payload[:status]
        { :status => payload[:status].to_i }
      else
        { :status => 0 }
      end
    end

    def runtimes(event)
      {
        :duration => event.duration,
        :view => event.payload[:view_runtime],
        :db => event.payload[:db_runtime]
      }.inject({}) do |runtimes, (name, runtime)|
        runtimes[name] = runtime.to_f.round(2) if runtime
        runtimes
      end
    end

    def location(event)
      if location = Thread.current[:logstasher_location]
        Thread.current[:logstasher_location] = nil
        { :location => location }
      else
        {}
      end
    end

    # Monkey patching to enable exception logging
    def extract_exception(payload)
      if payload[:exception]
        exception, message = payload[:exception]
        message = "#{exception}\n#{message}\n#{($!.backtrace.join("\n"))}"
        { :status => 500, :error => message }
      else
        {}
      end
    end

    def extract_appended_params(payload)
      (!Logstasher.appended_params.empty? && payload.extract!(*Logstasher.appended_params)) || {}
    end
  end
end
