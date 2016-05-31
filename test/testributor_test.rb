require 'test_helper'

class TestributorTest < MiniTest::Test
  describe "command" do
    it "does not wait for command to finish to show stderr" do
      log = ''
      Testributor.stub(:log, ->(m){log << m}) do
        command =
          %q{/bin/bash -c "ruby -e 'raise'; ruby -e 'puts \"stdout_here\"'"}
        Testributor.command(command)
      end
      log.must_match(/.*exception.*stdout_here.*/m)
    end
  end
end
