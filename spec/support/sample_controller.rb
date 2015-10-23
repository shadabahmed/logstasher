require 'action_controller'
require 'logstasher/rails_ext/action_controller/base'

module LogStasher
  class SampleController < ::ActionController::Base
    include ::LogStasher::ActionController::Instrumentation
  end
end
