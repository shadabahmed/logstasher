require "spec_helper"

require "logstasher/device"
require "logstasher/device/redis"
require "logstasher/device/syslog"

describe LogStasher::Device do
  describe ".factory" do
    it "expects a type" do
      expect {
        ::LogStasher::Device.factory(:no => "type given")
      }.to raise_error(ArgumentError, 'No "type" given')
    end

    it "forwards configuration options to the device" do
      ::LogStasher::Device::Redis.should_receive(:new).with(
        'options' => "other", 'than' => "type"
      )
      ::LogStasher::Device.factory(
        'type' => 'redis', 'options' => 'other', :than => "type"
      )
    end

    it "accepts symbolized configuration keys" do
      ::LogStasher::Device::Redis.should_receive(:new).with(
        'options' => "other", 'than' => "type"
      )
      ::LogStasher::Device.factory(
        :type => "redis", :options => "other", :than => "type"
      )
    end

    it "can create redis devices" do
      ::LogStasher::Device.should_receive(:require)
                          .with("logstasher/device/redis")

      device = ::LogStasher::Device.factory(:type => "redis")
      device.should be_a_kind_of(::LogStasher::Device::Redis)
    end

    it "can create syslog devices" do
      ::LogStasher::Device.should_receive(:require)
                          .with("logstasher/device/syslog")

      device = ::LogStasher::Device.factory(:type => "syslog")
      device.should be_a_kind_of(::LogStasher::Device::Syslog)
    end

    it "fails to create unknown devices" do
      expect {
        ::LogStasher::Device.factory(:type => "unknown")
      }.to raise_error(ArgumentError, "Unknown type: unknown")
    end
  end
end
