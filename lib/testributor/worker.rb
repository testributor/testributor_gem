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
      while true
        job = redis.rpop(Testributor::REDIS_JOBS_LIST)

        if job
          result = nil
          job = JSON.parse(job)
          Dir.chdir(Project::DIRECTORY) do
            result = TestJob.new(
              job.merge!('started_at_seconds_since_epoch' => Time.now.utc.to_i)
            ).run
          end
          redis.hset(Testributor::REDIS_REPORTS_HASH, job["id"], result.to_json)
        else
          sleep NO_JOBS_IN_QUEUE_TIMEOUT_SECONDS
        end
      end
    end

    private

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
