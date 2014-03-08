require 'json'

require 'active_support/log_subscriber'
require 'action_controller/log_subscriber'

module LogStasher
  class LogSubscriber < ::ActiveSupport::LogSubscriber

    INTERNAL_PARAMS = ::ActionController::LogSubscriber::INTERNAL_PARAMS

    def process_action(event)
      payload = event.payload
      tags    = extract_tags(payload)
      fields  = extract_request(payload)

      fields.merge! extract_status(payload)
      fields.merge! runtimes(event)
      fields.merge! location
      fields.merge! extract_exception(payload)
      fields.merge! extract_parameters(payload)
      fields.merge! appended_fields

      event = LogStash::Event.new(fields.merge('tags' => tags))

      LogStasher.logger << event.to_json + "\n"
    end

    def redirect_to(event)
      Thread.current[:logstasher_context][:location] = event.payload[:location]
    end

    private

    def appended_fields
      callback = ::LogStasher.append_fields_callback
      {}.tap do |fields|
        controller.instance_exec(fields, &callback) if callback
      end
    end

    def controller
      Thread.current[:logstasher_context][:controller]
    end

    def extract_request(payload)
      {
        :action     => payload[:action],
        :controller => payload[:controller],
        :format     => extract_format(payload),
        :ip         => request.remote_ip,
        :method     => payload[:method],
        :path       => extract_path(payload),
        :route      => "#{payload[:controller]}##{payload[:action]}"
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

    def extract_tags(payload)
      tags = ['request']
      tags.push('exception') if payload[:exception]
      tags
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

    def location
      location = Thread.current[:logstasher_context][:location]

      if location
        { :location => location }
      else
        {}
      end
    end

    # Monkey patching to enable exception logging
    def extract_exception(payload)
      if payload[:exception]
        exception, message = payload[:exception]
        status = ActionDispatch::ExceptionWrapper.status_code_for_exception(exception)
        message = "#{exception}\n#{message}\n#{($!.backtrace.join("\n"))}"
        { :status => status, :error => message }
      else
        {}
      end
    end

    def extract_parameters(payload)
      if LogStasher.include_parameters?
        { :params => JSON.generate(payload[:params].except(INTERNAL_PARAMS)) }
      else
        {}
      end
    end

    def request
      Thread.current[:logstasher_context][:request]
    end
  end
end

::LogStasher::LogSubscriber.attach_to :action_controller
