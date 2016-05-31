require 'test_helper'

class SetupJobTest < MiniTest::Test
  describe "SetupJobTest" do
    subject do
      Testributor::SetupJob.new(
        { "test_run" => { "id" => "123", "commit_sha" => "12345" },
          "testributor_yml" => _testributor_yml })
    end

    describe "#run" do
      before do
        subject.stubs(:commit_metadata).returns({})
        # Normally this should not be needed but if testributor.yml
        # exists on the filesystem it will override the one specified above.
        subject.stubs(:testributor_yml).returns(_testributor_yml)

        project_mock = mock
        project_mock.stubs(:checkout_commit).returns(true)
        Testributor.stubs(:current_project).returns(project_mock)
      end

      describe "when the testributor_yml is valid" do
        let(:_testributor_yml) do
          <<-YML
          each:
            pattern: '_test.rb'
            command: 'bin/rake test %{file}'
          YML
        end

        it "returns one Hash per job" do
          subject.stubs(:matching_files).returns([
            "test/models/user_test.rb",
            "test/features/user_feature_test.rb",
            "test/controllers/user_controller_test.rb",
          ])

          subject.run.must_equal({ jobs: [
            { job_name: "test/models/user_test.rb",
              command: "bin/rake test test/models/user_test.rb",
              before: "",
              after: ""
            },
            { job_name: "test/features/user_feature_test.rb",
              command: "bin/rake test test/features/user_feature_test.rb",
              before: "",
              after: ""
            },
            { job_name: "test/controllers/user_controller_test.rb",
              command: "bin/rake test test/controllers/user_controller_test.rb",
              before: "",
              after: ""
            }
          ]})
        end

        describe "but the pattern is not a valid regex" do
          let(:_testributor_yml) do
            <<-YML
            each:
              pattern: '[]'
              command: 'bin/rake test %{file}'
            YML
          end

          it "returns an error" do
            subject.run.must_equal({ error: "Matching pattern is not a valid regular expression" })
          end
        end

        describe "but the pattern matches over MATCHING_FILES_SANITY_LIMIT files" do
          before do
            too_many_files_result = {
              exit_code: 0,
              output:
                (Testributor::SetupJob::MATCHING_FILES_SANITY_LIMIT + 1).times.map do |i|
                  "test/models/model_#{i}_test.rb"
                end.join("\n")
            }

            Testributor.expects(:command).with(){|arg| arg.match(/find \. \|/)}.
              at_least_once.returns(too_many_files_result)
          end

          it "returns an error" do
            subject.run.must_equal({ error: "Your pattern matches over 1000 files. Aborting." })
          end
        end
      end

      describe "when the testributor_yml is not valid" do
        let(:_testributor_yml) do
          <<-YML
            each: each: each:
          YML
        end

        it "returns a Hash with the error" do
          subject.run.must_equal({
            error: "(<unknown>): mapping values are not allowed in this context at line 1 column 23"
          })
        end
      end
    end
  end
end
