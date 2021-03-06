require 'securerandom'
module Testributor

  BENCHMARK_COMMAND_RANGE_SECONDS = 2..60

  # Use the SSL certificate provided by Heroku for now
  API_URL = ENV["API_URL"] || "https://testributor.herokuapp.com/api/v1/"

  # We use the base_image installed redis for this gem. By default this
  # redis listens on port 6380 (default is 6379). The reason is to avoid letting
  # the user connect to this Redis by mistake (e.g. because no Redis image was
  # selected in technologies).
  REDIS_HOST = ENV['TESTRIBUTOR_REDIS_URL'] || '127.0.0.1'
  REDIS_PORT = ENV['TESTRIBUTOR_REDIS_PORT'] || '6380'
  REDIS_DB = ENV['TESTRIBUTOR_REDIS_DB'] || 0

  REDIS_JOBS_LIST = 'jobs'
  REDIS_REPORTS_HASH = 'reports'

  def self.allow_retries_on_failure
    @allow_retries_on_failure
  end

  def self.allow_retries_on_failure=(allow_retries)
    @allow_retries_on_failure = allow_retries
  end

  def self.current_project
    @current_project
  end

  def self.force_ruby_version=(ruby_version)
    @force_ruby_version = ruby_version
  end

  def self.force_ruby_version
    @force_ruby_version
  end

  def self.uuid
    @uuid
  end

  def self.uuid=(uuid)
    @uuid = uuid
  end

  def self.last_test_run_id
    @last_test_run_id
  end

  def self.last_test_run_id=(id)
    @last_test_run_id = id
  end

  def self.short_uuid
    @short_uuid
  end

  def self.worker_current_job_started_at=(time)
    @worker_current_job_started_at = time
  end

  def self.worker_current_job_cost_prediction=(cost_prediction)
    @worker_current_job_cost_prediction = cost_prediction
  end

  # Returns the number of seconds of workload left on the worker.
  # This is the cost prediction of the current working job minus the number
  # of seconds the worker is already running this job.
  # If started at is set but prediction is nil it means the current job has no
  # prediction so we return nil. The caller (Manager) should not request for more
  # work until this job is done since we don't know how long it will take.
  # We are being pessimistic here, as we do on the katana side.
  def self.workload_on_worker
    if @worker_current_job_cost_prediction.nil?
      if @worker_current_job_started_at.nil?
        return 0 # There is no current job
      else
        return nil # We have no prediction for the current job
      end
    end

    [@worker_current_job_cost_prediction -
      (Time.now - @worker_current_job_started_at), 0].max
  end

  def self.redis_blacklisted_test_run_key(test_run_id)
    "blacklist_test_run_#{test_run_id}"
  end

  # These should much the codes on the testributor side
  RESULT_TYPES = {
    passed: 3,
    failed: 4,
    error: 5
  }

  def self.redis
    @redis
  end

  def self.client
    @client
  end

  def self.start
    Thread.abort_on_exception = true

    Thread.current[:name] = "Main"

    # Don't memoize these to avoid races conditions between threads using it.
    # http://lucaguidi.com/2014/03/27/thread-safety-with-ruby.html
    # We initialize all shared variables once.
    @client = Client.new(ENV["APP_ID"], ENV["APP_SECRET"])
    @redis = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT, :db => REDIS_DB)
    @uuid = SecureRandom.uuid
    @short_uuid = @uuid.split("-").first

    # Clear any relics. Stopped workers should start fresh to avoid sending
    # irrelevant statistics about queue times etc. Katana reassigns jobs when
    # workers die so it should be no problem.
    @redis.flushdb

    @current_project = Project.new(client.get_setup_data)

    log "Starting Worker thread"
    worker_thread = Thread.new do
      Thread.current["name"] = "Worker"
      Testributor::Worker.new.run
    end

    log "Starting Manager thread"
    manager_thread = Thread.new do
      Thread.current["name"] = "Manager"
      Testributor::Manager.new.run
    end

    log "Starting Reporter thread"
    reporter_thread = Thread.new do
      Thread.current["name"] = "Reporter"
      Testributor::Reporter.new.run
    end

    worker_thread.join
    manager_thread.join
    reporter_thread.join
  end

  # We might want to implement a different logging mechanism.
  # For now, it's just "puts".
  def self.log(message)
    now = Time.now.utc.strftime "%H:%M:%S UTC"
    puts "[#{now}][#{short_uuid}][#{Thread.current[:name]}] ".ljust(25) << message
    STDOUT.flush # Always flush the output to show the messages immediately
  end

  # Runs a system command and streams the output to the log if log_output is
  # true. In any case a Hash is returned with the command output and the
  # a result_type key which is:
  # - passed (0) when exit code is success
  # - failed (1) when exit code is not success and no stderr output is written
  # - error (2) when exit code is not success and there are contents in stderr
  # TODO: popen3 takes a :chdir option. Consider using this instead of Dir.chdir
  # block.
  def self.command(command_str, options={})
    options = {log_output: true, return_duration: false}.merge(options)
    final_command_str = if force_ruby_version
                          "rvm #{force_ruby_version} do #{command_str}"
                        else
                          command_str
                        end
    start_time_at = Time.now

    # https://nickcharlton.net/posts/ruby-subprocesses-with-stdout-stderr-streams.html
    # see: http://stackoverflow.com/a/1162850/83386
    stdout_data = ''
    stderr_data = ''
    result_type = nil
    exit_code = nil
    thread_name = Thread.current["name"]
    threads = []

    if ENV["BENCHMARK_MODE"]
      final_command_str = "sleep #{rand(BENCHMARK_COMMAND_RANGE_SECONDS)}"
    end

    Open3.popen3(final_command_str) do |stdin, stdout, stderr, thread|
      # read each stream from a new thread
      [[stdout_data, stdout], [stderr_data, stderr]].each do |store_var, stream|
        threads << Thread.new do
          # give the same name as the caller thread to show in output
          # This threads are just helpers to read both streams at the same time
          # so the don't need a name on their own.
          Thread.current[:name] = thread_name
          until (line = stream.gets).nil? do
            store_var << line # append new lines
            options[:log_output] && log(line)
          end
        end
      end

      result_type =
        if thread.value.success?
          RESULT_TYPES[:passed]
        elsif stderr_data.strip == ''
          RESULT_TYPES[:failed]
        else
          RESULT_TYPES[:error]
        end

      # Wait 1 second for stream threads to be "joined".
      # The main thread (the command) is done so any commands binding the stdout
      # or stderr like E.g.
      #  Xvfb :1 -screen 0 1024x768x24 &
      # should not prevent this method from returning.
      # Give a fair timeout in case there is some last data on a stream which
      # the thread did not have the time to read.
      begin
        Timeout::timeout(1) {
          threads.map(&:join)
        }
      rescue Timeout::Error
        threads.each(&:exit)
      end

      # Keep the system exit code too. Useful for general purpose commands.
      exit_code = thread.value.exitstatus
    end
    duration = Time.now - start_time_at

    h = {
      # TODO: The output should be in the same order it was logged. Now the
      # error is always last.
      output: (stdout_data + stderr_data).strip,
      result_type: result_type,
      exit_code: exit_code
    }

    options[:return_duration] ? h.merge!(duration_seconds: duration) : h
  end

  class InvalidSshKeyError < StandardError
    def initialize(msg='No repository access - Check your SSH key')
      super
    end
  end
end

Testributor.allow_retries_on_failure = true

require 'testributor/constants'
require 'testributor/manager'
require 'testributor/reporter'
require 'testributor/worker'
require 'testributor/client'
require 'testributor/test_job'
require 'testributor/setup_job'
require 'testributor/project'
require 'rugged'
require 'open3'
require "redis"
