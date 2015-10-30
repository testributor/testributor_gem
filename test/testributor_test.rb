require 'test_helper'

class TestributorTest < MiniTest::Test
  describe ".initialize" do
    subject do
      Testributor::Worker.stub_any_instance(:create_project_repo, true) do
        Testributor::Worker.new('app_id', 'app_secret')
      end
    end

    let(:client_mock) { MiniTest::Mock.new }

    before do
      client_mock.expect(:get_current_project, {
        "repository_owner" => "testributor_rich_client",
        "repository_name" => "stupid_startup",
        "github_access_token" => "12345" })
      Testributor::Client.stubs(:new).returns(client_mock)
    end

    it "assigns instance variables for current project" do
      subject.repo_owner.must_equal 'testributor_rich_client'
      subject.repo_name.must_equal 'stupid_startup'
      subject.github_access_token.must_equal '12345'
      subject.repo.is_a?(Rugged::Repository).must_equal true
    end
  end
end
