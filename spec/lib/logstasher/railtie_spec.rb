require 'spec_helper'

require 'logstasher/railtie'
require 'logstasher/log_subscriber'
require 'logstasher/context_wrapper'

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

    it 'does nothing by default' do
      ::ActiveSupport.should_not_receive(:on_load)
      described_class.instance.should_not_receive(:silence_standard_logging)

      subject.run
    end

    context 'when logstasher is enabled' do
      before { ::LogStasher.stub(:enabled?) { true } }

      it 'should load LogStasher into ActionController' do
        ::ActiveSupport.should_receive(:on_load) do |&block|
          ::ActionController.should_receive(:require).with('logstasher/log_subscriber')
          ::ActionController.should_receive(:require).with('logstasher/context_wrapper')
          ::ActionController.should_receive(:include).with(::LogStasher::ContextWrapper)
          ::ActionController.instance_eval(&block)
        end

        subject.run
      end

      it 'should silence standard logging when requested' do
        ::LogStasher.stub(:silence_standard_logging?) { true }
        described_class.instance.should_receive(:silence_standard_logging)
        subject.run
      end

      it 'should not silence standard logging by default' do
        described_class.instance.should_not_receive(:silence_standard_logging)
        subject.run
      end
    end
  end
end
