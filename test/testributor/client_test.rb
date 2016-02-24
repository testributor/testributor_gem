require 'test_helper'

class ClientTest < MiniTest::Test
  describe ".ensure_run" do
    before do
      Testributor.stubs(:allow_retries_on_failure).returns(false)
    end

    it "logs exceptions in exception in CONNECTION_ERRORS" do
      Testributor::Client.expects(:log).twice
      Testributor::Client.ensure_run do
        raise Faraday::ConnectionFailed, "connection failed"
      end
    end

    it "raises exception if OAuth2::Error and e.code.present?" do
      Testributor::Client.expects(:log).never
      OAuth2::Error.any_instance.stubs(:code).returns("invalid_client")
      -> do
        Testributor::Client.ensure_run do
          raise OAuth2::Error, OpenStruct.new
        end
      end.must_raise OAuth2::Error
    end

    it "logs exception if OAuth2::Error and e.code.nil?" do
      Testributor::Client.expects(:log).twice
      Testributor::Client.ensure_run do
        raise OAuth2::Error, OpenStruct.new
      end
    end
  end
end
