require 'oauth2'

module Testributor
  class Client
    attr_reader :token

    def initialize(app_id, app_secret)
      # Setup connection
      client = OAuth2::Client.new(app_id, app_secret, site: Testributor::API_URL)
      @token = client.client_credentials.get_token
    end

    def get_current_project
      token.request(:get, 'projects/current').parsed
    end

    # Asks the testributor API for a job to run
    def fetch_job_to_run
      token.request(:patch, 'test_jobs/bind_next_pending').parsed
    end

    def update_test_job(id, params)
      token.request(:patch, "test_jobs/#{id}", params: params).parsed
    end
  end
end
