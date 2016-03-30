require 'action_controller'
require 'logstasher/rails_ext/action_controller/base'

module LogStasher
  class SampleController < ::ActionController::Base
    include ::LogStasher::ActionController::Instrumentation
    before_filter :set_before_filter_value

    def set_before_filter_value
      @before_filter_value = SecureRandom.hex
    end
  end
end
