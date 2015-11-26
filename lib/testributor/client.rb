require 'oauth2'
require 'securerandom'
require 'net/http'

module Testributor
  class Client
    attr_reader :token
    REQUEST_ERROR_TIMEOUT_SECONDS = 10
    CONNECTION_ERRORS = [Faraday::ConnectionFailed, Net::ReadTimeout]

    # Use this method only when the exception occurs in testributor's side.
    # In this way, there is no need to restart the gem, each time testributor
    # server dies. Rescues all exceptions that have to do with katana
    # communication.
    def self.ensure_run
      begin
        yield
      rescue *CONNECTION_ERRORS => e
        # TODO : Send us a notification
        log "Error occured: #{e.message}"
        log e.inspect
        log "Retrying in #{REQUEST_ERROR_TIMEOUT_SECONDS} seconds"
        sleep(REQUEST_ERROR_TIMEOUT_SECONDS)
        retry
      end
    end

    def initialize(app_id, app_secret)
      # Setup connection
      client = OAuth2::Client.new(app_id, app_secret, site: Testributor::API_URL)
      Testributor::Client.ensure_run do
        @token = client.client_credentials.get_token
      end

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

    def self.log(message)
      Testributor.log(message)
    end

    # Since we want to add our default header to every request and oauth2
    # does not have a way to add that to token, we wrap the oauth request method
    # to our version that adds the headers
    def request(verb, url, options={})
      Testributor::Client.ensure_run do
        options[:headers] ||= {}
        options[:headers]["WORKER_UUID"] = Testributor.uuid

        token.request(verb, url, options)
      end
    end
  end
end
