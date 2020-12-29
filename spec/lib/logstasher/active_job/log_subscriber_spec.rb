# frozen_string_literal: true

require 'spec_helper'
require 'logstasher/active_job/log_subscriber'
require 'active_job'

if LogStasher.has_active_job?
  describe LogStasher::ActiveJob::LogSubscriber do
    include ActiveJob::TestHelper

    class ActiveJobTestClass < ActiveJob::Base
      include ActiveJob::TestHelper

      def perform(*args)
        1 / 0 if args.size == 1
      end
    end

    before(:each) do
      clear_enqueued_jobs
      clear_performed_jobs
      log_output.truncate(0)
    end

    before(:all) do
      LogStasher::ActiveJob::LogSubscriber.attach_to(:active_job)
      LogStasher.field_renaming = {}
    end

    let(:log_output) { StringIO.new }
    let(:logger) do
      logger = Logger.new(log_output)
      logger.formatter = ->(_, _, _, msg) { msg }
      def log_output.json
        string.split("\n").map { |l| JSON.parse!(l) }
      end
      logger
    end

    before do
      LogStasher.logger = logger
      LogStasher.request_context[:request_id] = 'foobar123'

      # Silence the default logger from spitting out to the console
      allow_any_instance_of(LogStasher::ActiveJob::BASE_SUBSCRIBER).to receive(:logger)
        .and_return(double.as_null_object)
    end

    describe '#logger' do
      it 'returns an instance of Logstash::Logger' do
        expect(described_class.new.logger).to eq logger
      end
    end

    def enqueue_job
      job = nil
      perform_enqueued_jobs do
        job = ActiveJobTestClass.perform_later(1, 2, 3, { 'a' => { 'b' => ['c'] } })
      end
      job
    end

    def enqueue_job_with_error
      if ActiveJob.gem_version.to_s < '6.1'
        enqueue_job_with_error_pre_6_1
      else
        enqueue_job_with_error_6_1
      end
    end

    def enqueue_job_with_error_pre_6_1
      job = nil
      expect do
        perform_enqueued_jobs { job = ActiveJobTestClass.perform_later({error: true}) }
      end.to raise_error(ZeroDivisionError)
    end

    def enqueue_job_with_error_6_1
      job = ActiveJobTestClass.perform_later({error: true})
      expect do
        perform_enqueued_jobs
      end.to raise_error(ZeroDivisionError)
    end

    def log_line(type)
      log_output.json.detect { |j| j['tags'].include?(type) }
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
      expect(log_output.json.size).to eq(0)
      enqueue_job
      expect(log_output.json.size).to eq(3)
    end

    it 'logs a line for performing' do
      job = enqueue_job
      log_line('perform').tap do |json|
        expect(json['tags']).to eq(%w[job perform])
        expect(json['job_id']).to eq(job.job_id)
        expect(json['queue_name']).to eq('Test(default)')
        expect(json['job_class']).to eq('ActiveJobTestClass')
        expect(json['job_args']).to eq(::ActiveJob::Arguments.serialize(job.arguments))
        expect(json['duration']).to be_between(0, 1)
        expect(json).to_not have_key('scheduled_at')
        expect(json).to_not have_key('exception')
      end
    end

    it 'logs the exception when performing' do
      enqueue_job_with_error

      log_line('perform').tap do |json|
        expect(json['tags']).to eq(%w[job perform exception])
        expect(json['job_id']).to be_a(String) # Don't have good access to the real id in this test
        expect(json['job_id']).to_not eq('foobar123')
        expect(json['queue_name']).to eq('Test(default)')
        expect(json['job_class']).to eq('ActiveJobTestClass')
        expect(json['job_args']).to eq(::ActiveJob::Arguments.serialize([{error: true}]))
        #expect(json['job_args']).to eq([{"_aj_ruby2_keywords"=>[], "error"=>true}])
        expect(json['duration']).to be_between(0, 2)
        expect(json['exception']).to eq(['ZeroDivisionError', 'divided by 0'])
        expect(json).to_not have_key('scheduled_at')
      end
    end

    it 'logs a line for perform start' do
      job = enqueue_job
      log_line('perform_start').tap do |json|
        expect(json['tags']).to eq(%w[job perform_start])
        expect(json['job_id']).to eq(job.job_id)
        expect(json['queue_name']).to eq('Test(default)')
        expect(json['job_class']).to eq('ActiveJobTestClass')
        expect(json['job_args']).to eq(::ActiveJob::Arguments.serialize(job.arguments))
        expect(json).to_not have_key('duration')
        expect(json).to_not have_key('scheduled_at')
        expect(json).to_not have_key('exception')
      end
    end

    it 'logs a line for enqueuing' do
      job = enqueue_job
      log_line('enqueue').tap do |json|
        expect(json['tags']).to eq(%w[job enqueue])
        expect(json['job_id']).to eq(job.job_id)
        expect(json['queue_name']).to eq('Test(default)')
        expect(json['job_class']).to eq('ActiveJobTestClass')
        expect(json['job_args']).to eq(::ActiveJob::Arguments.serialize(job.arguments))
        expect(json).to_not have_key('duration')
        expect(json).to_not have_key('scheduled_at')
        expect(json).to_not have_key('exception')
      end
    end
  end
end
