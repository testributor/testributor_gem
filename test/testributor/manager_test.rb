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
end
