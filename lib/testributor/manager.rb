module Testributor
  # This class implements all the code run in the Manager thread.
  # The main method (#run) checks every LIST_CHECK_TIMEOUT_SECONDS seconds
  # to see wether the worker is running low on workload. If that's the case,
  # it loads more work from testributor to the worker's queue.
  #
  # If testributor replied with no jobs the method sleeps
  # for NO_JOBS_ON_TESTRIBUTOR_TIMEOUT_SECONDS to avoid hitting testributor
  # too frequently when there is nothing to do.
  # TODO: Use an exponential backoff timeout?
  class Manager
    # Don't check to often because each time we parse the list we are also
    # parsing the JSONed jobs and sum up the cost predictions. We need the CPU
    # for the Worker thread. Don't waste it here.
    LIST_CHECK_TIMEOUT_SECONDS = 3
    NO_JOBS_ON_TESTRIBUTOR_TIMEOUT_SECONDS = 5
    LOW_WORKLOAD_LIMIT_SECONDS = 10

    def run
      log "Entering Manager loop"
      loop do
        if low_workload?
          if (jobs = client.fetch_jobs).any?
            log "Fetched #{jobs.count} jobs to run"
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

    def low_workload?
      on_worker = Testributor.workload_on_worker
      in_queue = workload_in_queue

      # Don't fetch more work if there are jobs with no prediction
      return false if on_worker.nil? || in_queue.nil?

      in_queue + on_worker <= LOW_WORKLOAD_LIMIT_SECONDS
    end

    # Returns the sum of the cost predictions for the jobs in the queue
    # Returns nil if there is a job with no prediction in queue
    def workload_in_queue
      cost_predictions = redis.lrange(Testributor::REDIS_JOBS_LIST, 0, -1).
        map{|j| JSON.parse(j)["cost_prediction"].to_f}

      # TODO: Fix this, since we call "to_f" above, it can never be nil
      return nil if cost_predictions.index(:nil?) && cost_predictions.any?

      cost_predictions.inject(0, :+)
    end

    # Use different redis connection for each thread
    def redis
      return @redis if @redis

      log "Connecting to Redis: {"\
            " host: #{Testributor::REDIS_HOST.inspect},"\
            " port: #{Testributor::REDIS_PORT.inspect},"\
            " db: #{Testributor::REDIS_DB.inspect} }"
      @redis = Redis.new(
        :host => Testributor::REDIS_HOST,
        :port => Testributor::REDIS_PORT,
        :db => Testributor::REDIS_DB)
    end

    def client
      # Testributor.client
      # NOTE: Use a different client per thread to investigate the Faraday timeout
      # errors
      @client ||= Client.new(ENV["APP_ID"], ENV["APP_SECRET"])
    end

    def log(message)
      Testributor.log(message)
    end
  end
end
