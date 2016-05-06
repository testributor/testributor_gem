require 'test_helper'

class ProjectTest < MiniTest::Test
  describe "ProjectTest" do
    before do
      # Stub "dangerous" methods
      Testributor::Project.any_instance.stubs(:create_ssh_keys).returns(true)
      Testributor::Project.any_instance.stubs(:check_ssh_key_validity).returns(true)
      Testributor::Project.any_instance.stubs(:create_project_directory).returns(true)
      Testributor::Project.any_instance.stubs(:fetch_project_repo).returns(true)
    end

    subject do
      Testributor::Project.new(
        { "current_project" => {
            "repository_ssh_url" => "git@github.com:ispyropoulos/katana.git",
            "files" => [],
            "docker_image" => {
              "name" => "ruby",
              "version" => "2.3.0"
            },
          },
          "current_worker_group" => {
            "ssh_key_private" => "blah blah",
            "ssh_key_public" => "blah blah",
          }
        }
      )
    end

    describe "#prepare_for_test_run" do
      let(:repo_mock) { mock }
      before do
        Rugged::Repository.stubs(:new).returns(repo_mock)
        repo_mock.stubs(:exists?).returns(true)
      end

      it "calls setup methods when build is changed" do
        Testributor.last_test_run_id = "12345"
        subject.expects(:setup_test_environment).with("the_commit_sha").once.returns(true)

        subject.prepare_for_test_run({"id" => "9876", "commit_sha" => "the_commit_sha"})
      end

      it "does not call setup methods when build is not changed" do
        Testributor.last_test_run_id = "12345"
        subject.expects(:setup_test_environment).with("the_commit_sha").never

        subject.prepare_for_test_run({"id" => "12345", "commit_sha" => "the_commit_sha"})
      end

      it "calls fetch_project_repo when commit_sha is not found" do
        repo_mock.stubs(:exists?).returns(false)
        subject.expects(:fetch_project_repo).once.returns(true)

        subject.prepare_for_test_run({"id" => "12345", "commit_sha" => "the_commit_sha"})
      end

      it "doesn't call fetch_project_repo when commit_sha is found" do
        subject.expects(:fetch_project_repo).never

        subject.prepare_for_test_run({"id" => "12345", "commit_sha" => "the_commit_sha"})
      end
    end
  end
end
