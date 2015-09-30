require 'test_helper'

class TestJobFileTest < MiniTest::Test
  describe ".initialize" do
    subject do
      TestJobFile.new(
        { "test_job" => { "commit_sha" => "12345" },
          "file_name" => "test/models/user_test.rb" },
        Rugged::Repository.new('.'))
    end

    it "assigns instance variables" do
      subject.commit_sha.must_equal '12345'
      subject.file_name.must_equal 'test/models/user_test.rb'
      subject.repo.is_a?(Rugged::Repository).must_equal true
    end
  end

  describe "#run" do
    subject do
      TestJobFile.new(
        { "test_job" => { "commit_sha" => "12345" },
          "file_name" => "test/models/user_test.rb" },
        Rugged::Repository.new('.'))
    end

    it "calls setup methods when commit is changed" do
      subject.stubs(:commit_changed?).returns(true)
      subject.expects(:checkout_to_job_commit).once
      subject.expects(:setup_test_environment).once
      subject.run
    end
  end
end
