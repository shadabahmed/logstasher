require 'spec_helper'
require 'securerandom'

class MockController
  def user_id
    @user_id ||= SecureRandom.hex(16)
  end
end

class MockRequest
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
    Thread.current[:logstasher_context] = context
    Timecop.freeze { example.run }
    Thread.current[:logstasher_context] = nil
    LogStasher.logger = backup_logger
  end

  describe '#process_action' do
    let(:timestamp) { ::Time.new.utc.iso8601(3) }
    let(:controller) { 'users' }
    let(:action) { 'show' }
    let(:params) {{ 'foo' => 'bar' }}
    let(:format) { 'text/plain' }
    let(:method) { 'method' }
    let(:path) { '/users/1' }
    let(:duration) { 12.4 }
    let(:status) { 200 }
    let(:payload) {{
      :controller => controller,
      :action     => action,
      :params     => params,
      :format     => format,
      :method     => method,
      :path       => path,
      :status     => status
    }}

    let(:event) { double(:payload => payload, :duration => duration) }

    it 'logs the event in logstash format' do
      ::LogStash::Time.stub(:now => timestamp)

      logger.should_receive(:<<) do |json|
        JSON.parse(json).should eq({
          '@source'    => 'unknown',
          '@timestamp' => timestamp,
          '@tags'      => ['request'],
          '@fields'    => {
            'action'     => action,
            'controller' => controller,
            'format'     => format,
            'ip'         => mock_request.remote_ip,
            'method'     => method,
            'path'       => path,
            'route'      => "#{controller}##{action}",
            'status'     => status,
            'duration'   => duration
          },
        })
      end

      subject.process_action(event)
    end

    it 'includes custom fields in the log' do
      ::LogStasher.add_custom_fields do |fields|
        fields['user_id'] = user_id
        fields['other']   = 'stuff'
      end

      logger.should_receive(:<<) do |json|
        fields = JSON.parse(json)['@fields']
        fields['user_id'].should eq mock_controller.user_id
        fields['other'].should eq 'stuff'
      end

      subject.process_action(event)
    end

    it 'includes parameters in the log' do
      ::LogStasher.stub(:log_controller_parameters => true)

      logger.should_receive(:<<) do |json|
        JSON.parse(json)['@fields']['parameters'].should eq params
      end

      subject.process_action(event)
    end

    it 'includes redirect location in the log' do
      redirect_event = double(:payload => {:location => 'new/location'})
      subject.redirect_to(redirect_event)

      logger.should_receive(:<<) do |json|
        JSON.parse(json)['@fields']['location'].should eq 'new/location'
      end

      subject.process_action(event)
    end

    it 'includes runtimes in the log' do
      payload.merge!({
        :view_runtime => 3.3,
        :db_runtime =>  2.1
      })

      logger.should_receive(:<<) do |json|
        log = JSON.parse(json)
        log['@fields']['view'].should eq 3.3
        log['@fields']['db'].should eq 2.1
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

        logger.should_receive(:<<) do |json|
          log = JSON.parse(json)
          log['@fields']['error'].should match /^RuntimeError\nit no work\n.+/m
          log['@fields']['status'].should eq 500
          log['@tags'].should include('exception')
        end

        subject.process_action(event)
      end
    end
  end

  describe '#redirect_to' do
    let(:location) { "users/#{SecureRandom.hex(16)}" }
    let(:payload) {{ :location => location }}
    let(:event) { double(:payload => payload) }

    it 'copies the location from the event' do
      subject.redirect_to(event)
      Thread.current[:logstasher_location].should eq location
    end
  end
end
