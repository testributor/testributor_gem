require 'test_helper'

class WorkerTest < MiniTest::Test
  describe "#handle_next_job" do
    subject { Testributor::Worker.new }

    describe "when there is a job in the queue" do
      before do
        subject.stubs(:log) # Skip output
      end

      it "sets the worker_current_job_* variables on Testributor when there is a job" do
        subject.send(:redis).lpush(
          Testributor::REDIS_JOBS_LIST,
          { cost_prediction: 23,
            command: 'run something',
            test_run: { id: 23 } }.to_json)
        Testributor::TestJob.any_instance.stubs(:run).returns({})
        Timecop.freeze do
          subject.send(:handle_next_job)
          Testributor.instance_variable_get(:@worker_current_job_started_at).
            must_equal Time.now
          Testributor.instance_variable_get(:@worker_current_job_cost_prediction).
            must_equal 23
        end
      end

      it "sets the worker_current_job_* variables on Testributor to nil when there is no job" do
        # Don't sleep in tests
        Testributor::Worker.stub_const(:NO_JOBS_IN_QUEUE_TIMEOUT_SECONDS, 0) do
          Timecop.freeze do
            subject.send(:handle_next_job)
            Testributor.instance_variable_get(:@worker_current_job_started_at).
              must_equal nil
            Testributor.instance_variable_get(:@worker_current_job_cost_prediction).
              must_equal nil
          end
        end
      end
    end
  end
end
