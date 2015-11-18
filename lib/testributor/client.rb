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

    # Asks the testributor API for a batch of jobs to run
    def fetch_jobs
      token.request(:patch, 'test_jobs/bind_next_batch').parsed
    end

    # Sends multiple job results to testributor in one call
    def update_test_jobs(params)
      token.request(:patch, "test_jobs/batch_update",
                    body: { jobs: params }).parsed
    end
  end
end
