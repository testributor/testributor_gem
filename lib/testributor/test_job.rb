# This is a wrapper class around the test_job response from testributor
module Testributor
  class TestJob
    attr_reader :id, :commit_sha, :command, :repo, :api_client,
      :sent_at_seconds_since_epoch, :queued_at_seconds_since_epoch,
      :started_at_seconds_since_epoch

    def initialize(job_response)
      @id = job_response["id"]
      @commit_sha = job_response["test_run"]["commit_sha"]
      @command = job_response["command"]
      @sent_at_seconds_since_epoch = job_response["sent_at_seconds_since_epoch"]
      @queued_at_seconds_since_epoch = job_response["queued_at_seconds_since_epoch"]
      @started_at_seconds_since_epoch = job_response["started_at_seconds_since_epoch"]
    end

    def run
      Testributor.current_project.prepare_for_commit(commit_sha)

      Testributor.log "Running #{command}"
      result = Testributor.command(command, return_duration: true)
      final_result =
        begin
          # TODO: Also check that the parsed Hash is in the expected format
          # (and not something random)
          JSON.parse(result[:output])
        rescue
          { result: result[:output] }
        end

      final_result.merge(
        status: result[:result_type],
        sent_at_seconds_since_epoch: sent_at_seconds_since_epoch,
        worker_in_queue_seconds: started_at_seconds_since_epoch - queued_at_seconds_since_epoch,
        worker_command_run_seconds: result[:duration_seconds]
      )
    end
  end
end
