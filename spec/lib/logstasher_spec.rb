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

  describe '.setup' do
    let(:logger) { double }
    let(:logstasher_config) { double(:logger => logger,:log_level => 'warn',:log_controller_parameters => nil) }
    let(:config) { double(:logstasher => logstasher_config) }
    let(:app) { double(:config => config) }
    before do
      config.stub(:action_dispatch => double(:rack_cache => false))
    end
    it 'defines a method in ActionController::Base' do
      LogStasher.should_receive(:suppress_app_logs).with(app)
      LogStasher::LogSubscriber.should_receive(:attach_to).with(:action_controller)
      ActionController::Base.should_receive(:send).with(:include, ActionController::LogStasher)
      logger.should_receive(:level=).with('warn')
      LogStasher.setup(app)
      LogStasher.enabled.should be_true
      LogStasher.log_controller_parameters.should == false
    end
  end

  describe '.suppress_app_logs' do
    let(:logstasher_config){ double(:logstasher => double(:suppress_app_log => true))}
    let(:app){ double(:config => logstasher_config)}
    it 'removes existing subscription if enabled' do
      Rails::Rack::Logger.should_receive(:logger=).with(an_instance_of(Logger))
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

  describe '.log' do
    let(:logger) { ::Logger.new('/dev/null') }
    let(:timestamp) { ::Time.new.utc.iso8601(3) }

    it 'adds to log with specified level' do
      ::LogStasher.stub(:logger => logger)
      ::LogStash::Time.stub(:now => timestamp)

      logger.should_receive(:warn) do |json|
        JSON.parse(json).should eq ({
          '@source' => 'unknown',
          '@timestamp' => timestamp,
          '@tags' => ['log'],
          '@fields' => {
            'message' => 'WARNING',
            'level'   => 'warn'
          }
        })
      end

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
