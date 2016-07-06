require 'spec_helper'
require 'logstasher/rails_ext/action_controller/base'

describe ActionController::Base do
  before do
    class MyController < ActionController::Base
      include LogStasher::ActionController::Instrumentation

      def index(*args)
        render text: 'OK'
      end
    end
  end

  describe 'process_action' do
    subject { MyController.new }

    before :each do
      subject.request = ActionDispatch::TestRequest.new
      subject.response = ActionDispatch::TestResponse.new

      LogStasher.add_custom_fields_to_request_context do |fields|
        fields[:some_field] = 'value'
      end

      ActiveSupport::Notifications.subscribe('process_action.action_controller') do |_, _, _, _, payload|
        @payload = payload
      end
    end

    2.times do
      it 'stays constant with custom_fields' do
        subject.process_action(:index)
        expect(Thread.current[:logstasher_custom_fields]).to eq []
      end
    end
    after :each do
      expect(@payload[:some_field]).to eq('value')
    end
  end
end
