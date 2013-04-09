require 'spec_helper'

describe Logstasher do
  describe "when removing Rails' log subscribers" do
    after do
      ActionController::LogSubscriber.attach_to :action_controller
      ActionView::LogSubscriber.attach_to :action_view
    end

    it "should remove subscribers for controller events" do
      expect {
        Logstasher.remove_existing_log_subscriptions
      }.to change {
        ActiveSupport::Notifications.notifier.listeners_for('process_action.action_controller')
      }
    end

    it "should remove subscribers for all events" do
      expect {
        Logstasher.remove_existing_log_subscriptions
      }.to change {
        ActiveSupport::Notifications.notifier.listeners_for('render_template.action_view')
      }
    end

    it "shouldn't remove subscribers that aren't from Rails" do
      blk = -> {}
      ActiveSupport::Notifications.subscribe("process_action.action_controller", &blk)
      Logstasher.remove_existing_log_subscriptions
      listeners = ActiveSupport::Notifications.notifier.listeners_for('process_action.action_controller')
      listeners.size.should > 0
    end
  end

  describe '.appened_default_info_to_payload' do
    let(:params)  { {'a' => '1', 'b' => 2, 'action' => 'action', 'controller' => 'test'}.with_indifferent_access }
    let(:payload) { {:params => params} }
    let(:request) { mock(:params => params, :ip => '10.0.0.1')}
    after do
      Logstasher.appended_params = []
    end
    it 'appends default parameters to payload' do
      Logstasher.appended_params = []
      Logstasher.append_default_info_to_payload(payload, request)
      payload[:ip].should == '10.0.0.1'
      payload[:route].should == 'test#action'
      payload[:parameters].should == "a=1\nb=2\n"
      Logstasher.appended_params.should == [:ip, :route, :parameters]
    end
  end

  describe '.append_custom_params' do
    let(:block) { ->{} }
    it 'defines a method in ActionController::Base' do
      ActionController::Base.should_receive(:send).with(:define_method, :logtasher_append_custom_info_to_payload, &block)
      Logstasher.append_custom_params(&block)
    end
  end

  describe '.setup' do
    let(:logger) { mock }
    let(:logstasher_config) { mock(:logger => logger,:log_level => 'warn') }
    let(:config) { mock(:logstasher => logstasher_config) }
    let(:app) { mock(:config => config) }
    before do
      config.stub(:action_dispatch => mock(:rack_cache => false))
    end
    it 'defines a method in ActionController::Base' do
      Logstasher.should_receive(:require).with('logstasher/rails_ext/action_controller/metal/instrumentation')
      Logstasher.should_receive(:require).with('logstash/event')
      Logstasher.should_receive(:suppress_app_logs).with(app)
      Logstasher::RequestLogSubscriber.should_receive(:attach_to).with(:action_controller)
      logger.should_receive(:level=).with('warn')
      Logstasher.setup(app)
      Logstasher.enabled.should be_true
      Logstasher.appended_params.should == []
    end
  end

  describe '.supress_app_logs' do
    let(:logstasher_config){ mock(:logstasher => mock(:supress_app_log => true))}
    let(:app){ mock(:config => logstasher_config)}
    it 'removes existing subscription if enabled' do
      Logstasher.should_receive(:require).with('logstasher/rails_ext/rack/logger')
      Logstasher.should_receive(:remove_existing_log_subscriptions)
      Logstasher.suppress_app_logs(app)
    end
  end

  describe '.appended_params' do
    it 'returns the stored var in current thread' do
      Thread.current[:logstasher_appended_params] = :test
      Logstasher.appended_params.should == :test
    end
  end

  describe '.appended_params=' do
    it 'returns the stored var in current thread' do
      Logstasher.appended_params = :test
      Thread.current[:logstasher_appended_params].should == :test
    end
  end

  describe '.log' do
    let(:logger) { mock() }
    before do
      Logstasher.logger = logger
      LogStash::Time.stub(:now => 'timestamp')
    end
    it 'adds to log with specified level' do
      logger.should_receive(:send).with('warn?').and_return(true)
      logger.should_receive(:send).with('warn',"{\"@source\":\"unknown\",\"@tags\":[\"log\"],\"@fields\":{\"message\":\"WARNING\",\"level\":\"warn\"},\"@timestamp\":\"timestamp\"}")
      Logstasher.log('warn', 'WARNING')
    end
  end

  %w( fatal error warn info debug unknown ).each do |severity|
    describe ".#{severity}" do
      let(:message) { "This is a #{severity} message" }
      it 'should log with specified level' do
        Logstasher.should_receive(:log).with(severity.to_sym, message)
        Logstasher.send(severity, message )
      end
    end
  end
end
