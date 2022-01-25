require 'spec_helper'

require 'logstasher/device/udp'

describe LogStasher::Device::UDP do

  let(:default_options) {{
                           'hostname' => '127.0.0.1',
                           'port' => 31459,
                           'namespace' => 'test'
                         }}

  it 'has default options' do
    device = LogStasher::Device::UDP.new
    expect(device.options).to eq(default_options)
  end

  it 'closes the udp socket on #close' do
    device = LogStasher::Device::UDP.new
    expect(device.socket).to receive(:close)
    device.close
  end

  it 'works as a logger device' do
    device = LogStasher::Device::UDP.new
    expect(device).to receive(:write).with('foo')
    logger = Logger.new(device)
    logger << 'foo'
  end

  describe '#write' do
    subject { LogStasher::Device::UDP.new }
    it 'writes the log to the the socket' do
      expect(subject.socket).to receive(:send).with('a log', 0, default_options['hostname'], default_options['port'])
      subject.write('a log')
    end
  end  
end
