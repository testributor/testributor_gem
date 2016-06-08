require 'safe_yaml'

# This is a wrapper class around the test_job response from testributor
module Testributor
  class SetupJob

    # https://github.com/dtao/safe_yaml#configuration
    SafeYAML::OPTIONS[:default_mode] = :safe

    TESTRIBUTOR_YML_PATH = "testributor.yml"
    SHA_HISTORY_LIMIT = 30
    # The user might accidentally set the pattern to a very "loose" regex.
    # This could result in a huge number of matching files which could end up
    # filling our database with garbage. We filter this on the server too but
    # we avoid sending those files over the wire by checking on the worker
    # side too.
    # TODO: Check this on the server side too (the user might tamper this code).
    MATCHING_FILES_SANITY_LIMIT = 1000

    attr_reader :test_run_id, :commit_sha, :testributor_yml

    def initialize(job_response)
      @test_run_id = job_response["test_run"]["id"]
      @commit_sha = job_response["test_run"]["commit_sha"]
      # When testributor.yml exists on the repo is takes precedence over the
      # one on the server.
      @testributor_yml =
        if File.exists?(TESTRIBUTOR_YML_PATH)
          File.read(TESTRIBUTOR_YML_PATH)
        else
          job_response["testributor_yml"]
        end
    end

    def run
      # Return an error if commit does not exist.
      result = Testributor.current_project.checkout_commit(commit_sha)

      return result if result.is_a?(Hash) && result[:error]

      Testributor.log "Setting up Build ##{test_run_id} (commit: ##{commit_sha})"

      parsed_yml = testributor_yml_parsed_or_error
      # If testributor.yml comes from the repo it might be invalid
      if parsed_yml[:error]
        { error: parsed_yml[:error] }
      else
        jobs = []
        parsed_yml = parsed_yml[:parsed]
        if each_description = parsed_yml.delete("each")
          pattern = each_description["pattern"]
          command = each_description["command"]
          before = each_description["before"].to_s
          after = each_description["after"].to_s

          files = matching_files(pattern)
          return files if (files.is_a?(Hash) && files[:error])

          jobs += files.map do |f|
            { job_name: f,
              command: command.gsub(/%{file}/, f),
              before: before,
              after: after }
          end
        end

        parsed_yml.each do |job_name, description|
          command = description["command"]
          before = description["before"].to_s
          after = description["after"].to_s
          jobs << { job_name: job_name, command: command,
                    before: before, after: after }
        end

        { jobs: jobs }.merge(commit_metadata)
      end
    end

    private

    # Returns a hash with metadata for the current commit
    # These are data needed on Katana to be able to show full information
    # about the commit. Katana has no way to get this info so worker will
    # provide.
    # https://git-scm.com/docs/pretty-formats
    def commit_metadata
      git_mappings = {
        commit: '%H',
        author_name: '%an',
        author_email: '%ae',
        commiter_name: '%cn',
        commiter_email: '%ce',
        subject: '%s',
        body: '%b',
        committer_date_unix: '%ct'
      }

      git_command = "git log -1 --format=format:'%{var}' #{commit_sha}"
      result = {}
      git_mappings.each do |attr, var|
        result[attr] = Testributor.command(
          git_command.gsub(/%{var}/, var),
          log_output: false)[:output]
      end

      result[:sha_history] = Testributor.command(
        "git log -#{SHA_HISTORY_LIMIT} --format=format:'%H'",
        log_output: false)[:output].split("\n")

      result
    end

    def matching_files(regex)
      begin
        regex = Regexp.new(regex)
      rescue
        return { error: "Matching pattern is not a valid regular expression" }
      end

      bash_command = [
        "find .",                 # Find all files
        %q[sed -e 's/^\.\///g'],  # Remove the "./" from the beginning of the paths
        "egrep '#{regex.source}'" # Match files with Regex
      ].join(' | ')               # Pipe the commands together

      result = Testributor.command(bash_command, log_output: false)
      if result[:exit_code] == 0
        files = result[:output].split("\n")
        if files.size > MATCHING_FILES_SANITY_LIMIT
          { error: "Your pattern matches over #{MATCHING_FILES_SANITY_LIMIT} files. Aborting." }
        else
          files
        end
      else
        { error: result[:output] }
      end
    end

    def testributor_yml_parsed_or_error
      begin
        { parsed: YAML.load(testributor_yml, safe: true) }
      rescue Psych::SyntaxError => e
        { error: e.message }
      end
    end
  end
end
