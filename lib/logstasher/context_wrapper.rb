module LogStasher
  module ContextWrapper
    def process_action(*)
      Thread.current[:logstasher_context] = {
        :controller => self,
        :request    => request
      }

      super
    ensure
      Thread.current[:logstasher_context] = nil
    end
  end
end
