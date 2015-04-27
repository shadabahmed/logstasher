require 'delayed_job'
module LogStasher
  module Delayed
    class Plugin < ::Delayed::Plugin
      callbacks do |lifecycle|
        lifecycle.before(:invoke_job) do |job, *args, &block|
          ::LogStasher.request_context[:request_id] = job.id
          ::LogStasher.source = "Delayed::Job"
          # perhaps handler#object.first_line and method_name would be interesting too (in store??)
        end
      end
    end
  end
end
