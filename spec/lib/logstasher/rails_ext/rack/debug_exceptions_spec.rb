require 'spec_helper'

shared_examples 'MyApp' do
  before do
    class MyApp 
      def initialize()
      end
      def call(*args)
        raise Exception.new("My Exception")
      end
    end
  end

  let(:app) { MyApp.new }
  let(:environment) { { 'action_dispatch.show_exceptions' => true } } 
  let(:logger) { double }
  subject{ described_class.new(app) }

  before(:each) do
    allow(LogStasher).to receive(:logger).and_return(logger)
    allow(LogStasher.logger).to receive(:'<<').and_return(true)
  end
end

describe ::LogStasher::ActionDispatch::DebugExceptions do
  include_examples 'MyApp'

  describe '#build_exception_hash' do
    let (:wrapper) { double(exception: Exception.new("My Exception"), application_trace: [ "line5" ]) }
    it do
      hash = subject.build_exception_hash(wrapper)

      expect(hash).to match({:error=>{:exception=>"Exception", :message=>"My Exception", :trace=>["line5"]}})
    end
  end

  describe 'calls LogStasher.logger with json format exception' do
    describe '#log_error' do
      it do
        expect(LogStasher).to receive(:build_logstash_event)
        expect(LogStasher.logger).to receive(:'<<').and_return(true)
        subject.call(environment)
      end
    end
  end
end
