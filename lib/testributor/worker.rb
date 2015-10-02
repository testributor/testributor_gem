module Testributor
  class Worker
    # TODO: TBD we might want to sleep longer after many tries with nothing to run
    # (project developers might be sleeping, no need to keep polling too often)
    POLLING_TIMEOUT = 3
    PROJECT_DIR = ENV["HOME"] + '/.testributor'

    attr_reader :api_client, :repo_owner, :repo_name, :github_access_token, :repo

    def initialize(app_id, app_secret)
      @api_client = Client.new(app_id, app_secret)
      current_project_response = @api_client.get_current_project
      # TODO: Consider creating a new model for current_project
      @repo_owner = current_project_response["repository_owner"]
      @repo_name = current_project_response["repository_name"]
      @github_access_token = current_project_response["github_access_token"]
      @build_commands = current_project_response["build_commands"]
      create_project_repo
      @repo = Rugged::Repository.new(PROJECT_DIR)
    end

    def run
      while true
        if (file_response = api_client.fetch_file_to_run)
          test_job_file = TestJobFile.new(file_response, @repo, api_client, @build_commands)
          fetch_project_repo if !@repo.exists?(test_job_file.commit_sha)
          Dir.chdir(PROJECT_DIR) do
            test_job_file.run
          end
        else
          sleep POLLING_TIMEOUT
        end
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
        log `git init`
        log `git pull https://#{github_access_token}@github.com/#{repo_owner}/#{repo_name}.git`
      end
    end

    def log(message)
      Testributor.log(message)
    end
  end
end
