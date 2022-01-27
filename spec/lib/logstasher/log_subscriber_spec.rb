require 'spec_helper'
require 'securerandom'

require 'logstasher/log_subscriber'

class MockController
  def user_id
    @user_id ||= SecureRandom.hex(16)
  end
end

class MockRequest
  attr_accessor :env

  def initialize
    @env = { 'action_dispatch.request_id' => 1 }
  end

  def remote_ip
    '127.0.0.1'
  end
end

describe LogStasher::LogSubscriber do
  subject { described_class.new }

  let(:logger) { ::Logger.new('/dev/null') }

  let(:mock_controller) { MockController.new }
  let(:mock_request) { MockRequest.new }
  let(:context) {{ :controller => mock_controller, :request => mock_request }}

  around do |example|
    backup_logger = LogStasher.logger
    LogStasher.logger = logger
    LogStasher.append_fields { }
    Thread.current[:logstasher_context] = context
    Timecop.freeze { example.run }
    Thread.current[:logstasher_context] = nil
    LogStasher.logger = backup_logger
  end

  describe '#process_action' do
    let(:timestamp) { ::Time.new.utc.iso8601(3) }
    let(:duration) { 12.4 }
    let(:json_params) { JSON.dump(payload[:params]) }
    let(:payload) {{
      :controller => 'users',
      :action     => 'show',
      :params     => { 'foo' => 'bar' },
      :format     => 'text/plain',
      :method     => 'method',
      :path       => '/users/1',
      :status     => 200
    }}
    let(:data) { { "namespace" => "test", "appversion" => "v1" } }

    let(:event) { double(:payload => payload, :duration => duration) }

    before { ::LogStasher.metadata = data }
    after { ::LogStasher.metadata = {} }

    it 'logs the event in logstash format' do
      expect(logger).to receive(:<<) do |json|
        expect(JSON.parse(json)).to eq({
          '@timestamp' => timestamp,
          '@version'   => '1',
          'tags'       => ['request'],
          'action'     => payload[:action],
          'controller' => payload[:controller],
          'format'     => payload[:format],
          'params'     => json_params,
          'ip'         => mock_request.remote_ip,
          'method'     => payload[:method],
          'path'       => payload[:path],
          'route'      => "#{payload[:controller]}##{payload[:action]}",
          'status'     => payload[:status],
          'runtime'    => { 'total' => duration },
          'request_id' => 1,
          'metadata'   => data
        })
      end

      subject.process_action(event)
    end

    it 'appends fields to the log' do
      ::LogStasher.append_fields do |fields|
        fields['user_id'] = user_id
        fields['other']   = 'stuff'
      end

      expect(logger).to receive(:<<) do |json|
        fields = JSON.parse(json)
        expect(fields['user_id']).to eq mock_controller.user_id
        expect(fields['other']).to eq 'stuff'
      end

      subject.process_action(event)
    end

    it 'can be configured to remove parameters from the log' do
      allow(::LogStasher).to receive(:include_parameters?).and_return(false)

      expect(logger).to receive(:<<) do |json|
        expect(JSON.parse(json)['params']).to be_nil
      end

      subject.process_action(event)
    end

    it 'can be configured to skip parameter serialization' do
      expect(::LogStasher).to receive(:serialize_parameters?).and_return(false)

      expect(logger).to receive(:<<) do |json|
        expect(JSON.parse(json)['params']).to eq payload[:params]
      end

      subject.process_action(event)
    end

    it 'includes redirect location in the log' do
      redirect_event = double(:payload => {:location => 'new/location'})
      subject.redirect_to(redirect_event)

      expect(logger).to receive(:<<) do |json|
        expect(JSON.parse(json)['location']).to eq 'new/location'
      end

      subject.process_action(event)
    end

    it 'includes runtimes in the log' do
      payload.merge!({
        :view_runtime => 3.3,
        :db_runtime =>  2.1
      })

      expect(logger).to receive(:<<) do |json|
        runtime = JSON.parse(json)['runtime']
        expect(runtime['view']).to eq 3.3
        expect(runtime['db']).to eq 2.1
      end

      subject.process_action(event)
    end

    it 'includes exception info in the log' do
      begin
        fail RuntimeError, 'it no work'
      rescue
        # Test inside the rescue block so $! is properly set
        payload.merge!({
          :exception => ['RuntimeError', 'it no work']
        })

        expect(logger).to receive(:<<) do |json|
          log = JSON.parse(json)
          expect(log['error']).to match /^RuntimeError\nit no work\n.+/m
          expect(log['status']).to eq 500
          expect(log['tags']).to include('exception')
        end

        subject.process_action(event)
      end
    end
  end

  describe '#redirect_to' do
    let(:location) { "users/#{SecureRandom.hex(16)}" }
    let(:payload) {{ :location => location }}
    let(:event) { double(:payload => payload) }

    it 'copies the location into the thread local logstasher context' do
      subject.redirect_to(event)
      expect(Thread.current[:logstasher_context][:location]).to eq location
    end
  end
end
