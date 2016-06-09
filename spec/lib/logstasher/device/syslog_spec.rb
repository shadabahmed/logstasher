require 'spec_helper'

require 'logstasher/device/syslog'

describe LogStasher::Device::Syslog do

  let(:default_options) {{
    'identity' => 'logstasher',
    'facility' => ::Syslog::LOG_LOCAL0,
    'priority' => ::Syslog::LOG_INFO,
    'flags'    => ::Syslog::LOG_PID | ::Syslog::LOG_CONS
  }}

  before { allow(::Syslog).to receive(:log) }

  around do |example|
    ::Syslog.close rescue nil
    example.run
    ::Syslog.close rescue nil
  end

  it 'has default options' do
    device = LogStasher::Device::Syslog.new
    expect(device.options).to eq(default_options)
  end

  it 'has an identity' do
    device = LogStasher::Device::Syslog.new(:identity => 'rspec')
    expect(device.identity).to eq 'rspec'
  end

  it 'has a facility' do
    device = LogStasher::Device::Syslog.new(:facility => ::Syslog::LOG_USER)
    expect(device.facility).to eq ::Syslog::LOG_USER
  end

  it 'accepts facility as a string' do
    device = LogStasher::Device::Syslog.new(:facility => 'LOG_LOCAL7')
    expect(device.facility).to eq ::Syslog::LOG_LOCAL7
  end

  it 'has a priority' do
    device = LogStasher::Device::Syslog.new(:priority => ::Syslog::LOG_CRIT)
    expect(device.priority).to eq ::Syslog::LOG_CRIT
  end

  it 'accepts priority as a string' do
    device = LogStasher::Device::Syslog.new(:priority => 'LOG_AUTH')
    expect(device.priority).to eq ::Syslog::LOG_AUTH
  end

  it 'has flags' do
    device = LogStasher::Device::Syslog.new(:flags => ::Syslog::LOG_NOWAIT)
    expect(device.flags).to eq ::Syslog::LOG_NOWAIT
  end

  it 'accepts flags as a string' do
    device = LogStasher::Device::Syslog.new(:flags => 'LOG_NDELAY')
    expect(device.flags).to eq ::Syslog::LOG_NDELAY
  end

  it 'accepts flags as an array of strings' do
    device = LogStasher::Device::Syslog.new(:flags => ['LOG_NOWAIT', 'LOG_ODELAY'])
    expect(device.flags).to eq(::Syslog::LOG_NOWAIT | ::Syslog::LOG_ODELAY)
  end

  it 'opens syslog when it is closed' do
    expect(::Syslog).to receive(:open).with(
      default_options['identity'],
      default_options['flags'],
      default_options['facility'],
    )

    LogStasher::Device::Syslog.new
  end

  it 're-opens syslog when it is already opened' do
    ::Syslog.open('temp', ::Syslog::LOG_NDELAY, ::Syslog::LOG_AUTH)

    expect(::Syslog).to receive(:reopen).with(
      default_options['identity'],
      default_options['flags'],
      default_options['facility'],
    )

    LogStasher::Device::Syslog.new
  end

  describe '#write' do
    subject { LogStasher::Device::Syslog.new }

    it 'fails when the syslog config is out of sync' do
      subject
      ::Syslog.reopen('temp', ::Syslog::LOG_NDELAY, ::Syslog::LOG_AUTH)
      expect {
        subject.write('a log')
      }.to raise_error(::RuntimeError, 'Syslog re-configured unexpectedly.')
    end

    it 'writes the log to syslog' do
      expect(::Syslog).to receive(:log).with(subject.priority, '%s', 'a log')
      subject.write('a log')
    end

    it 'fails when the device is closed' do
      subject.close
      expect {
        subject.write('a log')
      }.to raise_error(::RuntimeError, 'Syslog has been closed.')
    end
  end

  describe '#close' do
    subject { LogStasher::Device::Syslog.new }

    it 'closes the device' do
      subject.close
      expect(subject).to be_closed
    end

    it 'closes syslog' do
      expect(::Syslog).to receive(:close)
      subject.close
    end
  end
end
