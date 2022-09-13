#
# ${DEVENV_PREFIX}/etc/bash.bashrc
#

# TODO: use PREFIX instead of DEVENV_PREFIX, need to handle other containers
# TODO: this should also work as a generic non-devenv template for user bashrc
################################################################################
##############################     Term init      ##############################
################################################################################

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# TODO: drop this
set_devenv_prefix_dynamic(){
  # BASH_SOURCE is actually an array
  local bash_source_path="$(realpath "${BASH_SOURCE}")"
  #local bash_source_basedir="$(dirname "${bash_source_path}")"
  local process_path="$(realpath "${0}")"
  #local process_basedir="$(dirname "${process_path}")"
  local devenv_libsdk=/usr/lib/sdk/devenv
  local devenv_varlib=/var/lib/devenv

  # ${DEVENV_PREFIX}/etc/bash.bashrc
  if [ -r "${bash_source_path}" ] &&
    [ -d "${bash_source_path%/*/*}/etc/bash.bashrc" ]; then
    DEVENV_PREFIX="${bash_source_path%/*/*}"
  # ${DEVENV_PREFIX}/bin/bash
  elif [ -r "${process_path}" ] &&
    [ -d "${process_path%/*/*}/bin/bash" ]; then
    DEVENV_PREFIX="${process_path%/*/*}"
  # TODO: test who's newer? should be moved then to top
  elif [ -r "${devenv_varlib}/etc/bash.bashrc" ]; then
    DEVENV_PREFIX="${devenv_varlib}"
  else
    DEVENV_PREFIX="${devenv_libsdk}"
  fi
}
#set_devenv_prefix_dynamic

set_devenv_prefix(){
  local devenv_libsdk=/usr/lib/sdk/devenv
  local devenv_varlib=/var/lib/devenv

  if [ -z "${DEVENV_PREFIX}" ]; then
    if [ -f "/.flatpak-info" ] &&
      [ -n "${DEVENV_PREFIX_SDK}" ] &&
      [ -f "${devenv_libsdk}/enable.sh" ]; then
      export DEVENV_PREFIX=${devenv_libsdk}
    elif [ -f "${devenv_varlib}/enable.sh" ]; then
      export DEVENV_PREFIX=${devenv_varlib}
    else
      2>&1 echo "ERROR: Cannot detect DEVENV_PREFIX! This should not happen!"
    fi
  fi
}
set_devenv_prefix

shopt -s nullglob extglob

################################################################################
##############################  Local functions  ###############################
################################################################################

local_functions=()

try_source() {
  if [ -r "${1}" ]; then
    source "${1}"
    return 0
  fi
  return 1
}; local_functions+=(try_source)

try_catch_source() {
  try_source "${1}"
  return 0
}; local_functions+=(try_catch_source)

set_complete_alias() {
  declare -F _complete_alias &>/dev/null &&
    defined_complete_alias="yes"

  # alternative
  #[ "$(type _complete_alias)" == "function" ] &&
  #  defined_complete_alias="yes"
  #fi
}; local_functions+=(set_complete_alias)

is_defined_complete_alias() {
  [ "${defined_complete_alias}" = "yes" ] || return 1
  return 0
}; local_functions+=(is_defined_complete_alias)

try_complete_alias() {
  is_defined_complete_alias &&
    complete -F _complete_alias "${1}"
}; local_functions+=(try_complete_alias)

################################################################################
############################   Global functions   ##############################
################################################################################

try_source "${XDG_CONFIG_HOME}"/bash/bash.functions ||
  try_catch_source ~/.bash.functions

try_source "${DEVENV_PREFIX}/enable.sh"

is_flatpak() {
  if [ -f "/.flatpak-info" ]; then
    echo "Yes! Running ${FLATPAK_ID}"
    return 0
  else
    echo "No! Not Running in a Flatpak sandbox"
    return 1
  fi
}

################################################################################
##############################    Extra PATHs    ###############################
################################################################################

if [ -z "${DEVENV_EXTRA_PATHS}" ]; then
  export DEVENV_EXTRA_PATHS=1

  extra_paths=(
    "${HOME}/.local/bin"
    "${XDG_DATA_HOME}/flatpak-run-cli/exports/bin"
  )

  for extra_path in ${extra_paths[@]}; do
    if [[ ":${PATH}:" != *":${extra_path}:"* ]]; then
      PATH+=":${extra_path}"
    fi
  done

  export PATH
fi

################################################################################
##############################        PS1         ##############################
################################################################################

# default PS1
PS1='[\u@\h \W]\$ '

# git PS1
try_source /usr/share/git/completion/git-prompt.sh &&
  PS1='[\u@\h \W$(__git_ps1 " (%s)")]\$ '

# powerline-go
if is_flatpak &>/dev/null; then
  PLGO_EXTRA_OPTIONS='-shell-var FLATPAK_ID'
fi

function _update_ps1() {
  # save return value as a workaround to it being swallowed by pyenv init
  ret=$?
  _cdw_pyenv_root_update
  PS1="$($(exit ${ret}); powerline-go -error $? -jobs $(jobs -p | wc -l) -numeric-exit-codes ${PLGO_EXTRA_OPTIONS} -modules venv,user,shell-var,ssh,cwd,perms,git,jobs,exit,root)"
}

# pyenv shell integration
if which pyenv &>/dev/null; then
  export _PYENV_FOUND=1
  export PYENV_VIRTUALENV_DISABLE_PROMPT=1
fi

_pyenv_init() {
  # pyenv init creates background jobs as it forks the shell instead of using subshell, see pyenv-init: print_path()
  export _PYENV_INIT=1
  eval "$(pyenv init -)"}
  local _pyenv_exec=$(realpath $(which pyenv 2>/dev/null))
  if [ -r "${PYENV_ROOT}"/plugins/pyenv-virtualenv/bin/pyenv-virtualenv ] ||
    [ -r ${_pyenv_exec%/*/*}/plugins/pyenv-virtualenv/bin/pyenv-virtualenv ]; then
    eval "$(pyenv virtualenv-init -)"
  fi
}

_pyenv_update() {
  [ -n "${_PYENV_INIT}" ] || _pyenv_init
  #eval "$(pyenv init --path)"
  # more aggresive PATH update
  IFS=:
  paths=(${PATH})
  for i in ${!paths[@]}; do
    if [[ ${paths[i]} == "${PYENV_ROOT}/shims" ]] ||
      [[ ${paths[i]} == *"pyenv/shims" ]]; then
      unset 'paths[i]'
    fi
  done
  PATH="${paths[*]}"
  unset IFS
  export PATH="${PYENV_ROOT}/shims:${PATH}"

  _pyenv_virtualenv_hook
}

# pyenv auto PYENV_ROOT update
function _cdw_pyenv_root_update() {
  # dynamic PYENV_ROOT updater is opt-in
  if [ -n "${AUTO_PYENV_ROOT}" ] && [ -n "${_PYENV_FOUND}" ]; then
    if [ -d "${PWD}/.pyenv" ]; then
      # only update PYENV_ROOT when different from ${PWD}/.pyenv
      if [ "${PWD}/.pyenv" != "${PYENV_ROOT}" ]; then
        # switching back to global pyenv_root
        if [ "${PWD}/.pyenv" == "${GLOBAL_PYENV_ROOT}" ]; then
          unset PROJECT_PYENV_ROOT
          export PYENV_ROOT="${GLOBAL_PYENV_ROOT}"
          _pyenv_update
        # switching to a different project
        elif [ "${PYENV_ROOT}" == "${PROJECT_PYENV_ROOT}" ] ||
          [ -z "${PYENV_ROOT}" ]; then
          export PROJECT_PYENV_ROOT="${PWD}/.pyenv"
          export PYENV_ROOT="${PROJECT_PYENV_ROOT}"
          _pyenv_update
        # PYENV_ROOT is already set, so save it as global
        elif [ -n "${PYENV_ROOT}" ]; then
          export GLOBAL_PYENV_ROOT="${PYENV_ROOT}"
          export PROJECT_PYENV_ROOT="${PWD}/.pyenv"
          export PYENV_ROOT="${PROJECT_PYENV_ROOT}"
          _pyenv_update
        # project pyenv_root without global one
        else
          export PROJECT_PYENV_ROOT="${PWD}/.pyenv"
          export PYENV_ROOT="${PROJECT_PYENV_ROOT}"
          _pyenv_update
        fi
      fi
    # no .pyenv, need to decide to reset back to global or unset
    else
      # if cwd is not a subfolder of project with .pyenv, then reset PYENV_ROOT
      if [ -n "${PROJECT_PYENV_ROOT}" ] &&
        [[ "${PWD}" != "${PROJECT_PYENV_ROOT%.pyenv}"* ]]; then
        unset PROJECT_PYENV_ROOT
        if [ -n "${GLOBAL_PYENV_ROOT}" ]; then
          export PYENV_ROOT="${GLOBAL_PYENV_ROOT}"
          _pyenv_update
        else
          unset PYENV_ROOT
          _pyenv_update
        fi
      fi
    fi
  fi
}

if [ "${TERM}" != "linux" ] && (which powerline-go &>/dev/null); then
  # workaround 1 for ssh and startup scratchpad issue
  #PROMPT_COMMAND='printf "\033_%s@%s:%s\033\\" "${USER}" "${HOSTNAME%%.*}" "${PWD/#${HOME}/\~}"'
  #PROMPT_COMMAND=''
  # workaround 2 for ssh and startup scratchpad issue
  if [ -z "${PROMPT_COMMAND}" ]; then
    PROMPT_COMMAND="_update_ps1"
  else
    PROMPT_COMMAND="_update_ps1; ${PROMPT_COMMAND}"
  fi
fi

################################################################################
##############################    Completions     ##############################
################################################################################

# TODO: handle both /usr and devenv prefices to support other containers
# bash-completion
try_catch_source ${DEVENV_PREFIX}/share/bash-completion/bash_completion

# bash git completion
try_catch_source ${DEVENV_PREFIX}/share/git/completion/git-completion.bash

# complete-alias
if ! is_defined_complete_alias; then
  try_source ~/.local/apps/bash-complete-alias ||
    try_source ${DEVENV_PREFIX}/share/bash-complete-alias/complete_alias ||
    try_catch_source /usr/share/bash-complete-alias/complete_alias
  set_complete_alias
fi

# TODO: user bash completion folder
#unset user_completion
#[ -d ~/.local/bin/bash-completion ] &&  user_completion=(~/.local/bin/bash-completion/!(*.md))
#for file in "${user_completion[@]}"; do
#  source "${file}"
#done
#unset file user_completion

################################################################################
###############################      Vars       ################################
################################################################################

# editor
which nvim &>/dev/null && export EDITOR=nvim

################################################################################
##############################      Aliases       ##############################
################################################################################

# NOTE: prefer setting aliases in XDG_CONFIG_HOME/bash/bashrc

################################################################################
###########################   XDG dirs workarounds  ############################
################################################################################

# bash
export HISTFILE="${XDG_DATA_HOME}/bash_history"

# gnupg
export GNUPGHOME="${XDG_CONFIG_HOME}/gnupg"

# helix
# TODO: actually handle xdg dir, related: https://github.com/helix-editor/helix/issues/584
export HELIX_RUNTIME="${DEVENV_PREFIX}/share/helix/runtime"

# openssl
export RANDFILE="${XDG_CACHE_HOME}/rnd"

# python-startup
if [ -r "${XDG_CONFIG_HOME}/python/python.startup" ]; then
  export PYTHONSTARTUP="${XDG_CONFIG_HOME}/python/python.startup"
elif [ -r "${HOME}/.config/python/python.startup" ]; then
  export PYTHONSTARTUP="${HOME}/.config/python/python.startup"
elif [ -r "${DEVENV_PREFIX}/etc/python.startup" ]; then
  export PYTHONSTARTUP="${DEVENV_PREFIX}/etc/python.startup"
else
  unset PYTHONSTARTUP
fi

# readline
if [ -r "${XDG_CONFIG_HOME}/readline/inputrc" ]; then
  export INPUTRC="${XDG_CONFIG_HOME}/readline/inputrc"
elif [ -r "${HOME}/.config/readline/inputrc" ]; then
  export INPUTRC="${HOME}/.config/readline/inputrc"
elif [ -r "${DEVENV_PREFIX}/etc/inputrc" ]; then
  export INPUTRC="${DEVENV_PREFIX}/etc/inputrc"
else
  unset INPUTRC
fi

# less
# flatpak workround as less doesn't check .config if XDG_CONFIG_HOME is set
if [ -r "${LESSKEYIN}" ]; then
  :
elif [ -r "${XDG_CONFIG_HOME}/lesskey" ]; then
  unset LESSKEYIN
elif [ -r "${HOME}/.config/lesskey" ]; then
  export LESSKEYIN="${HOME}/.config/less"
else
  unset LESSKEYIN
fi

# svn
alias svn='svn --config-dir "${XDG_CONFIG_HOME}/subversion"'

# wget
alias wget='wget --hsts-file="${XDG_CACHE_HOME}"/wget-hsts'

# zsh
ZDOTDIR="${XDG_CONFIG_HOME}/zsh"

################################################################################
################################     Colors     ################################
################################################################################

# man colors
man() {
    LESS_TERMCAP_md=$'\e[01;31m' \
    LESS_TERMCAP_me=$'\e[0m' \
    LESS_TERMCAP_se=$'\e[0m' \
    LESS_TERMCAP_so=$'\e[01;44;33m' \
    LESS_TERMCAP_ue=$'\e[0m' \
    LESS_TERMCAP_us=$'\e[01;32m' \
    command man "$@"
}

# less colors
export LESS=-R
export LESS_TERMCAP_mb=$'\E[1;31m'     # begin bold
export LESS_TERMCAP_md=$'\E[1;36m'     # begin blink
export LESS_TERMCAP_me=$'\E[0m'        # reset bold/blink
export LESS_TERMCAP_so=$'\E[01;44;33m' # begin reverse video
export LESS_TERMCAP_se=$'\E[0m'        # reset reverse video
export LESS_TERMCAP_us=$'\E[1;32m'     # begin underline
export LESS_TERMCAP_ue=$'\E[0m'        # reset underline
# and so on

# ls colors aliases
_colorized='--color=always'
alias lsLC='ls -al ${_colorized} | less'
alias ls='ls --color=auto'

# colors test
## https://unix.stackexchange.com/questions/41563/how-to-create-a-testcolor-sh-like-the-following-screenshot/213471#213471
alias color='echo -e "\n                 40m     41m     42m     43m     44m     45m     46m     47m"; for FGs in "    m" "   1m" "  30m" "1;30m" "  31m" "1;31m" "  32m" "1;32m" "  33m" "1;33m" "  34m" "1;34m" "  35m" "1;35m" "  36m" "1;36m" "  37m" "1;37m"; do FG=${FGs// /}; echo -en " $FGs \033[$FG  $T  "; for BG in 40m 41m 42m 43m 44m 45m 46m 47m; do echo -en "$EINS \033[$FG\033[$BG  $T  \033[0m"; done; echo; done; echo'

################################################################################
##############################  Extra functions  ###############################
################################################################################

################################################################################
##############################     SSH-Agent     ###############################
################################################################################

################################################################################
#############################  Terminal graphics  ##############################
################################################################################

################################################################################
########################   DevEnv prefix adjustments   #########################
################################################################################

# fish
# TODO: figure out what is not required and drop it
export __fish_data_dir=${DEVENV_PREFIX}/share
export __fish_datadir=${DEVENV_PREFIX}/share
export fish_complete_path=${DEVENV_PREFIX}/share/fish/completions
export fish_function_path=$DEVENV_PREFIX/share/fish/functions

################################################################################
##############################   Local bashrc   ###############################3
################################################################################

try_source "${XDG_CONFIG_HOME}"/bash/bashrc.local ||
  try_catch_source ~/.bashrc.local

################################################################################
###############################    Finalize    #################################
################################################################################

# unset local functions
for f in "${local_functions[@]}"; do
  unset -f "${f}"
done
unset local_functions

# systemd annoyance, always follows /home symlink
if [[ "${PWD}" == "/var/homes/"* ]]; then
  cd ${PWD/#\/var\/homes/\/home}
fi

enter_shell() {
  # using a function to avoid having wrong SHELL value if exec failed
  # no need to export SHELL as shells already do this, seems to be common practice
  local SHELL="${1}"
  exec "${SHELL}"
}

# enter into prefered shell
# TODO: maybe test if original command was bash or enabled devenv
if [ -n "${DEVENV_SHELL}" ] &&
  [ "${DEVENV_SHELL}" != "bash" ] &&
  [ -x "${DEVENV_PREFIX}/bin/${DEVENV_SHELL}" ] &&
  [[ "$(ps --no-header --pid=${PPID} --format=comm)" != "${DEVENV_SHELL}" ]]; then
  enter_shell "${DEVENV_PREFIX}/bin/${DEVENV_SHELL}"
fi
unset enter_shell
