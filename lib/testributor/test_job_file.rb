# This is a wrapper class around the test_job_file response from testributor
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

    # TODO: Change the reporter or do something so we can get the output
    # structured
    #`bin/rake test #{file_name}`
    log "Running test file #{file_name}"
    log `bin/rake test #{file_name}`

    report_results
  end

  # Yields the given block is test_job commit is different from the current one
  def commit_changed?
    # Use only the first 6 characters from each SHA1 to compare
    current_commit_sha[0..5] != commit_sha[0..5]
  end

  private

  def current_commit_sha
    Dir.chdir(Testributor::PROJECT_DIR) do
      `git rev-parse HEAD`.strip
    end
  end

  # TODO: Handle the following case gracefully:
  # Testributor#run has already fetched the repo if the commit is not known.
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
    Dir.chdir(Testributor::PROJECT_DIR) do
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
