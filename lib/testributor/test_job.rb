# This is a wrapper class around the test_job response from testributor
module Testributor
  class TestJob
    attr_reader :id, :commit_sha, :command, :repo, :api_client

    def initialize(job_response)
      @id = job_response["id"]
      @commit_sha = job_response["test_run"]["commit_sha"]
      @command = job_response["command"]
    end

    def run
      Testributor.current_project.prepare_for_commit(commit_sha)

      Testributor.log "Running #{command}"
      result = Testributor.command(command)
      begin
        # TODO: Also check that the parsed Hash is in the expected format
        # (and not something random)
        JSON.parse(result[:output]).merge(status: result[:result_type])
      rescue
        { result: result[:output], status: result[:result_type] }
      end
    end
  end
end
