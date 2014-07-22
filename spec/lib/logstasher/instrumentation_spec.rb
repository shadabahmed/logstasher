require 'spec_helper'
require 'logstasher/rails_ext/action_controller/metal/instrumentation'

describe ActionController::Base do
  before :each do
    subject.request = ActionDispatch::TestRequest.new
    subject.response = ActionDispatch::TestResponse.new

    def subject.index(*args)
      render text: 'OK'
    end
  end

  describe ".process_action" do
    it "adds default fields to payload" do
      LogStasher.should_receive(:add_default_fields_to_payload).once
      LogStasher.should_receive(:add_default_fields_to_request_context).once
      subject.process_action(:index)
    end

    it "creates the request context before processing" do
      LogStasher.request_context[:some_key] = 'value'
      LogStasher.should_receive(:clear_request_context).once.and_call_original
      expect {
        subject.process_action(:index)
      }.to change { LogStasher.request_context }
    end

    it "notifies rails of a request coming in" do
      ActiveSupport::Notifications.should_receive(:instrument).with("start_processing.action_controller", anything).once
      ActiveSupport::Notifications.should_receive(:instrument).with("process_action.action_controller", anything).once
      subject.process_action(:index)
    end

    context "request context has custom fields defined" do
      before :each do
        LogStasher.add_custom_fields_to_request_context do |fields|
          fields[:some_field] = 'value'
        end

        ActiveSupport::Notifications.subscribe('process_action.action_controller') do |_, _, _, _, payload|
          @payload = payload
        end
      end

      it "should retain the value in the request context" do
        subject.process_action(:index)
      end

      after :each do
        @payload[:some_field].should == 'value'

        ActionController::Metal.class_eval do
          undef logstasher_add_custom_fields_to_request_context
        end
        ActionController::Base.class_eval do
          undef logstasher_add_custom_fields_to_request_context
        end
      end
    end
  end
end
