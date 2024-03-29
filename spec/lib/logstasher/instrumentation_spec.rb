# frozen_string_literal: true

require 'spec_helper'
require 'logstasher/rails_ext/action_controller/metal/instrumentation'

describe ActionController::Base do
  before do
    # Revert the monkey patch again
    module ActionController
      module Instrumentation
        alias process_action logstasher_process_action
      end
    end
  end
  before :each do
    subject.request = ActionDispatch::TestRequest.create
    subject.response = ActionDispatch::TestResponse.create

    def subject.index(*_args)
      render plain: 'OK'
    end
  end

  describe '.process_action' do
    it 'adds default fields to payload' do
      expect(LogStasher).to receive(:add_default_fields_to_payload).once
      expect(LogStasher).to receive(:add_default_fields_to_request_context).once
      subject.send(:process_action, :index)
    end

    it 'creates the request context before processing' do
      LogStasher.request_context[:some_key] = 'value'
      expect(LogStasher).to receive(:clear_request_context).once.and_call_original
      expect do
        subject.send(:process_action, :index)
      end.to change { LogStasher.request_context }
    end

    it 'notifies rails of a request coming in' do
      expect(ActiveSupport::Notifications).to receive(:instrument).with('start_processing.action_controller',
                                                                        anything).once
      expect(ActiveSupport::Notifications).to receive(:instrument).with('process_action.action_controller',
                                                                        anything).once
      subject.send(:process_action, :index)
    end

    context 'request context has custom fields defined' do
      before :each do
        LogStasher.add_custom_fields_to_request_context do |fields|
          fields[:some_field] = 'value'
        end

        ActiveSupport::Notifications.subscribe('process_action.action_controller') do |_, _, _, _, payload|
          @payload = payload
        end
      end

      it 'should retain the value in the request context' do
        subject.send(:process_action, :index)
      end

      after :each do
        expect(@payload[:some_field]).to eq('value')

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
