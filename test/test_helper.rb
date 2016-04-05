# Use different redis settings for tests
ENV['TESTRIBUTOR_REDIS_URL'] = ENV['TESTRIBUTOR_REDIS_TEST_URL'] || '127.0.0.1'
ENV['TESTRIBUTOR_REDIS_PORT'] = ENV['TESTRIBUTOR_REDIS_TEST_PORT'] || '6379'
ENV['TESTRIBUTOR_REDIS_DB'] = ENV['TESTRIBUTOR_REDIS_TEST_DB'] || 'testributor_test'

require 'testributor'
require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/pride'
require 'minitest/stub_any_instance'
require "mocha/mini_test"
require "timecop"
require "minitest/stub_const"

class MiniTest::Test

  def setup
    redis = Redis.new(host: Testributor::REDIS_HOST,
                      port: Testributor::REDIS_PORT,
                      db: Testributor::REDIS_DB)
    redis.flushall

    # Don't print things when running tests
    Testributor.stubs(:log).returns(true)
  end
end
