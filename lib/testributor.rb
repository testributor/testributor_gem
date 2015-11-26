module Testributor
  # Use the SSL certificate provided by heroku for now
  API_URL = ENV["API_URL"] || "https://testributor.herokuapp.com/api/v1/"

  # We use the base_image installed redis for this gem. By default this
  # redis listens on port 6380 (default is 6379). The reason is to avoid letting
  # the user connect to this Redis by mistake (e.g. because no Redis image was
  # selected in technologies).
  REDIS_HOST = ENV['REDIS_URL'] || '127.0.0.1'
  REDIS_PORT = ENV['REDIS_PORT'] || '6380'
  REDIS_DB = ENV['REDIS_DB'] || 'testributor'

  REDIS_JOBS_LIST = 'jobs'
  REDIS_REPORTS_HASH = 'reports'

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
    @redis ||=
      Redis.new(:host => REDIS_HOST, :port => REDIS_PORT, :db => REDIS_DB)
  end

  def self.client
    @client ||= Client.new(ENV["APP_ID"], ENV["APP_SECRET"])
  end

  def self.start
    Thread.abort_on_exception = true

    Thread.current[:name] = "Main"

    @current_project = Project.new(client.get_current_project)

    worker_thread = Thread.new do
      Thread.current["name"] = "Worker"
      Testributor::Worker.new.run
    end

    manager_thread = Thread.new do
      Thread.current["name"] = "Manager"
      Testributor::Manager.new.run
    end

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
    puts "[#{Thread.current[:name]}]".ljust(15) << message
  end

  # Runs a system command and streams the output to the log if log_output is
  # true. In any case a Hash is returned with the command output and the
  # a result_type key which is:
  # - passed (0) when exit code is success
  # - failed (1) when exit code is not success and no stderr output is written
  # - error (2) when exit code is not success and there are contents in stderr
  def self.command(command_str, options={})
    options = {log_output: true, return_duration: false}.merge(options)
    final_command_str = force_ruby_version ? "rvm #{force_ruby_version} do #{command_str}"  : command_str
    start_time_at = Time.now
    stdin, stdout, stderr, wait_thread = Open3.popen3(final_command_str)
    duration = Time.now - start_time_at
    standard_output = ''
    standard_error = ''
    stdout.each do |s|
      standard_output << s
      options[:log_output] && log(s)
    end

    stderr.each do |s|
      standard_error << s
      options[:log_output] && log(s)
    end

    result_type =
      if wait_thread.value.success?
        RESULT_TYPES[:passed]
      elsif standard_error.strip == ''
        RESULT_TYPES[:failed]
      else
        RESULT_TYPES[:error]
      end

    h = {
      output: (standard_output + standard_error).strip, result_type: result_type
    }
    options[:return_duration] ? h.merge!(duration_seconds: duration) : h
  end
end

require 'testributor/manager'
require 'testributor/reporter'
require 'testributor/worker'
require 'testributor/client'
require 'testributor/test_job'
require 'testributor/project'
require 'rugged'
require 'open3'
require "redis"
