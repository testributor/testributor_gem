require 'oauth2'
require 'securerandom'
require 'net/http'

module Testributor
  class Client
    attr_reader :token
    REQUEST_ERROR_TIMEOUT_SECONDS = 10
    CONNECTION_ERRORS = [
      Faraday::ConnectionFailed,
      Net::ReadTimeout,
      OAuth2::Error,
      Faraday::TimeoutError,
      Testributor::InvalidSshKeyError
    ]

    # Use this method only when the exception occurs in testributor's side.
    # In this way, there is no need to restart the gem, each time testributor
    # server dies. Rescues all exceptions that have to do with katana
    # communication.
    def self.ensure_run
      begin
        start_time = Time.now
        yield
      rescue *CONNECTION_ERRORS => e
        # When OAuth2::Error occurs, e.code values can be one of the following:
        # :invalid_request,
        # :invalid_client,
        # :invalid_token,
        # :invalid_grant,
        # :unsupported_grant_type,
        # :invalid_scope.
        # If e.code is one of the above(not nil), then we assume something
        # is wrong in # the gem's side (code, configuration etc.).
        # Raise to let us know
        # If e.code is nil, no oauth error occurred.
        # As a result, there is probably a problem in the server's side.
        # In this case, we retry until the error is fixed in server.
        # Check the following url for details:
        # https://github.com/intridea/oauth2/blob/master/lib/oauth2/error.rb
        if e.respond_to?(:code) && e.code && e.is_a?(OAuth2::Error)
          raise e and return
        end

        # TODO : Send us a notification
        log "Error occured: #{e.message}\n #{e.inspect}"
        log "Error occured after #{Time.now - start_time} seconds"
        if Testributor.allow_retries_on_failure
          log "Retrying in #{REQUEST_ERROR_TIMEOUT_SECONDS} seconds"
          sleep(REQUEST_ERROR_TIMEOUT_SECONDS)
          retry
        end
      end
    end

    def initialize(app_id, app_secret)
      Testributor.log "Client is being initialized"
      # Setup connection
      client = OAuth2::Client.new(app_id, app_secret, site: Testributor::API_URL)

      Testributor::Client.ensure_run do
        @token = client.client_credentials.get_token
      end
    end

    def get_setup_data
      request(:get, 'projects/setup_data').parsed
    end

    # Asks the testributor API for a batch of jobs to run
    def fetch_jobs
      request(:patch, 'test_jobs/bind_next_batch').parsed
    end

    # Sends multiple job results to testributor in one call
    def update_test_jobs(params)
      request(:patch, "test_jobs/batch_update", body: { jobs: params }).parsed
    end

    def beacon
      request(:post, "projects/beacon")
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
