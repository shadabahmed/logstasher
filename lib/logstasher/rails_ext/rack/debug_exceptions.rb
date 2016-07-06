require 'action_dispatch'
require 'active_support/all'

module LogStasher
  module ActionDispatch

    class DebugExceptions < ::ActionDispatch::DebugExceptions
      include ::LogStasher::ActionDispatch

      def initialize(app, routes_app = nil)
        @app        = app
        @routes_app = routes_app
      end

      def call(env)
        begin
          status, header, body = @app.call(env)
          if header['X-Cascade'] == 'pass'
            raise ::ActionController::RoutingError, "No route matches [#{env['REQUEST_METHOD']}] #{env['PATH_INFO'].inspect}"
          end
        rescue Exception => exception
          log_error(env, ::ActionDispatch::ExceptionWrapper.new(env, exception))
        end
        [status, header, body]
      end

      def build_exception_hash(wrapper)
        exception = wrapper.exception
        trace = wrapper.application_trace
        trace = wrapper.framework_trace if trace.empty?

        { error:
          ({ exception: exception.class.name, message: exception.message, trace: trace}.
           merge!( exception.respond_to?(:annotated_source_code) && { annotated_source_code: exception.annoted_source_code } || {} ))
        }
      end

      private

      def log_error(env, wrapper)
        LogStasher.logger << LogStasher.build_logstash_event(build_exception_hash(wrapper), ["exception"]).to_json + "\n"
      end
    end
  end
end
