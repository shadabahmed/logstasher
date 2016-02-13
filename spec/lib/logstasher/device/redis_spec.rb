require 'spec_helper'

require 'logstasher/device/redis'

describe LogStasher::Device::Redis do

  let(:redis_mock) { double('Redis') }

  let(:default_options) {{
    key: 'logstash',
    data_type: 'list'
  }}

  it 'has default options' do
    device = LogStasher::Device::Redis.new
    expect(device.options).to eq(default_options)
  end

  it 'creates a redis instance' do
    expect(::Redis).to receive(:new).with({})
    LogStasher::Device::Redis.new()
  end

  it 'assumes unknown options are for redis' do
    expect(::Redis).to receive(:new).with(hash_including(db: '0'))
    device = LogStasher::Device::Redis.new(db: '0')
    expect(device.redis_options).to eq(db: '0')
  end

  it 'has a key' do
    device = LogStasher::Device::Redis.new(key: 'the_key')
    expect(device.key).to eq('the_key')
  end

  it 'has a data_type' do
    device = LogStasher::Device::Redis.new(data_type: 'channel')
    expect(device.data_type).to eq('channel')
  end

  it 'does not allow unsupported data types' do
    expect {
      device = LogStasher::Device::Redis.new(data_type: 'blargh')
    }.to raise_error(RuntimeError)
  end

  it 'quits the redis connection on #close' do
    device = LogStasher::Device::Redis.new
    expect(device.redis).to receive(:quit)
    device.close
  end

  it 'works as a logger device' do
    device = LogStasher::Device::Redis.new
    expect(device).to receive(:write).with('blargh')
    logger = Logger.new(device)
    logger << 'blargh'
  end

  describe '#write' do
    it "rpushes logs onto a list" do
      device = LogStasher::Device::Redis.new(data_type: 'list')
      expect(device.redis).to receive(:rpush).with('logstash', 'the log')
      device.write('the log')
    end

    it "rpushes logs onto a custom key" do
      device = LogStasher::Device::Redis.new(data_type: 'list', key: 'custom')
      expect(device.redis).to receive(:rpush).with('custom', 'the log')
      device.write('the log')
    end

    it "publishes logs onto a channel" do
      device = LogStasher::Device::Redis.new(data_type: 'channel', key: 'custom')
      expect(device.redis).to receive(:publish).with('custom', 'the log')
      device.write('the log')
    end
  end

end
