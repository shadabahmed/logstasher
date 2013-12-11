require 'spec_helper'

describe LogStasher do
  describe "when removing Rails' log subscribers" do
    after do
      ActionController::LogSubscriber.attach_to :action_controller
      ActionView::LogSubscriber.attach_to :action_view
    end

    it "should remove subscribers for controller events" do
      expect {
        LogStasher.remove_existing_log_subscriptions
      }.to change {
        ActiveSupport::Notifications.notifier.listeners_for('process_action.action_controller')
      }
    end

    it "should remove subscribers for all events" do
      expect {
        LogStasher.remove_existing_log_subscriptions
      }.to change {
        ActiveSupport::Notifications.notifier.listeners_for('render_template.action_view')
      }
    end

    it "shouldn't remove subscribers that aren't from Rails" do
      blk = -> {}
      ActiveSupport::Notifications.subscribe("process_action.action_controller", &blk)
      LogStasher.remove_existing_log_subscriptions
      listeners = ActiveSupport::Notifications.notifier.listeners_for('process_action.action_controller')
      listeners.size.should > 0
    end
  end

  describe '.appened_default_info_to_payload' do
    let(:params)  { {'a' => '1', 'b' => 2, 'action' => 'action', 'controller' => 'test'}.with_indifferent_access }
    let(:payload) { {:params => params} }
    let(:request) { double(:params => params, :remote_ip => '10.0.0.1')}
    after do
      LogStasher.custom_fields = []
    end
    it 'appends default parameters to payload' do
      LogStasher.custom_fields = []
      LogStasher.add_default_fields_to_payload(payload, request)
      payload[:ip].should == '10.0.0.1'
      payload[:route].should == 'test#action'
      payload[:parameters].should == {'a' => '1', 'b' => 2}
      LogStasher.custom_fields.should == [:ip, :route, :parameters]
    end
  end

  describe '.append_custom_params' do
    let(:block) { ->{} }
    it 'defines a method in ActionController::Base' do
      ActionController::Base.should_receive(:send).with(:define_method, :logtasher_add_custom_fields_to_payload, &block)
      LogStasher.add_custom_fields(&block)
    end
  end

  describe '.setup' do
    let(:logger) { double }
    let(:logstasher_config) { double(:logger => logger,:log_level => 'warn') }
    let(:config) { double(:logstasher => logstasher_config) }
    let(:app) { double(:config => config) }
    before do
      config.stub(:action_dispatch => double(:rack_cache => false))
    end
    it 'defines a method in ActionController::Base' do
      LogStasher.should_receive(:require).with('logstasher/rails_ext/action_controller/metal/instrumentation')
      LogStasher.should_receive(:require).with('logstash-event')
      LogStasher.should_receive(:suppress_app_logs).with(app)
      LogStasher::RequestLogSubscriber.should_receive(:attach_to).with(:action_controller)
      logger.should_receive(:level=).with('warn')
      LogStasher.setup(app)
      LogStasher.enabled.should be_true
      LogStasher.custom_fields.should == []
    end
  end

  describe '.suppress_app_logs' do
    let(:logstasher_config){ double(:logstasher => double(:suppress_app_log => true))}
    let(:app){ double(:config => logstasher_config)}
    it 'removes existing subscription if enabled' do
      LogStasher.should_receive(:require).with('logstasher/rails_ext/rack/logger')
      LogStasher.should_receive(:remove_existing_log_subscriptions)
      LogStasher.suppress_app_logs(app)
    end

    context 'when disabled' do
      let(:logstasher_config){ double(:logstasher => double(:suppress_app_log => false)) }
      it 'does not remove existing subscription' do
        LogStasher.should_not_receive(:remove_existing_log_subscriptions)
        LogStasher.suppress_app_logs(app)
      end

      describe "backward compatibility" do
        context 'with spelling "supress_app_log"' do
          let(:logstasher_config){ double(:logstasher => double(:suppress_app_log => nil, :supress_app_log => false)) }
          it 'does not remove existing subscription' do
            LogStasher.should_not_receive(:remove_existing_log_subscriptions)
            LogStasher.suppress_app_logs(app)
          end
        end
      end
    end
  end

  describe '.appended_params' do
    it 'returns the stored var in current thread' do
      Thread.current[:logstasher_custom_fields] = :test
      LogStasher.custom_fields.should == :test
    end
  end

  describe '.appended_params=' do
    it 'returns the stored var in current thread' do
      LogStasher.custom_fields = :test
      Thread.current[:logstasher_custom_fields].should == :test
    end
  end

  describe '.log' do
    let(:logger) { double() }
    before do
      LogStasher.logger = logger
      LogStash::Time.stub(:now => 'timestamp')
    end
    it 'adds to log with specified level' do
      logger.should_receive(:send).with('warn?').and_return(true)
      logger.should_receive(:send).with('warn',"{\"@source\":\"unknown\",\"@tags\":[\"log\"],\"@fields\":{\"message\":\"WARNING\",\"level\":\"warn\"},\"@timestamp\":\"timestamp\"}")
      LogStasher.log('warn', 'WARNING')
    end
  end

  %w( fatal error warn info debug unknown ).each do |severity|
    describe ".#{severity}" do
      let(:message) { "This is a #{severity} message" }
      it 'should log with specified level' do
        LogStasher.should_receive(:log).with(severity.to_sym, message)
        LogStasher.send(severity, message )
      end
    end
  end
end
