module Testributor
  BENCHMARK_SETUP_SECONDS = 3
  BENCHMARK_FETCH_PROJECT_SECONDS = 5
  TESTRIBUTOR_FUNCTIONS_COMBINED_BUILD_COMMANDS_PATH = 'testributor_functions.sh'

  # This class wraps the current project response. It is responsible for
  # the git repository setup.
  class Project
    DIRECTORY = ENV["HOME"] + '/.testributor'
    # Should match the one on testributor project files
    BUILD_COMMANDS_PATH = 'testributor_build_commands.sh'
    SSH_DIRECTORY = ENV['HOME'] + '/.ssh'

    attr_reader :repository_ssh_url, :repo, :overridden_files, :ssh_key_private,
      :ssh_key_public

    def initialize(setup_data_response)
      current_project = setup_data_response['current_project']
      current_worker_group = setup_data_response['current_worker_group']
      set_force_ruby_version_if_needed(current_project["docker_image"])

      @repository_ssh_url = current_project["repository_ssh_url"]
      @overridden_files = current_project["files"]
      @ssh_key_private = current_worker_group['ssh_key_private']
      @ssh_key_public = current_worker_group['ssh_key_public']
      create_ssh_keys
      check_ssh_key_validity
      create_project_directory
      fetch_project_repo
      # Setup the environment because TestJob#run will not setup the
      # project if the commit is the current commit.
      setup_test_environment
      @repo = Rugged::Repository.new(DIRECTORY) unless ENV["BENCHMARK_MODE"]
    end

    # Performs any actions needed to prepare the projects directory for a
    # job on a the specified commit
    def prepare_for_commit(commit_sha)
      return if ENV["BENCHMARK_MODE"]

      fetch_project_repo if !repo.exists?(commit_sha)
      current_commit = current_commit_sha
      if current_commit[0..5] != commit_sha[0..5] # commit changed
        log "Current commit ##{current_commit[0..5]} does not match ##{commit_sha[0..5]}"
        setup_test_environment(commit_sha)
      end
    end

    private

    # Sets the Testributor.force_ruby_version to the user's ruby when that ruby
    # is different from the current (in which this gem is run). We use this
    # instance variable to wrap all commands in "rvm ruby_version do" so that
    # user's commands run in the user's ruby, not the one loaded for testributor
    # gem.
    def set_force_ruby_version_if_needed(docker_image)
      if docker_image && docker_image["name"] == 'ruby' &&
        docker_image["version"] != RUBY_VERSION

        Testributor.force_ruby_version = docker_image["version"]
      end
    end

    def current_commit_sha
      Dir.chdir(DIRECTORY) do
        Testributor.command("git rev-parse HEAD", log_output: false)[:output].strip
      end
    end

    def create_project_directory
      unless File.exists?(DIRECTORY)
        log "Creating directory #{DIRECTORY}"
        Dir.mkdir(DIRECTORY)
      end
    end

    def fetch_project_repo
      log "Fetching repo"
      return sleep BENCHMARK_FETCH_PROJECT_SECONDS if ENV["BENCHMARK_MODE"]

      Dir.chdir(DIRECTORY) do
        Testributor.command("git init")
        Testributor.command("git remote add origin #{repository_ssh_url}")
        Testributor.command("git fetch origin")
        # A "random" commit to checkout. This creates the local HEAD so we can
        # hard reset to something in setup_test_environment.
        # TODO: Add a "default_branch" setting on katana and use that here
        ref_to_checkout = Testributor.command(
          "git ls-remote --heads -q | tail -n 1 | awk '{print $1}'",
          log_output: false)[:output]
        Testributor.command("git reset --hard #{ref_to_checkout}")
      end
    end

    # TODO Handle the following case gracefully:
    # Testributor::Worker#run has already fetched the repo if the commit is not known.
    # Still, there might be a case that the commit cannot be found even after
    # pulling the repo. E.g. The history was rewritten somehow (do the commits
    # get lost then?) or the repo has been reset (deleted and repushed). This is
    # an edge case but our worker should probably inform katana about this (so
    # katana can notify the users).
    def setup_test_environment(commit_sha=nil)
      log "Setting up environment"

      return sleep BENCHMARK_SETUP_SECONDS if ENV["BENCHMARK_MODE"]

      Dir.chdir(DIRECTORY) do
        # This stores environment variables we expose in build commands script
        build_commands_variables = {}

        # reset hard to the specified commit (or simply HEAD if no commit is
        # specified) and drop any changes.
        # TODO remove old project if any
        if commit_sha.nil?
          log "Resetting to default branch"
          Testributor.command("git reset --hard")
          build_commands_variables["WORKER_INITIALIZING"] = true
        else
          log "Checking out commit #{commit_sha}"
          build_commands_variables["PREVIOUS_COMMIT_HASH"] = current_commit_sha[0..5]
          build_commands_variables["CURRENT_COMMIT_HASH"] = commit_sha[0..5]
          Testributor.command("git reset --hard #{commit_sha}")
        end
        Testributor.command("git clean -df")

        overridden_files.each do |file|
          log "Creating #{file["path"]}"
          dirname = File.dirname(file["path"])
          unless File.directory?(dirname)
            FileUtils.mkdir_p(dirname)
          end
          File.write(file["path"], file["contents"])
        end

        # TODO Store the result of this command and put it in the reporter's
        # list to be sent.
        log "Running build commands with available variables: #{build_commands_variables}"
        if File.exists?(BUILD_COMMANDS_PATH)
          prepare_bash_functions_and_variables(build_commands_variables)

          Testributor.command(
            "/bin/bash #{TESTRIBUTOR_FUNCTIONS_COMBINED_BUILD_COMMANDS_PATH}")
        end
      end
    end

    def prepare_bash_functions_and_variables(build_commands_variables={})
      variables =
        build_commands_variables.map{ |name, value| "#{name}=#{value}\n" }.join

      build_commands =
        if File.exists?(BUILD_COMMANDS_PATH) 
          commands = File.read(BUILD_COMMANDS_PATH)
          log commands
          commands
        else
          ''
        end

      Dir.chdir(DIRECTORY) do
        File.write(TESTRIBUTOR_FUNCTIONS_COMBINED_BUILD_COMMANDS_PATH,
          "#{variables}" << Testributor::BASH_FUNCTIONS << "\n" << build_commands)
      end
    end

    def log(message)
      Testributor.log(message)
    end

    def create_ssh_keys
      raise Testributor::InvalidSshKeyError if ssh_key_private.nil?

      log 'Creating `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub` files'
      unless File.directory?(SSH_DIRECTORY)
        FileUtils.mkdir_p(SSH_DIRECTORY)
      end
      File.write("#{SSH_DIRECTORY}/id_rsa", ssh_key_private)
      File.write("#{SSH_DIRECTORY}/id_rsa.pub", ssh_key_public)

      log 'Set the appropriate permissions'
      Testributor.command('chmod 700 ~/.ssh')
      Testributor.command('chmod 600 ~/.ssh/id_rsa')
      Testributor.command('chmod 644 ~/.ssh/id_rsa.pub')

      # The following 2 lines are not currently required.
      # Uncomment if the SSH Agent is needed.
      # log 'Add the SSH key to the SSH agent'
      # Testributor.command('ssh-add ~/.ssh/id_rsa')

      # Configure SSH to avoid prompting to add the remote host to the
      # known_hosts file.
      Testributor.command('printf "Host *\n    StrictHostKeyChecking no\n" > ~/.ssh/config')
    end

    def check_ssh_key_validity
      remote_host = repository_ssh_url.split(":").first # e.g. git@github.com
      result = Testributor.command("ssh -T #{remote_host}")

      # SSH exits with the exit status of the remote command or with 255 if an
      # error occurred.
      if result[:exit_code] == 255
        raise Testributor::InvalidSshKeyError
      end
    end
  end
end
