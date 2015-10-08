# This is a wrapper class around the test_job_file response from testributor
module Testributor
  class TestJobFile
    attr_reader :id, :commit_sha, :file_name, :repo, :api_client, :worker

    def initialize(file_response, worker)
      @id = file_response["id"]
      @commit_sha = file_response["test_job"]["commit_sha"]
      @file_name = file_response["file_name"]
      @worker = worker
      @repo = worker.repo
      @api_client = worker.api_client
    end

    def run
      if commit_changed?
        checkout_to_job_commit
        worker.setup_test_environment
      end

      # Unless already required the reporter on this file
      # inject our own reporter by requiring on the top of the file to run
      unless File.open(file_name, &:gets) =~ /testributor\/reporter/
        log "Injecting our reporter"
        File.write(
          file_name, "require 'testributor/reporter'\n" + File.read(file_name))
      end
      log "Running test file #{file_name}"
      results = JSON.parse(Testributor.command("bin/rake test #{file_name}"))

      report_results(results)
    end

    # Use only the first 6 characters from each SHA1 to compare
    def commit_changed?
      current_commit_sha[0..5] != commit_sha[0..5]
    end

    private

    def current_commit_sha
      Dir.chdir(Testributor::Worker::PROJECT_DIR) do
        Testributor.command("git rev-parse HEAD", false).strip
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
      params = { test_job_file: results }
      api_client.update_test_job_file(id, params)
    end

    def log(message)
      Testributor.log(message)
    end
  end
end
