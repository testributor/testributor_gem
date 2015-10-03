module Testributor
  # Use the SSL certificate provided by heroku for now
  API_URL = ENV["API_URL"] || "https://testributor.herokuapp.com/api/v1/"

  # We might want to implement a different logging mechanism.
  # For now, it's just "puts".
  def self.log(message)
    puts message
  end
end

require 'testributor/worker'
require 'testributor/client'
require 'testributor/test_job_file'
require 'rugged'
