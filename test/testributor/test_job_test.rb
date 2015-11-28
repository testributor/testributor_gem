require 'test_helper'

class TestJobTest < MiniTest::Test
  describe "TestJobTest" do
    subject do
      Testributor::TestJob.new(
        { "test_run" => { "commit_sha" => "12345" },
          "command" => "test/models/user_test.rb",
          "id" => 2,
          "sent_at_seconds_since_epoch" => 4,
          "queued_at_seconds_since_epoch" => 3,
          "started_at_seconds_since_epoch" => 1 })
    end

    before do
      client_mock = mock
      client_mock.stubs(:get_current_project).returns({
        "repository_owner" => "",
        "repository_name" => "",
        "github_access_token" => "",
        "build_commands" => "",
        "files" => ""
      })
      Testributor::Client.stubs(:new).returns(client_mock)
    end

    describe "initialize" do
      it "assigns instance variables" do
        subject.commit_sha.must_equal '12345'
        subject.command.must_equal 'test/models/user_test.rb'
        subject.id.must_equal 2
        subject.queued_at_seconds_since_epoch.must_equal 3
        subject.sent_at_seconds_since_epoch.must_equal 4
        subject.started_at_seconds_since_epoch.must_equal 1
      end
    end

    describe "#run" do
      it "calls setup methods when commit is changed" do
        # TODO: Rewrite this test after refactoring the method #run
        # Currently we have to stub a thousand methods to test a stupid thing.
      end
    end
  end
end
