# This is a wrapper class around the test_job_file response from testributor
class TestJobFile
  attr_reader :api_client, :commit_sha, :file_name

  def initialize(file_response, api_client)
    @commit_sha = file_response["test_job"]["commit_sha"]
    @file_name = file_response["file_name"]
    @api_client = api_client
  end

  def run
    unless commit_sha == current_commit_sha
      checkout_to_job_commit
      setup_test_environment
    end

    # TODO: Change the reporter or do something so we can get the output
    # structured
    #`bin/rake test #{file_name}`
    log "Running test file #{file_name}"

    report_results
  end

  private

  def current_commit_sha
    # TODO:
    `git rev-parse HEAD`
  end

  def checkout_to_job_commit
    log "Checking out #{commit_sha}"
    # TODO: fetch and checkout to commit
    # token = api_client.get_github_api_key
    # puts `mkdir #{repo_name}`
    # Dir.chdir repo_name
    # puts `pwd`
    # puts `git init`
    # puts `git pull https://#{token}@github.com/#{owner}/#{repo_name}.git`
  end

  # Create test database, install needed gems and run any custom build scripts
  def setup_test_environment
    log "Setting up environment"
    # TODO
    # puts `bundle install`
    # puts `RAILS_ENV=test bin/rake db:setup`
  end

  def report_results
    log "Reporting to testributor"
    # TODO
  end

  def log(message)
    Testributor.log(message)
  end
end
