require 'spec_helper'

require 'logstasher/device/syslog'

describe LogStasher::Device::Syslog do

  let(:default_options) {{
    'identity' => 'logstasher',
    'facility' => ::Syslog::LOG_LOCAL0,
    'priority' => ::Syslog::LOG_INFO,
    'flags'    => ::Syslog::LOG_PID | ::Syslog::LOG_CONS
  }}

  before { ::Syslog.stub(:log) }

  around do |example|
    ::Syslog.close if ::Syslog.opened?
    example.run
    ::Syslog.close if ::Syslog.opened?
  end

  it 'has default options' do
    device = LogStasher::Device::Syslog.new
    device.options.should eq(default_options)
  end

  it 'has an identity' do
    device = LogStasher::Device::Syslog.new(:identity => 'rspec')
    device.identity.should eq 'rspec'
  end

  it 'has a facility' do
    device = LogStasher::Device::Syslog.new(:facility => ::Syslog::LOG_USER)
    device.facility.should eq ::Syslog::LOG_USER
  end

  it 'accepts facility as a string' do
    device = LogStasher::Device::Syslog.new(:facility => 'LOG_LOCAL7')
    device.facility.should eq ::Syslog::LOG_LOCAL7
  end

  it 'has a priority' do
    device = LogStasher::Device::Syslog.new(:priority => ::Syslog::LOG_CRIT)
    device.priority.should eq ::Syslog::LOG_CRIT
  end

  it 'accepts priority as a string' do
    device = LogStasher::Device::Syslog.new(:priority => 'LOG_AUTH')
    device.priority.should eq ::Syslog::LOG_AUTH
  end

  it 'has flags' do
    device = LogStasher::Device::Syslog.new(:flags => ::Syslog::LOG_NOWAIT)
    device.flags.should eq ::Syslog::LOG_NOWAIT
  end

  it 'accepts flags as a string' do
    device = LogStasher::Device::Syslog.new(:flags => 'LOG_NDELAY')
    device.flags.should eq ::Syslog::LOG_NDELAY
  end

  it 'accepts flags as an array of strings' do
    device = LogStasher::Device::Syslog.new(:flags => ['LOG_NOWAIT', 'LOG_ODELAY'])
    device.flags.should eq(::Syslog::LOG_NOWAIT | ::Syslog::LOG_ODELAY)
  end

  describe '#write' do
    subject { LogStasher::Device::Syslog.new }

    it 'opens syslog when syslog is closed' do
      ::Syslog.should_receive(:open).with(subject.identity, subject.flags, subject.facility)
      subject.write('a log')
    end

    it 'does not re-open syslog when its config is in sync' do
      ::Syslog.open(subject.identity, subject.flags, subject.facility)
      ::Syslog.should_not_receive(:open)
      ::Syslog.should_not_receive(:reopen)
      subject.write('a log')
    end

    it 're-opens syslog when its config is out of sync' do
      ::Syslog.open('temp', ::Syslog::LOG_NDELAY, ::Syslog::LOG_AUTH)
      ::Syslog.should_receive(:reopen).with(subject.identity, subject.flags, subject.facility)
      subject.write('a log')
    end

    it 'writes the log to syslog' do
      ::Syslog.should_receive(:log).with(subject.facility, 'a log')
      subject.write('a log')
    end

    it 'fails when the device is closed' do
      subject.close
      expect {
        subject.write('a log')
      }.to raise_error(::RuntimeError, 'Cannot write. The device has been closed.')
    end
  end

  describe '#close' do
    subject { LogStasher::Device::Syslog.new }

    it 'closes the device' do
      subject.close
      subject.should be_closed
    end

    it 'closes syslog when syslog is open' do
      ::Syslog.open(subject.identity, subject.flags, subject.facility)
      ::Syslog.should_receive(:close)
      subject.close
    end

    it 'does not close syslog if it is already closed' do
      ::Syslog.should_not_receive(:close)
      subject.close
    end
  end
end
