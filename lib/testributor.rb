module Testributor
  # Use the SSL certificate provided by heroku for now
  API_URL = ENV["API_URL"] || "https://testributor.herokuapp.com/api/v1/"

  # These should much the codes on the testributor side
  RESULT_TYPES = {
    passed: 2,
    failed: 3,
    error: 4
  }

  # We might want to implement a different logging mechanism.
  # For now, it's just "puts".
  def self.log(message)
    puts message
  end

  # Runs a system command and streams the output to the log if log_output is
  # true. In any case a Hash is returned with the command output and the
  # a result_type key which is:
  # - passed (0) when exit code is success
  # - failed (1) when exit code is not success and no stderr output is written
  # - error (2) when exit code is not success and there are contents in stderr
  def self.command(command_str, log_output=true)
    stdin, stdout, stderr, wait_thread = Open3.popen3(command_str)
    standard_output = ''
    standard_error = ''
    stdout.each do |s|
      standard_output << s
      log_output && log(s)
    end

    stderr.each do |s|
      standard_error << s
      log_output && log(s)
    end

    result_type =
      if wait_thread.value.success?
        RESULT_TYPES[:passed]
      elsif standard_error.strip == ''
        RESULT_TYPES[:failed]
      else
        RESULT_TYPES[:error]
      end

    { output: (standard_output + standard_error).strip, result_type: result_type }
  end
end

require 'testributor/worker'
require 'testributor/client'
require 'testributor/test_job'
require 'rugged'
require 'open3'
