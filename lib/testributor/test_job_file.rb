# This is a wrapper class around the test_job_file response from testributor
module Testributor
  class TestJobFile
    attr_reader :repo, :commit_sha, :file_name, :build_commands

    def initialize(file_response, repo, build_commands='')
      @commit_sha = file_response["test_job"]["commit_sha"]
      @file_name = file_response["file_name"]
      @repo = repo
      @build_commands = build_commands
    end

    def run
      if commit_changed?
        checkout_to_job_commit
        setup_test_environment
      end

      # Unless already required the reporter on this file
      # inject our own reporter by requiring on the top of the file to run
      unless File.open(file_name, &:gets) =~ /testributor\/reporter/
        log "Injecting our reporter"
        File.write(
          file_name, "require 'testributor/reporter'\n" + File.read(file_name))
      end
      log "Running test file #{file_name}"
      log `bin/rake test #{file_name}`

      report_results
    end

    # Use only the first 6 characters from each SHA1 to compare
    def commit_changed?
      current_commit_sha[0..5] != commit_sha[0..5]
    end

    private

    def current_commit_sha
      Dir.chdir(Testributor::Worker::PROJECT_DIR) do
        `git rev-parse HEAD`.strip
      end
    end

    # TODO: Handle the following case gracefully:
    # Testributor::Worker#run has already fetched the repo if the commit is not known.
    # Still, there might be a case that the commit cannot be found even after
    # pulling the repo. E.g. The history was rewritten somehow (do the commits
    # get lost then?) or the repo has been reset (deleted and repushed). This is
    # an edge case but our worker should probably inform katana about this (so
    # katana can notify the users).
    def checkout_to_job_commit
      log "Checking out #{commit_sha}"
      repo.checkout(commit_sha)
    end

    # Create test database, install needed gems and run any custom build scripts
    def setup_test_environment
      log "Setting up environment"
      Dir.chdir(Testributor::Worker::PROJECT_DIR) do
        # Inject our gem in the Gemfile
        # What if there is not Gemfile? (could it be?)
        `echo 'gem "testributor", group: :test' >> Gemfile`

        # Run custom build commands
        log `#{build_commands}` if build_commands && build_commands != ''
      end
    end

    def report_results
      log "Reporting to testributor"
      # TODO
    end

    def log(message)
      Testributor.log(message)
    end
  end
end
