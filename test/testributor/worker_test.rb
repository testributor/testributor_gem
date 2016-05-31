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

      describe "and the job is a setup job" do
        before do
          subject.send(:redis).lpush(
            Testributor::REDIS_JOBS_LIST,
            { cost_prediction: 20,
              type: "setup",
              test_run: { id: "123", commit_sha: "1234" },
              testributor_yml: "a: 1"
            }.to_json)
        end

        it "creates a SetupJob and runs it" do
          Testributor::Worker.stub_const(:NO_JOBS_IN_QUEUE_TIMEOUT_SECONDS, 0) do
            Testributor::SetupJob.any_instance.expects(:run).once
            Testributor::TestJob.any_instance.expects(:run).times(0)
            subject.send(:handle_next_job)
          end
        end

        it "pushes the result to the reports queue" do
          Testributor::Worker.stub_const(:NO_JOBS_IN_QUEUE_TIMEOUT_SECONDS, 0) do
            Testributor::SetupJob.any_instance.expects(:run).once.
              returns({ some_key: :some_value })
            subject.send(:handle_next_job)
            subject.send(:redis).hgetall(Testributor::REDIS_REPORTS_HASH).
              must_equal({"setup_job_123"=>"{\"some_key\":\"some_value\"}"})
          end
        end
      end
    end
  end
end
