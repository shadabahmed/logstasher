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
    LogStasher.custom_fields = []
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
    let(:json)    { "{\"@source\":\"unknown\",\"@tags\":[\"request\"],\"@fields\":{\"request\":true,\"status\":true,\"runtimes\":true,\"location\":true,\"exception\":true,\"custom\":true},\"@timestamp\":\"timestamp\"}\n" }
    before do
      LogStasher.stub(:logger => logger)
      LogStash::Time.stub(:now => 'timestamp')
    end
    it 'calls all extractors and outputs the json' do
      request_subscriber.should_receive(:extract_request).with(payload).and_return({:request => true})
      request_subscriber.should_receive(:extract_status).with(payload).and_return({:status => true})
      request_subscriber.should_receive(:runtimes).with(event).and_return({:runtimes => true})
      request_subscriber.should_receive(:location).with(event).and_return({:location => true})
      request_subscriber.should_receive(:extract_exception).with(payload).and_return({:exception => true})
      request_subscriber.should_receive(:extract_custom_fields).with(payload).and_return({:custom => true})
      LogStasher.logger.should_receive(:<<).with(json)
      request_subscriber.process_action(event)
    end
  end

  describe 'logstasher output' do

    it "should contain request tag" do
      subscriber.process_action(event)
      log_output.json['@tags'].should include 'request'
    end

    it "should contain HTTP method" do
      subscriber.process_action(event)
      log_output.json['@fields']['method'].should == 'GET'
    end

    it "should include the path in the log output" do
      subscriber.process_action(event)
      log_output.json['@fields']['path'].should == '/home'
    end

    it "should include the format in the log output" do
      subscriber.process_action(event)
      log_output.json['@fields']['format'].should == 'application/json'
    end

    it "should include the status code" do
      subscriber.process_action(event)
      log_output.json['@fields']['status'].should == 200
    end

    it "should include the controller" do
      subscriber.process_action(event)
      log_output.json['@fields']['controller'].should == 'home'
    end

    it "should include the action" do
      subscriber.process_action(event)
      log_output.json['@fields']['action'].should == 'index'
    end

    it "should include the view rendering time" do
      subscriber.process_action(event)
      log_output.json['@fields']['view'].should == 0.01
    end

    it "should include the database rendering time" do
      subscriber.process_action(event)
      log_output.json['@fields']['db'].should == 0.02
    end

    it "should add a valid status when an exception occurred" do
      begin
        raise AbstractController::ActionNotFound.new('Could not find an action')
      # working this in rescue to get access to $! variable
      rescue
        event.payload[:status] = nil
        event.payload[:exception] = ['AbstractController::ActionNotFound', 'Route not found']
        subscriber.process_action(event)
        log_output.json['@fields']['status'].should >= 400
        log_output.json['@fields']['error'].should =~ /AbstractController::ActionNotFound.*Route not found.*logstasher\/spec\/lib\/logstasher\/log_subscriber_spec\.rb/m
        log_output.json['@tags'].should include 'request'
        log_output.json['@tags'].should include 'exception'
      end
    end

    it "should return an unknown status when no status or exception is found" do
      event.payload[:status] = nil
      event.payload[:exception] = nil
      subscriber.process_action(event)
      log_output.json['@fields']['status'].should == 0
    end

    describe "with a redirect" do
      before do
        Thread.current[:logstasher_location] = "http://www.example.com"
      end

      it "should add the location to the log line" do
        subscriber.process_action(event)
        log_output.json['@fields']['location'].should == 'http://www.example.com'
      end

      it "should remove the thread local variable" do
        subscriber.process_action(event)
        Thread.current[:logstasher_location].should == nil
      end
    end

    it "should not include a location by default" do
      subscriber.process_action(event)
      log_output.json['@fields']['location'].should be_nil
    end
  end

  describe "with append_custom_params block specified" do
    let(:request) { double(:remote_ip => '10.0.0.1')}
    it "should add default custom data to the output" do
      request.stub(:params => event.payload[:params])
      LogStasher.add_default_fields_to_payload(event.payload, request)
      subscriber.process_action(event)
      log_output.json['@fields']['ip'].should == '10.0.0.1'
      log_output.json['@fields']['route'].should == 'home#index'
      log_output.json['@fields']['parameters'].should == {'foo' => 'bar'}
    end
  end

  describe "with append_custom_params block specified" do
    before do
      LogStasher.stub(:add_custom_fields) do |&block|
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
      log_output.json['@fields']['user'].should == 'user'
    end
  end

  describe "when processing a redirect" do
    it "should store the location in a thread local variable" do
      subscriber.redirect_to(redirect)
      Thread.current[:logstasher_location].should == "http://example.com"
    end
  end
end
