require 'spec_helper'
require 'logstasher/active_record/log_subscriber'

describe LogStasher::ActiveRecord::LogSubscriber do
  let(:log_output) {StringIO.new}
  let(:logger) {
    logger = Logger.new(log_output)
    logger.formatter = ->(_, _, _, msg) {
      msg
    }
    def log_output.json
      JSON.parse! self.string
    end
    logger
  }
  before do
    LogStasher.logger = logger
    LogStasher.log_controller_parameters = true
    LogStasher::CustomFields.custom_fields = []
    allow(described_class).to receive(:runtime).and_return(0)
    allow(described_class).to receive(:runtime=)
  end
  after do
    LogStasher.log_controller_parameters = false
  end

  let(:event) {
    ActiveSupport::Notifications::Event.new(
      'identity.active_record', Time.now, Time.now, 1, { sql: 'SELECT * FROM nothing;' }
    )
  }

  describe '.process_action' do
    let(:logger)  { double }
    let(:json)    { '{"sql":"SELECT * FROM nothing;","duration":0.0,"request_id":"1","source":"unknown","tags":["request"],"@timestamp":"1970-01-01T00:00:00.000Z","@version":"1"}'+"\n" }
    before do
      LogStasher.store.clear
      allow(LogStasher).to receive(:request_context).and_return({request_id: "1"})
      allow(LogStasher).to receive(:logger).and_return(logger)
      allow(Time).to receive(:now).and_return(Time.at(0))
    end
    it 'calls all extractors and outputs the json' do
      expect(LogStasher.logger).to receive(:<<).with(json)
      subject.identity(event)
    end
  end

  describe 'logstasher output' do
    it "should contain request tag" do
      subject.identity(event)
      expect(log_output.json['tags']).to eq [ "request" ]
    end

    it "should contain identifier" do
      subject.identity(event)
      expect(log_output.json['sql']).to eq 'SELECT * FROM nothing;'
    end

    it "should include duration time" do
      subject.identity(event)
      expect(log_output.json['duration']).to eq 0.00
    end

    it "should not contain :connection" do
      event.payload[:connection] = Object.new

      subject.identity(event)
      expect(event.payload[:connection]).not_to be_nil
      expect(log_output.json['connection']).to be_nil
    end

  end

  describe "with append_custom_params block specified" do
    let(:request) { double(:remote_ip => '10.0.0.1', :env => {})}
    it "should add default custom data to the output" do
      allow(request).to receive_messages(:params => { controller: "home", action: "index" })
      LogStasher.add_default_fields_to_payload(event.payload.merge!(params: { foo: "bar" }), request)
      subject.identity(event)
      expect(log_output.json['ip']).to eq '10.0.0.1'
      expect(log_output.json['route']).to eq'home#index'
      expect(log_output.json['parameters']).to eq 'foo' => 'bar'
    end
  end

  describe "with append_custom_params block specified" do
    before do
      allow(LogStasher).to receive(:add_custom_fields) do |&block|
        @block = block
      end
      LogStasher.add_custom_fields do |payload|
        payload[:user] = 'user'
      end
      LogStasher::CustomFields.custom_fields += [:user]
    end

    it "should add the custom data to the output" do
      @block.call(event.payload)
      subject.identity(event)
      expect(log_output.json['user']).to eq 'user'
    end
  end

  describe "db_runtime incrementing" do
    let(:event) do
      start = Time.now
      finish = Time.now + 1
      ActiveSupport::Notifications::Event.new(
        'identity.active_record', start, finish, 1, { sql: '' }
      )
    end

    it "should increment runtime by event duration" do
      expect(described_class).to receive(:runtime=).with(be_within(0.01).of(1000.0))
      subject.identity(event)
    end
  end
end
