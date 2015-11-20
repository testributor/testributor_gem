require 'oauth2'
require 'securerandom'

module Testributor
  class Client
    attr_reader :token

    def initialize(app_id, app_secret)
      # Setup connection
      client = OAuth2::Client.new(app_id, app_secret, site: Testributor::API_URL)
      @token = client.client_credentials.get_token

      # If no uuid is already set, set it now
      Testributor.uuid ||= SecureRandom.uuid
    end

    def get_current_project
      request(:get, 'projects/current').parsed
    end

    # Asks the testributor API for a batch of jobs to run
    def fetch_jobs
      request(:patch, 'test_jobs/bind_next_batch').parsed
    end

    # Sends multiple job results to testributor in one call
    def update_test_jobs(params)
      request(:patch, "test_jobs/batch_update", body: { jobs: params }).parsed
    end

    private

    # Since we want to add our default header to every request and oauth2
    # does not have a way to add that to token, we wrap the oauth request method
    # to our version that adds the headers
    def request(verb, url, options={})
      options[:headers] ||= {}
      options[:headers]["WORKER_UUID"] = Testributor.uuid

      token.request(verb, url, options)
    end
  end
end
