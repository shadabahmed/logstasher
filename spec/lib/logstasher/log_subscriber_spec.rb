require 'spec_helper'

describe LogStasher::RequestLogSubscriber do
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
    LogStasher.custom_fields = []
  end
  after do
    LogStasher.log_controller_parameters = false
  end

  let(:subscriber) {LogStasher::RequestLogSubscriber.new}
  let(:event) {
    ActiveSupport::Notifications::Event.new(
      'process_action.action_controller', Time.now, Time.now, 2, {
        status: 200, format: 'application/json', method: 'GET', path: '/home?foo=bar', params: {
          :controller => 'home', :action => 'index', 'foo' => 'bar'
        }.with_indifferent_access, db_runtime: 0.02, view_runtime: 0.01
      }
    )
  }

  let(:redirect) {
    ActiveSupport::Notifications::Event.new(
      'redirect_to.action_controller', Time.now, Time.now, 1, location: 'http://example.com', status: 302
    )
  }

  describe '.process_action' do
    let!(:request_subscriber) { @request_subscriber ||= LogStasher::RequestLogSubscriber.new() }
    let(:payload) { {} }
    let(:event)   { double(:payload => payload) }
    let(:logger)  { double }
    let(:json)    {
      {
        "source" => "unknown",
        "tags" => ["request"],
        "request" => true,
        "status" => true,
        "runtimes" => true,
        "location" => true,
        "exception" => true,
        "custom" => true,
        "@timestamp" => "timestamp",
        "@version" => "1"
      }.to_json + "\n"
    }
    before do
      allow(LogStasher).to receive(:logger).and_return(logger)
      allow(Time).to receive_message_chain(:now, :utc).and_return('timestamp')
    end
    it 'calls all extractors and outputs the json' do
      expect(request_subscriber).to receive(:extract_request).with(payload).and_return({:request => true})
      expect(request_subscriber).to receive(:extract_status).with(payload).and_return({:status => true})
      expect(request_subscriber).to receive(:runtimes).with(event).and_return({:runtimes => true})
      expect(request_subscriber).to receive(:location).with(event).and_return({:location => true})
      expect(request_subscriber).to receive(:extract_exception).with(payload).and_return({:exception => true})
      expect(request_subscriber).to receive(:extract_custom_fields).with(payload).and_return({:custom => true})
      expect(LogStasher.logger).to receive(:<<).with(json)
      request_subscriber.process_action(event)
    end
  end

  describe 'logstasher output' do

    it "should contain request tag" do
      subscriber.process_action(event)
      expect(log_output.json['tags']).to include 'request'
    end

    it "should contain HTTP method" do
      subscriber.process_action(event)
      expect(log_output.json['method']).to eq 'GET'
    end

    it "should include the path in the log output" do
      subscriber.process_action(event)
      expect(log_output.json['path']).to eq '/home'
    end

    it "should include the format in the log output" do
      subscriber.process_action(event)
      expect(log_output.json['format']).to eq 'application/json'
    end

    it "should include the status code" do
      subscriber.process_action(event)
      expect(log_output.json['status']).to eq 200
    end

    it "should include the controller" do
      subscriber.process_action(event)
      expect(log_output.json['controller']).to eq 'home'
    end

    it "should include the action" do
      subscriber.process_action(event)
      expect(log_output.json['action']).to eq 'index'
    end

    it "should include the view rendering time" do
      subscriber.process_action(event)
      expect(log_output.json['view']).to eq 0.01
    end

    it "should include the database rendering time" do
      subscriber.process_action(event)
      expect(log_output.json['db']).to eq 0.02
    end

    it "should add a valid status when an exception occurred" do
      begin
        raise AbstractController::ActionNotFound.new('Could not find an action')
      # working this in rescue to get access to $! variable
      rescue
        event.payload[:status] = nil
        event.payload[:exception] = ['AbstractController::ActionNotFound', 'Route not found']
        subscriber.process_action(event)
        expect(log_output.json['status']).to be >= 400
        expect(log_output.json['error']).to be =~ /AbstractController::ActionNotFound.*Route not found.*logstasher.*\/spec\/lib\/logstasher\/log_subscriber_spec\.rb/m
        expect(log_output.json['tags']).to include 'request'
        expect(log_output.json['tags']).to include 'exception'
      end
    end

    it "should return an unknown status when no status or exception is found" do
      event.payload[:status] = nil
      event.payload[:exception] = nil
      subscriber.process_action(event)
      expect(log_output.json['status']).to eq 0
    end

    describe "with a redirect" do
      before do
        Thread.current[:logstasher_location] = "http://www.example.com"
      end

      it "should add the location to the log line" do
        subscriber.process_action(event)
        expect(log_output.json['location']).to eq 'http://www.example.com'
      end

      it "should remove the thread local variable" do
        subscriber.process_action(event)
        expect(Thread.current[:logstasher_location]).to be_nil
      end
    end

    it "should not include a location by default" do
      subscriber.process_action(event)
      expect(log_output.json['location']).to be_nil
    end
  end

  describe "with append_custom_params block specified" do
    let(:request) { double(:remote_ip => '10.0.0.1', :env => {})}
    it "should add default custom data to the output" do
      allow(request).to receive_messages(:params => event.payload[:params])
      LogStasher.add_default_fields_to_payload(event.payload, request)
      subscriber.process_action(event)
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
      LogStasher.custom_fields += [:user]
    end

    it "should add the custom data to the output" do
      @block.call(event.payload)
      subscriber.process_action(event)
      expect(log_output.json['user']).to eq 'user'
    end
  end

  describe "when processing a redirect" do
    it "should store the location in a thread local variable" do
      subscriber.redirect_to(redirect)
      expect(Thread.current[:logstasher_location]).to eq "http://example.com"
    end
  end
end

describe LogStasher::MailerLogSubscriber do
  let(:log_output) {StringIO.new}
  let(:logger) {
    logger = Logger.new(log_output)
    logger.formatter = ->(_, _, _, msg) {
      msg
    }
    def log_output.json
      JSON.parse!(self.string.split("\n").last)
    end
    logger
  }

  before :all do
    SampleMailer.delivery_method = :test
    LogStasher::MailerLogSubscriber.attach_to(:action_mailer)
  end

  before do
    LogStasher.logger = logger
    expect(LogStasher.request_context).to receive(:merge).at_most(2).times.and_call_original
  end

  let :message do
    Mail.new do
      from 'some-dude@example.com'
      to 'some-other-dude@example.com'
      subject 'Goodbye'
      body 'LOL'
    end
  end

  describe "#logger" do
    it "returns an instance of Logstash::Logger" do
      expect(LogStasher::MailerLogSubscriber.new.logger).to eq(logger)
    end
  end

  it 'receive an e-mail' do
    SampleMailer.receive(message.encoded)
    log_output.json.tap do |json|
      expect(json['source']).to eq(LogStasher.source)
      expect(json['tags']).to eq(['mailer', 'receive'])
      expect(json['mailer']).to eq('SampleMailer')
      expect(json['from']).to eq(['some-dude@example.com'])
      expect(json['to']).to eq(['some-other-dude@example.com'])
      expect(json['message_id']).to eq(message.message_id)
    end
  end

  it 'deliver an outgoing e-mail' do
    email = SampleMailer.welcome

    if version = ENV['RAILS_VERSION'] and version >= '4.1'
      log_output.json.tap do |json|
        expect(json['source']).to eq(LogStasher.source)
        expect(json['tags']).to eq(['mailer', 'process'])
        expect(json['mailer']).to eq('SampleMailer')
        expect(json['action']).to eq('welcome')
      end
    end

    email.deliver
    log_output.json.tap do |json|
      expect(json['source']).to eq(LogStasher.source)
      expect(json['tags']).to eq(['mailer', 'deliver'])
      expect(json['mailer']).to eq('SampleMailer')
      expect(json['from']).to eq(['some-dude@example.com'])
      expect(json['to']).to eq(['some-other-dude@example.com'])
      # Message-Id appears not to be yet available at this point in time.
      expect(json['message_id']).to be_nil
    end
  end
end
