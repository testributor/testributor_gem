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

    def run
      while true
        reports = redis.hgetall(Testributor::REDIS_REPORTS_HASH)
        if reports.any?
          if !report(redis.hgetall(Testributor::REDIS_REPORTS_HASH))
            log "Sleeping due to errors"
            sleep REPORT_ERROR_TIMEOUT_SECONDS
            next
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
      begin
        result = client.update_test_jobs(reports)
        return false if result.is_a?(Hash) && result[:error]
      rescue
        return false
      end

      redis.hdel(Testributor::REDIS_REPORTS_HASH, reports.keys)
    end

    def redis
      Testributor.redis
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
