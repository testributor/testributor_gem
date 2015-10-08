module Testributor
  # Use the SSL certificate provided by heroku for now
  API_URL = ENV["API_URL"] || "https://testributor.herokuapp.com/api/v1/"

  # We might want to implement a different logging mechanism.
  # For now, it's just "puts".
  def self.log(message)
    puts message
  end

  # Runs a system command and streams the output to the log if log_output is
  # true. In any case the output is returned
  def self.command(command_str, log_output=true)
    stdin, stdout, stderr = Open3.popen3(command_str)
    final_output = ''
    stdout.each do |s|
      final_output << s
      log_output && log(s)
    end

    final_output
  end
end

require 'testributor/worker'
require 'testributor/client'
require 'testributor/test_job_file'
require 'rugged'
require 'open3'
