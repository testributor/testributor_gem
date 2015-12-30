require 'fileutils'

module Testributor
  # This class implements all the code run in the Worker thread.
  # The main method (#run) reads a job from the Testributor::REDIS_JOBS_LIST
  # wraps the job in a TestJob and runs it. The result is written in
  # Testributor::REDIS_REPORTS_HASH and the job is deleted from the
  # Testributor::REDIS_JOBS_LIST after that. If after trying to get a new job
  # from the REDIS_JOBS_LIST, no job is found, the method sleeps for
  # NO_JOBS_IN_QUEUE_TIMEOUT_SECONDS seconds to avoid hitting the redis database
  # to frequently even if no jobs are queued.
  class Worker
    NO_JOBS_IN_QUEUE_TIMEOUT_SECONDS = 3

    def run
      log "Entering Worker loop"
      loop { handle_next_job }
    end

    private

    # We wrap the loop's code in a separate method to make testing easier
    def handle_next_job
      job = redis.rpop(Testributor::REDIS_JOBS_LIST)

      if job
        result = nil
        job = JSON.parse(job)
        # Skip blacklisted test runs
        test_run_id = job["test_run"]["id"]
        if redis.get(Testributor.redis_blacklisted_test_run_key(test_run_id))
          log "Skipping job #{job["id"]} for blacklisted test run #{test_run_id}"
          return
        end

        set_current_job(job)
        Dir.chdir(Project::DIRECTORY) do
          result = TestJob.new(
            job.merge!('started_at_seconds_since_epoch' => Time.now.utc.to_i)
          ).run
        end
        result.merge!("test_run_id" => job["test_run"]["id"])
        redis.hset(Testributor::REDIS_REPORTS_HASH, job["id"], result.to_json)
      else
        set_current_job(nil)
        sleep NO_JOBS_IN_QUEUE_TIMEOUT_SECONDS
      end
    end

    # Sets the current job cost prediction details using the Testributor methods
    def set_current_job(job)
      if job.nil?
        Testributor.worker_current_job_started_at = nil
        Testributor.worker_current_job_cost_prediction = nil
      else
        Testributor.worker_current_job_started_at = Time.now
        Testributor.worker_current_job_cost_prediction = job["cost_prediction"].to_f
      end
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
      Testributor.client
    end

    def log(message)
      Testributor.log(message)
    end
  end
end
