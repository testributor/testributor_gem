require 'test_helper'

class TestJobTest < MiniTest::Test
  describe "TestJobTest" do
    subject do
      Testributor::TestJob.new(
        { "test_run" => { "commit_sha" => "12345", "id" => "987" },
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
        subject.test_run_data.must_equal({ "commit_sha" => "12345", "id" => "987" })
        subject.command.must_equal 'test/models/user_test.rb'
        subject.id.must_equal 2
        subject.queued_at_seconds_since_epoch.must_equal 3
        subject.sent_at_seconds_since_epoch.must_equal 4
        subject.started_at_seconds_since_epoch.must_equal 1
      end
    end

    describe "#run" do
      let(:project_mock) { mock }

      before do
        Testributor.expects(:command).with(){ |arg| arg.match("test/models/user_test.rb") }.once.
          returns({})
        project_mock.stubs(:prepare_for_test_run).returns(true)
        Testributor.stubs(:current_project).returns(project_mock)
      end

      it "calls setup methods when commit is changed" do
        project_mock.expects(:prepare_for_test_run).once.returns(true)

        subject.run
      end

      it "sets Testributor.last_test_run_id" do
        Testributor.last_test_run_id.must_equal nil
        subject.run
        Testributor.last_test_run_id.must_equal 987
      end
    end
  end
end
