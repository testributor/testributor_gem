module Testributor
  # Use the SSL certificate provided by heroku for now
  API_URL = ENV["API_URL"] || "https://testributor.herokuapp.com/api/v1/"

  # We might want to implement a different logging mechanism.
  # For now, it's just "puts".
  def self.log(message)
    puts message
  end

  # Runs a system command and streams the output to the log if log_output is
  # true. In any case a Hash is returns with the command output and the
  # a "success" key which is true when the command's exit code indicates
  # a successfull command.
  def self.command(command_str, log_output=true)
    stdin, stdout, stderr, wait_thread = Open3.popen3(command_str)
    final_output = ''
    stdout.each do |s|
      final_output << s
      log_output && log(s)
    end

    stderr.each do |s|
      final_output << s
      log_output && log(s)
    end

    { output: final_output, success: wait_thread.value.success? }
  end
end

require 'testributor/worker'
require 'testributor/client'
require 'testributor/test_job'
require 'rugged'
require 'open3'
