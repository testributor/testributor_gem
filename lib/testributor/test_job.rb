# This is a wrapper class around the test_job response from testributor
module Testributor
  class TestJob
    attr_reader :id, :commit_sha, :command, :repo, :api_client, :worker

    def initialize(job_response, worker)
      @id = job_response["id"]
      @commit_sha = job_response["test_run"]["commit_sha"]
      @command = job_response["command"]
      @worker = worker
      @repo = worker.repo
      @api_client = worker.api_client
    end

    def run
      if commit_changed?
        checkout_to_job_commit
        worker.setup_test_environment
      end

      log "Running #{command}"
      Dir.chdir(Testributor::Worker::PROJECT_DIR) do
        result = Testributor.command(command)
        report_results(
          # The results are either strcutured as JSON or raw. When raw, we
          # assign the output to the result key
          begin
            JSON.parse(result[:output]).merge(status: result[:result_type])
          rescue
            { result: result[:output], status: result[:result_type] }
          end
        )
      end
    end

    # Use only the first 6 characters from each SHA1 to compare
    def commit_changed?
      current_commit_sha[0..5] != commit_sha[0..5]
    end

    private

    def current_commit_sha
      Dir.chdir(Testributor::Worker::PROJECT_DIR) do
        Testributor.command("git rev-parse HEAD", false)[:output].strip
      end
    end

    # TODO: Handle the following case gracefully:
    # Testributor::Worker#run has already fetched the repo if the commit is not known.
    # Still, there might be a case that the commit cannot be found even after
    # pulling the repo. E.g. The history was rewritten somehow (do the commits
    # get lost then?) or the repo has been reset (deleted and repushed). This is
    # an edge case but our worker should probably inform katana about this (so
    # katana can notify the users).
    # TODO: Might not let us checkout if there are changes pending (like the
    # lines we inject in various files). Maybe we need to reset --hard to master
    # first or something.
    def checkout_to_job_commit
      log "Checking out #{commit_sha}"
      repo.checkout(commit_sha)
    end

    def report_results(results)
      log "Reporting to testributor"
      params = { test_job: results }
      api_client.update_test_job(id, params)
    end

    def log(message)
      Testributor.log(message)
    end
  end
end
