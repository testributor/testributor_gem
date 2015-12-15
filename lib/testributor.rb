module Testributor
  # Use the SSL certificate provided by heroku for now
  API_URL = ENV["API_URL"] || "https://testributor.herokuapp.com/api/v1/"

  # We use the base_image installed redis for this gem. By default this
  # redis listens on port 6380 (default is 6379). The reason is to avoid letting
  # the user connect to this Redis by mistake (e.g. because no Redis image was
  # selected in technologies).
  REDIS_HOST = ENV['TESTRIBUTOR_REDIS_URL'] || '127.0.0.1'
  REDIS_PORT = ENV['TESTRIBUTOR_REDIS_PORT'] || '6380'
  REDIS_DB = ENV['TESTRIBUTOR_REDIS_DB'] || 'testributor'

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

  def self.uuid=(uuid)
    @uuid = uuid
  end

  def self.uuid
    @uuid
  end

  def self.redis_blacklisted_test_run_key(test_run_id)
    "blacklist_test_run_#{test_run_id}"
  end

  # These should much the codes on the testributor side
  RESULT_TYPES = {
    passed: 2,
    failed: 3,
    error: 4
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

    @current_project = Project.new(client.get_current_project)

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
    puts "[#{now}][#{Thread.current[:name]}]".ljust(25) << message
    STDOUT.flush # Always flush the output to show the messages immediatelly
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
    final_command_str = force_ruby_version ? "rvm #{force_ruby_version} do #{command_str}"  : command_str
    start_time_at = Time.now

    # https://nickcharlton.net/posts/ruby-subprocesses-with-stdout-stderr-streams.html
    # see: http://stackoverflow.com/a/1162850/83386
    data = {:out => '', :err => ''}
    result_type = nil
    thread_name = Thread.current["name"]
    threads = []
    Open3.popen3(final_command_str) do |stdin, stdout, stderr, thread|
      # read each stream from a new thread
      { :out => stdout, :err => stderr }.each do |key, stream|
        threads << Thread.new do
          # give the same name as the caller thread to show in output
          # This threads are just helpers to read both streams at the same time
          # so the don't need a name on their own.
          Thread.current[:name] = thread_name
          until (line = stream.gets).nil? do
            data[key] << line # append new lines
            options[:log_output] && log(line) # append new lines
          end
        end
      end

      threads.each(&:join)

      result_type =
        if thread.value.success?
          RESULT_TYPES[:passed]
        elsif data[:err].strip == ''
          RESULT_TYPES[:failed]
        else
          RESULT_TYPES[:error]
        end
    end
    duration = Time.now - start_time_at

    h = { output: (data[:out] + data[:err]).strip, result_type: result_type }

    options[:return_duration] ? h.merge!(duration_seconds: duration) : h
  end
end

Testributor.allow_retries_on_failure = true

require 'testributor/manager'
require 'testributor/reporter'
require 'testributor/worker'
require 'testributor/client'
require 'testributor/test_job'
require 'testributor/project'
require 'rugged'
require 'open3'
require "redis"
