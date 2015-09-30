class Testributor
  # TODO: TBD we might want to sleep longer after many tries with nothing to run
  # (project developers might be sleeping, no need to keep polling too often)
  POLLING_TIMEOUT = 3
  API_URL = ENV["API_URL"] || "http://www.testributor.com/api/v1/"
  PROJECT_DIR = ENV["HOME"] + '/testributor'

  attr_reader :api_client # The testributor API client

  def initialize(app_id, app_secret)
    @api_client = Client.new(app_id, app_secret)
    # TODO: Create endpoint in katana to return this Doorkeeper application's
    # details. Those are, the github api token, the repo name, the repo owner etc
    # Assign them to instance variables here so they can be accessed everywhere.
    #
    # details = @api_client.get_client_details
    # @owner = details['owner']
    # @repo = details['repo_name']
  end

  def run
    fetch_project_repo unless project_dir_exists?

    while true
      if (file_response = api_client.fetch_file_to_run)
        test_job_file = TestJobFile.new(file_response, @api_client)
        test_job_file.run
      else
        sleep POLLING_TIMEOUT
      end
    end
  end

  private

  # We might want to implement a different logging mechanism.
  # For now, it's just "puts".
  def self.log(message)
    puts message
  end

  def project_dir_exists?
    File.directory?(PROJECT_DIR)
  end

  def fetch_project_repo
    puts "Fetching repo"
    # TODO: Ask for github credentials and fetch the code and switch working
    # directory to the project directory.
    # @repo_token ||= client.get_repo_and_api_token
  end
end

require 'testributor/client'
require 'testributor/test_job_file'
