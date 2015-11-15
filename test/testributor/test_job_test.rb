require 'test_helper'

class TestJobTest < MiniTest::Test
  describe "TestJobTest" do
    let(:worker) do
      Testributor::Worker.new('app_id', 'app_secret')
    end

    subject do
      Testributor::TestJob.new(
        { "test_job" => { "commit_sha" => "12345" },
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

    describe "initialize" do
      it "assigns instance variables" do
        Testributor::Worker.stub_any_instance(:create_project_repo, nil) do
          subject.commit_sha.must_equal '12345'
          subject.command.must_equal 'test/models/user_test.rb'
          subject.repo.is_a?(Rugged::Repository).must_equal true
        end
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
