# This is a wrapper class around the test_job response from testributor
module Testributor
  class TestJob
    attr_reader :id, :test_run_data, :command, :sent_at_seconds_since_epoch,
      :queued_at_seconds_since_epoch, :started_at_seconds_since_epoch

    def initialize(job_response)
      @id = job_response["id"]
      @test_run_data = job_response["test_run"]
      @command = job_response["command"]
      @sent_at_seconds_since_epoch = job_response["sent_at_seconds_since_epoch"]
      @queued_at_seconds_since_epoch = job_response["queued_at_seconds_since_epoch"]
      @started_at_seconds_since_epoch = job_response["started_at_seconds_since_epoch"]
    end

    def run
      Testributor.current_project.prepare_for_test_run(test_run_data)
      Testributor.last_test_run_id = test_run_data["id"].to_i

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
