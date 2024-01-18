require "spec_helper"

describe ::LogStasher do
  describe "#log_as_json" do
    it "calls the logger with the payload" do
      expect(::LogStasher.logger).to receive(:<<) do |json|
        expect(::JSON.parse(json)).to eq("yolo" => "brolo")
      end

      ::LogStasher.log_as_json(:yolo => :brolo)
    end

    context "with event" do
      it "calls logger with a logstash event" do
        expect(::LogStasher.logger).to receive(:<<) do |json|
          payload = ::JSON.parse(json)

          expect(payload["@timestamp"]).to_not be_nil
          expect(payload["@version"]).to eq("1")
          expect(payload["yolo"]).to eq("brolo")
        end

        ::LogStasher.log_as_json({:yolo => :brolo}, :as_logstash_event => true)
      end
    end

    context "with metadata" do
      before { ::LogStasher.metadata = { :namespace => :cooldude } }
      after { ::LogStasher.metadata = {} }

      it "calls logger with the metadata" do
        expect(::LogStasher.logger).to receive(:<<) do |json|
          expect(::JSON.parse(json)).to eq("yolo" => "brolo", "metadata" => { "namespace" => "cooldude" })
        end

        ::LogStasher.log_as_json(:yolo => :brolo)
      end

      it "merges metadata for LogStash::Event types" do
        expect(::LogStasher.logger).to receive(:<<) do |json|
          expect(::JSON.parse(json)).to match(a_hash_including("yolo" => "brolo", "metadata" => { "namespace" => "cooldude" }))
        end

        ::LogStasher.log_as_json(::LogStash::Event.new(:yolo => :brolo))
      end

      it "does not merge metadata on an array" do
        expect(::LogStasher.logger).to receive(:<<) do |json|
          expect(::JSON.parse(json)).to eq([{ "yolo" => "brolo" }])
        end

        ::LogStasher.log_as_json([{:yolo => :brolo}])
      end
    end
  end

  describe "#load_from_config" do
    before(:each) do
      ::LogStasher.metadata = {}
      ::LogStasher.serialize_parameters = true
      ::LogStasher.silence_standard_logging = false
    end

    it "loads with multiple config keys" do
      config = {
        metadata: {
          namespace: 'kirby',
          logged_via: 'logstasher',
        },
        device: {
          type: 'stdout'
        }
      }

      ::LogStasher.load_from_config(config)
      expect(::LogStasher.metadata).to eq({:namespace => 'kirby', :logged_via => 'logstasher'})
      expect(::LogStasher.default_device).to eq(STDOUT)
    end

    it "loads metadata" do
      config = {
        metadata: {
          namespace: 'kirby',
          logged_via: 'logstasher',
        }
      }

      ::LogStasher.load_from_config(config)
      expect(::LogStasher.metadata).to eq({:namespace => 'kirby', :logged_via => 'logstasher'})
    end

    it "loads parameters" do
      config = {
        include_parameters: false,
        serialize_parameters: false,
        silence_standard_logging: true,
        silence_creation_message: false
      }

      ::LogStasher.load_from_config(config)
      expect(::LogStasher.instance_variable_get(:@include_parameters)).to be false
      expect(::LogStasher.instance_variable_get(:@serialize_parameters)).to be false
      expect(::LogStasher.instance_variable_get(:@silence_standard_logging)).to be true
    end

    it "loads with a stdout device" do
      config = {
        metadata: {
          namespace: 'kirby',
          logged_via: 'logstasher',
        }
      }

      ::LogStasher.load_from_config(config)
      expect(::LogStasher.metadata).to eq({:namespace => 'kirby', :logged_via => 'logstasher'})
    end

    it "loads with a syslog device" do
      config = {
        device:
          {
            type: 'syslog',
            identity: 'logstasher',
            facility: 'LOG_LOCAL1',
            priority: 'LOG_INFO',
            flags: ['LOG_PID', 'LOG_CONS']
          }
      }
      ::LogStasher.load_from_config(config)
      expect(::LogStasher.metadata).to eq({})
      expect(::LogStasher.default_device).to be_a ::LogStasher::Device::Syslog
    end
  end

end
