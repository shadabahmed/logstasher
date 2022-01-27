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

      it "does not merge metadata on an array" do
        expect(::LogStasher.logger).to receive(:<<) do |json|
          expect(::JSON.parse(json)).to eq([{ "yolo" => "brolo" }])
        end

        ::LogStasher.log_as_json([{:yolo => :brolo}])
      end
    end
  end
end
