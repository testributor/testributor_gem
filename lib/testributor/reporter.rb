module Testributor
  # This class implements all the code run in the Reporter thread.
  # The main method (#run) checks the REDIS_HASH_NAME list for completed
  # jobs every REPORTING_FREQUENCY_SECONDS seconds. When there are completed
  # jobs, it sends them to testributor and clears the list upon success.
  # The Testributor::REDIS_REPORTS_HASH list is filled by the Worker thread
  # (see Worker class for more).
  # TODO: When reporting to katana there is a possibility that the jobs
  # refer to a now cancelled (or destoyed) test run. In this case katana
  # should respond with a list of cancelled/destroyed runs. This class should
  # then remove the jobs from the REDIS_JOBS_LIST to prevent the worker from 
  # running those.
  class Reporter
    # If Worker pushes completed jobs a lot faster than this interval,
    # we simply report multiple (small) jobs in batches. If Worker pushes
    # a lot slower (e.g. one every 15 seconds), we simply report each job
    # separately (almost as soon as it gets completed).
    REPORTING_FREQUENCY_SECONDS = 5
    # If we cannot send reports, it probably means there is a problem on the
    # testributor side. Sleep for a while before trying again.
    # TODO: Stop the manager thread until the reporter succeeds. We don't want
    # jobs assigned to workers when there is a problem.
    REPORT_ERROR_TIMEOUT_SECONDS = 60
    BLACKLIST_EXPIRATION_SECONDS = 3600

    def run
      log "Entering Reporter loop"
      loop do
        reports = redis.hgetall(Testributor::REDIS_REPORTS_HASH)
        if reports.any?
          if !(response = report(reports))
            log "Sleeping due to errors"
            sleep REPORT_ERROR_TIMEOUT_SECONDS
            next
          else
            blacklist_test_runs(response['delete_test_runs'])
          end
        else
          sleep REPORTING_FREQUENCY_SECONDS
        end
      end
    end

    private

    # @param reports [Hash] the list of completed jobs to send to testributor
    def report(reports)
      log "Sending reports to testributor"
      result = client.update_test_jobs(reports) rescue false
      return false if (!result || result[:error])

      redis.hdel(Testributor::REDIS_REPORTS_HASH, reports.keys)

      result
    end

    # Add an expiring key for each deleted test_run (blacklist).
    # When the user pops a job for a blacklisted run it will be skipped.
    # The keys will expire so they will only be run again if the job stays
    # in queue for too long.
    def blacklist_test_runs(test_run_ids)
      return false if test_run_ids.to_a.empty?

      log "Blacklisting jobs for TestRuns: #{test_run_ids}"
      test_run_ids.each do |test_run_id|
        key = Testributor.redis_blacklisted_test_run_key(test_run_id)
        redis.setnx(key, 1)
        redis.expire(key, BLACKLIST_EXPIRATION_SECONDS)
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
