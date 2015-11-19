module Testributor
  # This class implements all the code run in the Manager thread.
  # The main method (#run) checks every LIST_CHECK_TIMEOUT_SECONDS seconds the
  # Testributor::REDIS_JOBS_LIST on redis and the number of jobs is less or
  # equal to MINIMUM_NUMBER_OF_JOBS_IN_QUEUE, it requests more
  # jobs from testributor. If testributor replied with no jobs the method sleeps
  # for NO_JOBS_ON_TESTRIBUTOR_TIMEOUT_SECONDS to avoid hitting testributor
  # too frequently when there is nothing to do.
  # TODO: Use an exponential backoff timeout?
  class Manager
    LIST_CHECK_TIMEOUT_SECONDS = 1
    NO_JOBS_ON_TESTRIBUTOR_TIMEOUT_SECONDS = 5
    MINIMUM_NUMBER_OF_JOBS_IN_QUEUE = 2

    def run
      while true
        if running_low_on_jobs
          if (jobs = client.fetch_jobs).any?
            jobs.each do |job|
              job.merge!(queued_at_seconds_since_epoch: Time.now.utc.to_i)
              redis.lpush(Testributor::REDIS_JOBS_LIST, job.to_json)
            end
            sleep LIST_CHECK_TIMEOUT_SECONDS
          else
            sleep NO_JOBS_ON_TESTRIBUTOR_TIMEOUT_SECONDS
          end
        else
          sleep LIST_CHECK_TIMEOUT_SECONDS
        end
      end
    end

    private

    def running_low_on_jobs
      redis.llen(Testributor::REDIS_JOBS_LIST) <=
        MINIMUM_NUMBER_OF_JOBS_IN_QUEUE
    end

    # Use different redis connection for each thread
    def redis
      @redis ||= Redis.new(
        :host => Testributor::REDIS_HOST,
        :port => Testributor::REDIS_PORT,
        :db => Testributor::REDIS_DB)
    end

    def client
      Testributor.client
    end

    def log(message)
      Testributor.log(message)
    end
  end
end
