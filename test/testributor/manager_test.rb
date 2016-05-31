require 'test_helper'

class ManagerTest < MiniTest::Test
  describe "#workload_in_queue" do
    subject { Testributor::Manager.new }
    before do
      subject.stubs(:log) # Skip output

      subject.send(:redis).lpush(
        Testributor::REDIS_JOBS_LIST,
        { cost_prediction: 23, command: 'run something' }.to_json)
      subject.send(:redis).lpush(
        Testributor::REDIS_JOBS_LIST,
        { cost_prediction: 12, command: 'run something else' }.to_json)
    end

    it "returns the total workload in queue" do
      subject.send(:workload_in_queue).must_equal 35
    end
  end

  describe "#low_workload?" do
    subject { Testributor::Manager.new }

    it "returns true when total workload (in queue and on worker) is below 10" do
      subject.stubs(:workload_in_queue).returns(2)
      Testributor.stubs(:workload_on_worker).returns(2)
      subject.send(:low_workload?).must_equal true
    end

    it "returns false when total workload (in queue and on worker) is above 10" do
      subject.stubs(:workload_in_queue).returns(2)
      Testributor.stubs(:workload_on_worker).returns(10)
      subject.send(:low_workload?).must_equal false
    end

    it "returns false when workload_in_queue is nil" do
      subject.stubs(:workload_in_queue).returns(nil)
      Testributor.stubs(:workload_on_worker).returns(10)
      subject.send(:low_workload?).must_equal false
    end

    it "returns false when Testributor.workload_on_worker is nil" do
      subject.stubs(:workload_in_queue).returns(20)
      Testributor.stubs(:workload_on_worker).returns(nil)
      subject.send(:low_workload?).must_equal false
    end
  end

  describe "#loop_iteration" do
    subject { Testributor::Manager.new }

    describe "when workload is low" do
      before { subject.stubs(:low_workload?).returns(true) }

      describe "and the response is empty" do
        before do
          client_mock = mock
          client_mock.stubs(:fetch_jobs).returns([])
          subject.stubs(:client).returns(client_mock)
        end
        it "sleeps NO_JOBS_ON_TESTRIBUTOR_TIMEOUT_SECONDS" do
          subject.expects(:sleep).
            with(Testributor::Manager::NO_JOBS_ON_TESTRIBUTOR_TIMEOUT_SECONDS).
            once.returns(true)
          subject.loop_iteration
        end
      end

      describe "and the response has jobs" do
        before do
          client_mock = mock
          client_mock.stubs(:fetch_jobs).returns([{ some_key: :some_value }])
          subject.stubs(:client).returns(client_mock)
        end
        it "adds the jobs to the Redis queue" do
          # Don't sleep on tests
          subject.stubs(:sleep).returns(true)
          subject.loop_iteration
          job = JSON.parse(subject.send(:redis).
                           lrange(Testributor::REDIS_JOBS_LIST, 0, -1).first)
          job.keys.must_equal(["some_key","queued_at_seconds_since_epoch"])
        end
      end

      describe "and the response has a setup job" do
        before do
          client_mock = mock
          client_mock.stubs(:fetch_jobs).
            returns({ "test_run" => { "id" => "123" }})
          subject.stubs(:client).returns(client_mock)
        end
        it "adds the setup job to the Redis queue" do
          # Don't sleep on tests
          subject.stubs(:sleep).returns(true)
          subject.loop_iteration
          job = JSON.parse(subject.send(:redis).
                           lrange(Testributor::REDIS_JOBS_LIST, 0, -1).first)
          job.keys.must_equal(["test_run"])
        end
      end
    end

    describe "when the workload is not low" do
      before { subject.stubs(:low_workload?).returns(false) }

      it "sleeps LIST_CHECK_TIMEOUT_SECONDS" do
        subject.expects(:sleep).
          with(Testributor::Manager::LIST_CHECK_TIMEOUT_SECONDS).
          once.returns(true)
        subject.loop_iteration
      end
    end
  end
end
