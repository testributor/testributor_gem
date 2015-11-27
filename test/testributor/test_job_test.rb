require 'test_helper'

class TestJobTest < MiniTest::Test
  describe "TestJobTest" do
    let(:worker) do
      Testributor::Worker.new('app_id', 'app_secret')
    end

    subject do
      Testributor::TestJob.new(
        { "test_run" => { "commit_sha" => "12345" },
          "command" => "test/models/user_test.rb" }, worker)
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

    describe "#run" do
      it "calls setup methods when commit is changed" do
        # TODO: Rewrite this test after refactoring the method #run
        # Currently we have to stub a thousand methods to test a stupid thing.
      end
    end
  end
end
