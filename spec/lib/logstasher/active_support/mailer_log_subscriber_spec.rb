require 'spec_helper'

describe LogStasher::ActiveSupport::MailerLogSubscriber do
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
    LogStasher::ActiveSupport::MailerLogSubscriber.attach_to(:action_mailer)
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
      expect(LogStasher::ActiveSupport::MailerLogSubscriber.new.logger).to eq logger
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
