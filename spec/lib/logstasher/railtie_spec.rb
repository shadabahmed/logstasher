require 'spec_helper'

require 'action_controller/railtie'
require 'action_controller/log_subscriber'
require 'action_view/railtie'
require 'action_view/log_subscriber'

require 'logstasher/context_wrapper'
require 'logstasher/log_subscriber'
require 'logstasher/railtie'
require 'logstasher/silent_logger'

ENV['RAILS_ENV'] = 'test'

class ::LogStasher::RailtieApp < ::Rails::Application
end

describe ::LogStasher::Railtie do
  let(:config) { described_class.config.logstasher }

  describe 'logstasher.configure' do
    subject do
      described_class.instance.initializers.find do |initializer|
        initializer.name == 'logstasher.configure'
      end
    end

    it 'should configure LogStasher' do
      config.logger                   =  ::Logger.new('/dev/null')
      config.log_level                = "log_level"
      config.enabled                  = "enabled"
      config.include_parameters       = "include_parameters"
      config.silence_standard_logging = "silence_standard_logging"

      ::LogStasher.should_receive(:enabled=).with("enabled")
      ::LogStasher.should_receive(:include_parameters=).with("include_parameters")
      ::LogStasher.should_receive(:silence_standard_logging=).with("silence_standard_logging")
      ::LogStasher.should_receive(:logger=).with(config.logger).and_call_original
      config.logger.should_receive(:level=).with("log_level")

      subject.run
    end
  end

  describe 'logstasher.load' do
    subject do
      described_class.instance.initializers.find do |initializer|
        initializer.name == 'logstasher.load'
      end
    end

    context 'when logstasher is disabled' do
      it 'does nothing' do
        ::ActiveSupport.should_not_receive(:on_load)

        subject.run
      end
    end

    context 'when logstasher is enabled' do
      before { ::LogStasher.stub(:enabled?) { true } }

      it 'should load LogStasher into ActionController' do
        ::ActionController.should_receive(:require).with('logstasher/log_subscriber')
        ::ActionController.should_receive(:require).with('logstasher/context_wrapper')
        ::ActionController.should_receive(:include).with(::LogStasher::ContextWrapper)

        subject.run
        ::ActiveSupport.run_load_hooks(:action_controller, ::ActionController)
      end
    end
  end

  describe 'config.after_initialize' do
    context 'when logstasher is enabled' do
      before { ::LogStasher.stub(:enabled?) { true } }

      context 'and silence_standard_logging is enabled' do
        before { ::LogStasher.stub(:silence_standard_logging?) { true } }

        it 'should not silence standard logging' do
          ::ActionController::LogSubscriber.should_receive(:include).with(::LogStasher::SilentLogger)
          ::ActionView::LogSubscriber.should_receive(:include).with(::LogStasher::SilentLogger)
          ::Rails::Rack::Logger.should_receive(:include).with(::LogStasher::SilentLogger)
          ::ActiveSupport.run_load_hooks(:after_initialize, ::LogStasher::RailtieApp)
        end
      end

      context 'and silence_standard_logging is disabled' do
        before { ::LogStasher.stub(:silence_standard_logging?) { false } }

        it 'should not silence standard logging' do
          ::ActionController.should_not_receive(:include).with(::LogStasher::SilentLogger)
          ::ActionView.should_not_receive(:include).with(::LogStasher::SilentLogger)
          ::Rails::Rack::Logger.should_not_receive(:include).with(::LogStasher::SilentLogger)
          ::ActiveSupport.run_load_hooks(:after_initialize, ::LogStasher::RailtieApp)
        end
      end
    end

    context 'when logstasher is disabled' do
      before { ::LogStasher.stub(:enabled?) { false } }

      context 'and silence_standard_logging is enabled' do
        before { ::LogStasher.stub(:silence_standard_logging?) { true } }

        it 'should not silence standard logging' do
          ::ActionController::LogSubscriber.should_not_receive(:include).with(::LogStasher::SilentLogger)
          ::ActionView::LogSubscriber.should_not_receive(:include).with(::LogStasher::SilentLogger)
          ::Rails::Rack::Logger.should_not_receive(:include).with(::LogStasher::SilentLogger)
          ::ActiveSupport.run_load_hooks(:after_initialize, ::LogStasher::RailtieApp)
        end
      end

      context 'and silence_standard_logging is disabled' do
        before { ::LogStasher.stub(:silence_standard_logging?) { false } }

        it 'should not silence standard logging' do
          ::ActionController.should_not_receive(:include).with(::LogStasher::SilentLogger)
          ::ActionView.should_not_receive(:include).with(::LogStasher::SilentLogger)
          ::Rails::Rack::Logger.should_not_receive(:include).with(::LogStasher::SilentLogger)
          ::ActiveSupport.run_load_hooks(:after_initialize, ::LogStasher::RailtieApp)
        end
      end
    end
  end
end
