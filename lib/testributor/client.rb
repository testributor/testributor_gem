require 'oauth2'

class Testributor::Client
  attr_reader :token

  def initialize(app_id, app_secret)
    # Setup connection
    client = OAuth2::Client.new(app_id, app_secret, site: Testributor::API_URL)
    @token = client.client_credentials.get_token
  end

  def get_current_project
    token.request(:get, 'projects/current').parsed
  end

  # Asks the testributor API for a file to run
  def fetch_file_to_run
    token.request(:patch, 'test_job_files/bind_next_pending').parsed
  end
end
