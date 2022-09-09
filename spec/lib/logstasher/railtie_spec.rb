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

  describe 'logstasher should touch log file to prevent creation message by default' do
    it 'should configure LogStasher' do
      expect(::FileUtils).to receive(:touch)
      ActiveSupport.run_load_hooks(:before_initialize)
    end
  end

  describe 'logstasher should NOT touch log file if silence disabled' do
    before { config.silence_creation_message = false }
    after { config.silence_creation_message = true }

    it 'should configure LogStasher' do
      expect(::FileUtils).not_to receive(:touch)
      ActiveSupport.run_load_hooks(:before_initialize)
    end
  end


  describe 'logstasher.configure' do
    it 'should configure LogStasher' do
      config.logger                   = ::Logger.new('/dev/null')
      config.log_level                = "log_level"
      config.enabled                  = "enabled"
      config.include_parameters       = "include_parameters"
      config.serialize_parameters     = "serialize_parameters"
      config.silence_standard_logging = "silence_standard_logging"

      expect(::LogStasher).to receive(:enabled=).with("enabled")
      expect(::LogStasher).to receive(:include_parameters=).with("include_parameters")
      expect(::LogStasher).to receive(:serialize_parameters=).with("serialize_parameters")
      expect(::LogStasher).to receive(:silence_standard_logging=).with("silence_standard_logging")
      expect(::LogStasher).to receive(:logger=).with(config.logger).and_call_original
      expect(config.logger).to receive(:level=).with("log_level")

      ActiveSupport.run_load_hooks(:before_initialize)
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
        expect(::ActiveSupport).not_to receive(:on_load)

        subject.run
      end
    end

    context 'when logstasher is enabled' do
      before { allow(::LogStasher).to receive(:enabled?) { true } }

      it 'should load LogStasher into ActionController' do
        expect(::ActionController).to receive(:require).with('logstasher/log_subscriber')
        expect(::ActionController).to receive(:require).with('logstasher/context_wrapper')
        expect(::ActionController).to receive(:include).with(::LogStasher::ContextWrapper)

        subject.run
        ::ActiveSupport.run_load_hooks(:action_controller, ::ActionController)
      end
    end
  end

  describe 'config.after_initialize' do
    context 'when logstasher is enabled' do
      before { allow(::LogStasher).to receive(:enabled?) { true } }

      context 'and silence_standard_logging is enabled' do
        before { allow(::LogStasher).to receive(:silence_standard_logging?) { true } }

        it 'should not silence standard logging' do
          expect(::ActionController::LogSubscriber).to receive(:include).with(::LogStasher::SilentLogger)
          expect(::ActionView::LogSubscriber).to receive(:include).with(::LogStasher::SilentLogger)
          expect(::Rails::Rack::Logger).to receive(:include).with(::LogStasher::SilentLogger)
          ::ActiveSupport.run_load_hooks(:after_initialize, ::LogStasher::RailtieApp)
        end
      end

      context 'and silence_standard_logging is disabled' do
        before { allow(::LogStasher).to receive(:silence_standard_logging?) { false } }

        it 'should not silence standard logging' do
          expect(::ActionController).not_to receive(:include).with(::LogStasher::SilentLogger)
          expect(::ActionView).not_to receive(:include).with(::LogStasher::SilentLogger)
          expect(::Rails::Rack::Logger).not_to receive(:include).with(::LogStasher::SilentLogger)
          ::ActiveSupport.run_load_hooks(:after_initialize, ::LogStasher::RailtieApp)
        end
      end
    end

    context 'when logstasher is disabled' do
      before { allow(::LogStasher).to receive(:enabled?) { false } }

      context 'and silence_standard_logging is enabled' do
        before { allow(::LogStasher).to receive(:silence_standard_logging?) { true } }

        it 'should not silence standard logging' do
          expect(::ActionController::LogSubscriber).not_to receive(:include).with(::LogStasher::SilentLogger)
          expect(::ActionView::LogSubscriber).not_to receive(:include).with(::LogStasher::SilentLogger)
          expect(::Rails::Rack::Logger).not_to receive(:include).with(::LogStasher::SilentLogger)
          ::ActiveSupport.run_load_hooks(:after_initialize, ::LogStasher::RailtieApp)
        end
      end

      context 'and silence_standard_logging is disabled' do
        before { allow(::LogStasher).to receive(:silence_standard_logging?) { false } }

        it 'should not silence standard logging' do
          expect(::ActionController).not_to receive(:include).with(::LogStasher::SilentLogger)
          expect(::ActionView).not_to receive(:include).with(::LogStasher::SilentLogger)
          expect(::Rails::Rack::Logger).not_to receive(:include).with(::LogStasher::SilentLogger)
          ::ActiveSupport.run_load_hooks(:after_initialize, ::LogStasher::RailtieApp)
        end
      end
    end
  end
end
