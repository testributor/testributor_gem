module Testributor
  BASH_FUNCTIONS = <<-FUNCTIONS
  # Calls "git diff" between the specified commits and checks if the changed files
  # include the string passed as an argument. If not both commits are set it means
  # we should consider all files as changed so we return true (e.g. when setting
  # up workers we don't have a previous commit)
  function changed_file_paths_match {
    if [[ -n "$CURRENT_COMMIT" && -n "$PREVIOUS_COMMIT" ]]
    then
      test -n "$(git diff --name-only $CURRENT_COMMIT $PREVIOUS_COMMIT | grep $1)"
    else
      true
    fi
  }

  function commit_changed {
    if [[ -n "$CURRENT_COMMIT" && -n "$PREVIOUS_COMMIT" ]]
    then
      $CURRENT_COMMIT != $PREVIOUS_COMMIT
    else
      true
    fi
  }
  FUNCTIONS
end
