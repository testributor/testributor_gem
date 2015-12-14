module Testributor
  # This class wraps the current project response. It is responsible for
  # the git repository setup.
  class Project
    DIRECTORY = ENV["HOME"] + '/.testributor'
    # Should match the one on testributor project files
    BUILD_COMMANDS_PATH = 'testributor_build_commands.sh'

    attr_reader :repo_owner, :repo_name, :github_access_token, :repo,
      :overridden_files

    def initialize(current_project_response)
      set_force_ruby_version_if_needed(current_project_response["docker_image"])

      @repo_owner = current_project_response["repository_owner"]
      @repo_name = current_project_response["repository_name"]
      @github_access_token = current_project_response["github_access_token"]
      @overridden_files = current_project_response["files"]
      create_project_directory
      fetch_project_repo
      # Setup the environment because TestJob#run will not setup the
      # project if the commit is the current commit.
      setup_test_environment
      @repo = Rugged::Repository.new(DIRECTORY)
    end

    # Perfoms any actions needed to prepare the projects directory for a
    # job on a the specified commit
    def prepare_for_commit(commit_sha)
      fetch_project_repo if !repo.exists?(commit_sha)

      current_commit = current_commit_sha[0..5]
      if current_commit != commit_sha[0..5] # commit changed
        log "Current commit ##{current_commit} does not match ##{commit_sha[0..5]}"
        log "Setting up environment"
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
      Dir.chdir(DIRECTORY) do
        Testributor.command("git init")
        Testributor.command("git fetch https://#{github_access_token}@github.com/#{repo_owner}/#{repo_name}.git +refs/heads/*:refs/remotes/*")
      end
    end

    # TODO: Handle the following case gracefully:
    # Testributor::Worker#run has already fetched the repo if the commit is not known.
    # Still, there might be a case that the commit cannot be found even after
    # pulling the repo. E.g. The history was rewritten somehow (do the commits
    # get lost then?) or the repo has been reset (deleted and repushed). This is
    # an edge case but our worker should probably inform katana about this (so
    # katana can notify the users).
    def setup_test_environment(commit_sha=nil)
      log "Setting up environment"
      Dir.chdir(DIRECTORY) do
        # reset hard to the specified commit (or simply HEAD if no commit is
        # specified) and drop any changes.
        # TODO: remove old project if any
        Testributor.command("git reset --hard #{commit_sha}")
        Testributor.command("git clean -df")
        overridden_files.each do |file|
          log "Creating #{file["path"]}"
          dirname = File.dirname(file["path"])
          unless File.directory?(dirname)
            FileUtils.mkdir_p(dirname)
          end
          File.write(file["path"], file["contents"])
        end

        # TODO: Store the result of this command and put is in the reporter's
        # list to be sent.
        log "Running build commands:"
        if File.exists?(BUILD_COMMANDS_PATH)
          log File.read(BUILD_COMMANDS_PATH)
          Testributor.command("/bin/bash #{BUILD_COMMANDS_PATH}")
        end
      end
    end

    def log(message)
      Testributor.log(message)
    end
  end
end
