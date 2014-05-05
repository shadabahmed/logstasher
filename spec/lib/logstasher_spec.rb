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
      LogStasher.log_controller_parameters = false
    end
    it 'appends default parameters to payload' do
      LogStasher.log_controller_parameters = true
      LogStasher.custom_fields = []
      LogStasher.add_default_fields_to_payload(payload, request)
      payload[:ip].should == '10.0.0.1'
      payload[:route].should == 'test#action'
      payload[:parameters].should == {'a' => '1', 'b' => 2}
      LogStasher.custom_fields.should == [:ip, :route, :parameters]
    end

    it 'does not include parameters when not configured to' do
      LogStasher.custom_fields = []
      LogStasher.add_default_fields_to_payload(payload, request)
      payload.should_not have_key(:parameters)
      LogStasher.custom_fields.should == [:ip, :route]
    end
  end

  describe '.append_custom_params' do
    let(:block) { ->{} }
    it 'defines a method in ActionController::Base' do
      ActionController::Base.should_receive(:send).with(:define_method, :logtasher_add_custom_fields_to_payload, &block)
      LogStasher.add_custom_fields(&block)
    end
  end

  shared_examples 'setup' do
    let(:logger) { double }
    let(:logstasher_config) { double(:logger => logger, :log_level => 'warn', :log_controller_parameters => nil, :source => logstasher_source) }
    let(:config) { double(:logstasher => logstasher_config) }
    let(:app) { double(:config => config) }
    before do
      @previous_source = LogStasher.source
      config.stub(:action_dispatch => double(:rack_cache => false))
    end
    after { LogStasher.source = @previous_source } # Need to restore old source for specs
    it 'defines a method in ActionController::Base' do
      LogStasher.should_receive(:require).with('logstasher/rails_ext/action_controller/metal/instrumentation')
      LogStasher.should_receive(:require).with('logstash-event')
      LogStasher.should_receive(:suppress_app_logs).with(app)
      LogStasher::RequestLogSubscriber.should_receive(:attach_to).with(:action_controller)
      logger.should_receive(:level=).with('warn')
      LogStasher.setup(app)
      LogStasher.source.should == (logstasher_source || 'unknown')
      LogStasher.enabled.should be_true
      LogStasher.custom_fields.should == []
      LogStasher.log_controller_parameters.should == false
    end
  end

  describe '.setup' do
    describe 'with source set' do
      let(:logstasher_source) { 'foo' }
      it_behaves_like 'setup'
    end

    describe 'without source set (default behaviour)' do
      let(:logstasher_source) { nil }
      it_behaves_like 'setup'
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
    context 'with a source specified' do
      before :each do
        LogStasher.source = 'foo'
      end
      it 'sets the correct source' do
        logger.should_receive(:send).with('warn?').and_return(true)
        logger.should_receive(:send).with('warn',"{\"@source\":\"foo\",\"@tags\":[\"log\"],\"@fields\":{\"message\":\"WARNING\",\"level\":\"warn\"},\"@timestamp\":\"timestamp\"}")
        LogStasher.log('warn', 'WARNING')
      end
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

  describe '.store' do
    it "returns a new Hash for each key" do
      expect(LogStasher.store['a'].object_id).to_not be(LogStasher.store['b'].object_id)
    end

    it "returns the same store if called several time with the same key" do
      expect(LogStasher.store['a'].object_id).to be(LogStasher.store['a'].object_id)
    end

  end

  describe ".watch" do
    before(:each) { LogStasher.custom_fields = [] }

    it "subscribes to the required event" do
      ActiveSupport::Notifications.should_receive(:subscribe).with('event_name')
      LogStasher.watch('event_name')
    end

    it 'executes the block when receiving an event' do
      probe = lambda {}
      LogStasher.watch('custom.event.foo', &probe)
      expect(probe).to receive(:call)
      ActiveSupport::Notifications.instrument('custom.event.foo', {})
    end

    describe "store" do
      it 'stores the events in a store with the event\'s name' do
        probe = lambda { |*args, store| store[:foo] = :bar }
        LogStasher.watch('custom.event.bar', &probe)
        ActiveSupport::Notifications.instrument('custom.event.bar', {})
        LogStasher.store['custom.event.bar'].should == {:foo => :bar}
      end
    end
  end
end
