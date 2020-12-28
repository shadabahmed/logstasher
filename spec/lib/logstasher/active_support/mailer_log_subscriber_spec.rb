require 'spec_helper'

describe LogStasher::ActiveSupport::MailerLogSubscriber do
  let(:log_output) { StringIO.new }
  let(:logger) do
    logger = Logger.new(log_output)
    logger.formatter = lambda { |_, _, _, msg|
      msg
    }
    def log_output.json
      return '' if string.nil?

      JSON.parse!(string.split("\n").last)
    end
    logger
  end

  before :all do
    SampleMailer.delivery_method = :test
    LogStasher.field_renaming = {}
    LogStasher::ActiveSupport::MailerLogSubscriber.attach_to(:action_mailer)
  end

  before :each do
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

  describe '#logger' do
    it 'returns an instance of Logstash::Logger' do
      expect(LogStasher::ActiveSupport::MailerLogSubscriber.new.logger).to eq logger
    end
  end

  # Receive functionality was removed from ActionMailer in 6.1.0
  if ActionMailer.gem_version.to_s < '6.1.0'
    it 'receives an e-mail' do
      SampleMailer.receive(message.encoded)
      log_output.json.tap do |json|
        expect(json['source']).to eq(LogStasher.source)
        expect(json['tags']).to eq(%w[mailer receive])
        expect(json['mailer']).to eq('SampleMailer')
        expect(json['from']).to eq(['some-dude@example.com'])
        expect(json['to']).to eq(['some-other-dude@example.com'])
        expect(json['message_id']).to eq(message.message_id)
      end
    end
  end

  it 'deliver an outgoing e-mail' do
    email = SampleMailer.welcome
    email.respond_to?(:deliver_now) ? email.deliver_now : email.deliver
    log_output.json.tap do |json|
      expect(json['source']).to eq(LogStasher.source)
      expect(json['tags']).to eq(%w[mailer deliver])
      expect(json['mailer']).to eq('SampleMailer')
      expect(json['from']).to eq(['some-dude@example.com'])
      expect(json['to']).to eq(['some-other-dude@example.com'])
      expect(json['message_id']).to eq(email.message_id)
    end
  end
end
