# frozen_string_literal: true

require 'spec_helper'
require 'logstasher/rails_ext/action_controller/base'

describe ActionController::Base do
  shared_examples 'controller.process_action' do
    let(:logger) { instance_double(Logger) }

    before :all do
      LogStasher::ActiveSupport::LogSubscriber.attach_to :action_controller
      LogStasher::ActionView::LogSubscriber.attach_to :action_view
      LogStasher.field_renaming = {}
    end

    before :each do
      subject.request = ActionDispatch::TestRequest.create
      subject.response = ActionDispatch::TestResponse.create

      LogStasher.add_custom_fields_to_request_context do |fields|
        fields[:some_field] = 'value'
      end

      @payload = {}
      ActiveSupport::Notifications.subscribe('process_action.action_controller') do |_, _, _, _, payload|
        @payload = payload
      end
      LogStasher.logger = logger

      allow(logger).to receive(:<<)
      allow(logger).to receive(:debug)
      allow(logger).to receive(:info)
    end

    2.times do |index|
      it 'stays constant with custom_fields' do
        expect(LogStasher).to receive(:build_logstash_event).with(
          hash_including(identifier: 'text template', layout: nil, name: 'render_template.action_view',
                         request_id: index, ip: '0.0.0.0', route: '#'), any_args
        )
        expect(LogStasher).to receive(:build_logstash_event).with(
          hash_including(method: 'GET', path: '/', format: :html, controller: nil, action: nil, status: 200,
                         ip: '0.0.0.0', route: '#', request_id: index, some_field: 'value'), any_args
        )
        subject.request.env['action_dispatch.request_id'] = index
        subject.process_action(:index)
      end
    end

    after :each do
      expect(@payload[:some_field]).to eq('value')
      expect(Thread.current[:logstasher_custom_fields]).to eq []
    end

    after :all do
      ::ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
        case subscriber.class.name
        when 'LogStasher::ActiveSupport::LogSubscriber'
          LogStasher.unsubscribe(:action_controller, subscriber)
        when 'LogStasher::ActionView::LogSubscriber'
          LogStasher.unsubscribe(:action_view, subscriber)
        end
      end
    end
  end

  describe 'instrumented' do
    before do
      class MyController < ActionController::Base
        include LogStasher::ActionController::Instrumentation

        def index(*_args)
          #          ActiveRecord::Base.connection.execute("SELECT true;")
          render plain: 'OK'
        end
      end
    end

    describe 'process_action' do
      subject { MyController.new }
      include_examples 'controller.process_action'
    end
  end

  describe 'monkey patch' do
    before do
      class MyController < ActionController::Base
        def index(*_args)
          render plain: 'OK'
        end
      end
    end

    describe 'process_action' do
      subject { MyController.new }
      include_examples 'controller.process_action'
    end
  end
end
