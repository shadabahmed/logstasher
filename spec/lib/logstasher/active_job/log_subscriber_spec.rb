require 'spec_helper'

describe LogStasher::ActiveJob::LogSubscriber do
  require 'active_job'
  class ActiveJobTestClass < ActiveJob::Base
    def perform(*args)
      1/0 if args.size == 1
    end
  end

  before(:all) { LogStasher::ActiveJob::LogSubscriber.attach_to(:active_job) }

  let(:log_output) { StringIO.new }
  let(:logger) do
    logger = Logger.new(log_output)
    logger.formatter = ->(_, _, _, msg) { msg }
    def log_output.json
      self.string.split("\n").map { |l| JSON.parse!(l) }
    end
    logger
  end

  before(:each) do
    LogStasher.logger = logger
    LogStasher.request_context[:request_id] = 'foobar123'

    # Silence the default logger from spitting out to the console
    allow_any_instance_of(ActiveJob::Logging::LogSubscriber).to receive(:logger)
      .and_return(double.as_null_object)
  end

  describe "#logger" do
    it "returns an instance of Logstash::Logger" do
      expect(described_class.new.logger).to eq logger
    end
  end

  def enqueue_job
    ActiveJobTestClass.perform_later(1,2,3, {'a' => {'b' => ['c']}})
  end

  def log_line(type)
    log_output.json.detect{|j| j['tags'].include?(type) }
  end

  it 'uses the correct request id' do
    job = nil
    expect { job = enqueue_job }
      .to_not change { LogStasher.request_context[:request_id] }.from('foobar123')

    expect(log_line('enqueue')['request_id']).to eq('foobar123')
    expect(log_line('perform_start')['request_id']).to eq(job.job_id)
    expect(log_line('perform')['request_id']).to eq(job.job_id)
  end

  it 'logs 3 lines per job' do
    # enqueue, perform_start, perform
    enqueue_job
    expect(log_output.json.size).to eq(3)
  end

  it 'logs a line for performing' do
    job = enqueue_job
    log_line('perform').tap do |json|
      expect(json['tags']).to eq(['job', 'perform'])
      expect(json['job_id']).to eq(job.job_id)
      expect(json['queue_name']).to eq('Inline(default)')
      expect(json['job_class']).to eq('ActiveJobTestClass')
      expect(json['job_args']).to eq([1,2,3, {'a' => {'b' => ['c']}}])
      expect(json['duration']).to be_between(0, 1)
      expect(json).to_not have_key('scheduled_at')
      expect(json).to_not have_key('exception')
    end
  end

  it 'logs the exception when performing' do
    job = nil
    expect { job = ActiveJobTestClass.perform_later('error' => true) }
      .to raise_error(ZeroDivisionError)

    log_line('perform').tap do |json|
      expect(json['tags']).to eq(['job', 'perform', 'exception'])
      expect(json['job_id']).to be_a(String) # Don't have good access to the real id in this test
      expect(json['job_id']).to_not eq('foobar123')
      expect(json['queue_name']).to eq('Inline(default)')
      expect(json['job_class']).to eq('ActiveJobTestClass')
      expect(json['job_args']).to eq([{'error' => true}])
      expect(json['duration']).to be_between(0, 1)
      expect(json['exception']).to eq(['ZeroDivisionError', 'divided by 0'])
      expect(json).to_not have_key('scheduled_at')
    end
  end

  it 'logs a line for perform start' do
    job = enqueue_job
    log_line('perform_start').tap do |json|
      expect(json['tags']).to eq(['job', 'perform_start'])
      expect(json['job_id']).to eq(job.job_id)
      expect(json['queue_name']).to eq('Inline(default)')
      expect(json['job_class']).to eq('ActiveJobTestClass')
      expect(json['job_args']).to eq([1,2,3, {'a' => {'b' => ['c']}}])
      expect(json).to_not have_key('duration')
      expect(json).to_not have_key('scheduled_at')
      expect(json).to_not have_key('exception')
    end
  end

  it 'logs a line for enqueuing' do
    job = enqueue_job
    log_line('enqueue').tap do |json|
      expect(json['tags']).to eq(['job', 'enqueue'])
      expect(json['job_id']).to eq(job.job_id)
      expect(json['queue_name']).to eq('Inline(default)')
      expect(json['job_class']).to eq('ActiveJobTestClass')
      expect(json['job_args']).to eq([1,2,3, {'a' => {'b' => ['c']}}])
      expect(json).to_not have_key('duration')
      expect(json).to_not have_key('scheduled_at')
      expect(json).to_not have_key('exception')
    end
  end
end if LogStasher.has_active_job?
