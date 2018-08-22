cite about-plugin
about-plugin 'load pyenv, if you are using it'

export PYENV_ROOT="$HOME/.pyenv"
pathmunge "$PYENV_ROOT/bin"

[[ `which pyenv` ]] && eval "$(pyenv init -)"

#Load pyenv virtualenv if the virtualenv plugin is installed.
if pyenv virtualenv-init - &> /dev/null; then
  eval "$(pyenv virtualenv-init -)"
fi

function mkpvenv {
  about 'create a new virtualenv for this directory'
  group 'pyenv-virtualenv'

  cwd=`basename \`pwd\``
  eval "touch .env"
  eval "echo \"#!/bin/bash\" >> .env"
  eval "echo \"if [ \\\`basename \\\$(pwd)\\\` == \\\"$cwd\\\" ]; then \"eval \"wopvenv\"\"; fi\" >> .env"
  mkvirtualenv --distribute $cwd
}

function mkpvbranch {
  about 'create a new virtualenv for the current branch'
  group 'pyenv-virtualenv'

  mkvirtualenv --distribute "$(basename `pwd`)@$SCM_BRANCH"
}

function wopvbranch {
  about 'sets workon branch'
  group 'pyenv-virtualenv'

  workon "$(basename `pwd`)@$SCM_BRANCH"
}

function wopvenv {
  about 'works on the virtualenv for this directory'
  group 'virtualenv'

  workon "$(basename `pwd`)"
}

function rmpvenv {
  about 'removes virtualenv for this directory'
  group 'virtualenv'

  eval "deactivate"
  rmvirtualenv "$(basename `pwd`)"
  eval "rm .env"
}

function rmpvenvbranch {
  about 'removes virtualenv for this directory'
  group 'virtualenv'

  eval "deactivate"
  rmvirtualenv "$(basename `pwd`)@$SCM_BRANCH"
}

# Load the auto-completion script if pyenv was loaded.
[[ -e $PYENV_ROOT/completions/pyenv.bash ]] && source $PYENV_ROOT/completions/pyenv.bash
