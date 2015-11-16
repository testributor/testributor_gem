require 'fileutils'

module Testributor
  class Worker
    # TODO: TBD we might want to sleep longer after many tries with nothing to run
    # (project developers might be sleeping, no need to keep polling too often)
    POLLING_TIMEOUT = 3
    PROJECT_DIR = ENV["HOME"] + '/.testributor'

    attr_reader :api_client, :repo_owner, :repo_name, :github_access_token, :repo,
      :build_commands, :overridden_files

    def initialize(app_id, app_secret)
      @api_client = Client.new(app_id, app_secret)
      current_project_response = @api_client.get_current_project
      # TODO: Consider creating a new model for current_project
      @repo_owner = current_project_response["repository_owner"]
      @repo_name = current_project_response["repository_name"]
      @github_access_token = current_project_response["github_access_token"]
      @build_commands = current_project_response["build_commands"]
      @overridden_files = current_project_response["files"]
      create_project_repo
      @repo = Rugged::Repository.new(PROJECT_DIR)
    end

    def run
      while true
        if (job_response = api_client.fetch_job_to_run)
          test_job = TestJob.new(job_response, self)
          fetch_project_repo if !@repo.exists?(test_job.commit_sha)
          Dir.chdir(PROJECT_DIR) do
            test_job.run
          end
        else
          sleep POLLING_TIMEOUT
        end
      end
    end

    # Create test database, install needed gems and run any custom build scripts
    def setup_test_environment
      log "Setting up environment"
      Dir.chdir(PROJECT_DIR) do
        Testributor.command('git reset --hard')
        overridden_files.each do |file|
          log "Creating #{file["path"]}"
          dirname = File.dirname(file["path"])
          unless File.directory?(dirname)
            FileUtils.mkdir_p(dirname)
          end
          File.write(file["path"], file["contents"])
        end

        log "Running build commands"
        Testributor.command("#{build_commands}") if build_commands && build_commands != ''
      end
    end

    private

    def create_project_repo
      Dir.mkdir(PROJECT_DIR) unless File.exists?(PROJECT_DIR)
      fetch_project_repo
    end

    def fetch_project_repo
      log "Fetching repo"
      Dir.chdir(PROJECT_DIR) do
        Testributor.command("git init")
        Testributor.command("git pull https://#{github_access_token}@github.com/#{repo_owner}/#{repo_name}.git")

        # Setup the environment because TestJob#run will not setup the
        # project if the commit is the current commit.
        setup_test_environment
      end
    end

    def log(message)
      Testributor.log(message)
    end
  end
end
