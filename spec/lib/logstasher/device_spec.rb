require "spec_helper"

require "logstasher/device"
require "logstasher/device/redis"
require "logstasher/device/syslog"
require "logstasher/device/udp"

describe LogStasher::Device do
  describe ".factory" do
    it "expects a type" do
      expect {
        ::LogStasher::Device.factory(:no => "type given")
      }.to raise_error(ArgumentError, 'No "type" given')
    end

    it "forwards configuration options to the device" do
      expect(::LogStasher::Device::Redis).to receive(:new).with(
        'options' => "other", 'than' => "type"
      )
      ::LogStasher::Device.factory(
        'type' => 'redis', 'options' => 'other', :than => "type"
      )
    end

    it "accepts symbolized configuration keys" do
      expect(::LogStasher::Device::Redis).to receive(:new).with(
        'options' => "other", 'than' => "type"
      )
      ::LogStasher::Device.factory(
        :type => "redis", :options => "other", :than => "type"
      )
    end

    it "can create redis devices" do
      expect(
        ::LogStasher::Device
      ).to receive(:require).with("logstasher/device/redis")

      device = ::LogStasher::Device.factory(:type => "redis")
      expect(device).to be_a_kind_of(::LogStasher::Device::Redis)
    end

    it "can create syslog devices" do
      expect(
        ::LogStasher::Device
       ).to receive(:require).with("logstasher/device/syslog")

      device = ::LogStasher::Device.factory(:type => "syslog")
      expect(device).to be_a_kind_of(::LogStasher::Device::Syslog)
    end
    
    it "can create udp devices" do
      expect(
        ::LogStasher::Device
       ).to receive(:require).with("logstasher/device/udp")

      device = ::LogStasher::Device.factory(:type => "udp")
      expect(device).to be_a_kind_of(::LogStasher::Device::UDP)
    end

    it "can create stdout devices" do
      device = ::LogStasher::Device.factory(:type => "stdout")
      expect(device).to eq $stdout
    end
    
    it "fails to create unknown devices" do
      expect {
        ::LogStasher::Device.factory(:type => "unknown")
      }.to raise_error(ArgumentError, "Unknown type: unknown")
    end
  end
end
