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
    device.options.should eq(default_options)
  end

  it 'creates a redis instance' do
    ::Redis.should_receive(:new).with({})
    LogStasher::Device::Redis.new()
  end

  it 'assumes unknown options are for redis' do
    ::Redis.should_receive(:new).with(hash_including(db: '0'))
    device = LogStasher::Device::Redis.new(db: '0')
    device.redis_options.should eq(db: '0')
  end

  it 'has a key' do
    device = LogStasher::Device::Redis.new(key: 'the_key')
    device.key.should eq 'the_key'
  end

  it 'has a data_type' do
    device = LogStasher::Device::Redis.new(data_type: 'channel')
    device.data_type.should eq 'channel'
  end

  it 'does not allow unsupported data types' do
    expect {
      device = LogStasher::Device::Redis.new(data_type: 'blargh')
    }.to raise_error()
  end

  it 'quits the redis connection on #close' do
    device = LogStasher::Device::Redis.new
    device.redis.should_receive(:quit)
    device.close
  end

  it 'works as a logger device' do
    device = LogStasher::Device::Redis.new
    device.should_receive(:write).with('blargh')
    logger = Logger.new(device)
    logger << 'blargh'
  end

  describe '#write' do
    it "rpushes logs onto a list" do
      device = LogStasher::Device::Redis.new(data_type: 'list')
      device.redis.should_receive(:rpush).with('logstash', 'the log')
      device.write('the log')
    end

    it "rpushes logs onto a custom key" do
      device = LogStasher::Device::Redis.new(data_type: 'list', key: 'custom')
      device.redis.should_receive(:rpush).with('custom', 'the log')
      device.write('the log')
    end

    it "publishes logs onto a channel" do
      device = LogStasher::Device::Redis.new(data_type: 'channel', key: 'custom')
      device.redis.should_receive(:publish).with('custom', 'the log')
      device.write('the log')
    end
  end

end
