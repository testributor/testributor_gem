require 'test_helper'

class TestributorTest < MiniTest::Test
  describe "#project_dir_exists?" do
    subject { Testributor.new('api_key', 'api_secret') }

    before do
    end

    after do
      FileUtils.rm_rf(Testributor::PROJECT_DIR)
    end

    it "returns true when directory exists" do
      Dir.mkdir(Testributor::PROJECT_DIR) unless File.exists?(Testributor::PROJECT_DIR)

      Testributor::Client.stub :new, true do
        subject.send(:project_dir_exists?).must_equal true
      end
    end

    it "returns false when directory does not exist" do
      Testributor::Client.stub :new, true do
        subject.send(:project_dir_exists?).must_equal false
      end
    end
  end
end
