# geometry_git - please see the readme for documentation on all features

(( $+commands[git] )) || return

_stashes() {
  git rev-parse --quiet --verify refs/stash >/dev/null \
    && ansi $GEOMETRY_GIT_COLOR_STASHES $GEOMETRY_GIT_SYMBOL_STASHES
}

_time() {
  local last_commit=$(git log -1 --pretty=format:'%at' 2> /dev/null)
  [[ -z "$last_commit" ]] && ansi $GEOMETRY_COLOR_NO_TIME $GEOMETRY_GIT_NO_COMMITS_MESSAGE && return

  now=$(date +%s)
  seconds_since_last_commit=$((now - last_commit))
  geometry::time $seconds_since_last_commit $GEOMETRY_GIT_TIME_DETAILED
}

_branch() {
  ansi $GEOMETRY_GIT_COLOR_BRANCH $(git symbolic-ref --short HEAD || git rev-parse --short HEAD)
}

_status() {
  _status=$([[ -z "$(git status --porcelain --ignore-submodules HEAD)" ]] && [[ -z "$(git ls-files --others --modified --exclude-standard)" ]] && echo CLEAN || echo DIRTY)
  ansi ${(e):-\$GEOMETRY_GIT_COLOR_${_status}} ${(e):-\$GEOMETRY_GIT_SYMBOL_${_status}}
}

_rebase() {
  git_dir=$(git rev-parse --git-dir)
  [[ -d "$git_dir/rebase-merge" ]] || [[ -d "$git_dir/rebase-apply" ]] || return
  echo "$GEOMETRY_GIT_SYMBOL_REBASE"
}

_remote() {
  local_commit=$(git rev-parse "@" 2>/dev/null)
  remote_commit=$(git rev-parse "@{u}" 2>/dev/null)

  [[ $local_commit == "@" || $local_commit == $remote_commit ]] && return

  common_base=$(git merge-base "@" "@{u}" 2>/dev/null) # last common commit
  [[ $common_base == $remote_commit ]] && echo $GEOMETRY_GIT_SYMBOL_UNPUSHED && return
  [[ $common_base == $local_commit ]]  && echo $GEOMETRY_GIT_SYMBOL_UNPULLED && return

  echo "$GEOMETRY_GIT_SYMBOL_UNPUSHED $GEOMETRY_GIT_SYMBOL_UNPULLED"
}

_symbol() { echo ${(j: :):-$(_rebase) $(_remote)} }

_conflicts() {
  conflicts=$(git diff --name-only --diff-filter=U)

  [[ -n "$conflicts" ]] && return

  pushd -q $(git rev-parse --show-toplevel)

  local _grep="grep"
  (($+commands[ag])) && _grep="ag"
  (($+commands[rg])) && _grep="rg"

  conflict_list=$(${GEOMETRY_GIT_GREP:-$_grep} -cH '^=======$' $conflicts)
  popd -q

  raw_file_count="${#${(@f)conflict_list}}"
  file_count=${raw_file_count##*( )}

  raw_total=$(echo $conflict_list | cut -d ':' -f2 | paste -sd+ - | bc)
  total=${raw_total##*(  )}

  [[ -z "$total" ]] && ansi $GEOMETRY_GIT_COLOR_CONFLICTS_SOLVED $GEOMETRY_GIT_SYMBOL_CONFLICTS_SOLVED && return

  ansi $GEOMETRY_GIT_COLOR_CONFLICTS_UNSOLVED "$GEOMETRY_GIT_SYMBOL_CONFLICTS_UNSOLVED (${file_count}f|${total}c)"
}

geometry_git() {
  command git rev-parse --git-dir > /dev/null 2>&1 || return

  : ${GEOMETRY_GIT_SEPARATOR:="::"}

  # Color definitions
  : ${GEOMETRY_GIT_COLOR_DIRTY:=red}
  : ${GEOMETRY_GIT_COLOR_CLEAN:=green}
  : ${GEOMETRY_GIT_COLOR_BARE:=blue}
  : ${GEOMETRY_GIT_COLOR_CONFLICTS_UNSOLVED:=red}
  : ${GEOMETRY_GIT_COLOR_CONFLICTS_SOLVED:=green}
  : ${GEOMETRY_GIT_COLOR_BRANCH:=242}
  : ${GEOMETRY_GIT_COLOR_STASHES:="144"}

  # Symbol definitions
  : ${GEOMETRY_GIT_SYMBOL_DIRTY:="⬡"}
  : ${GEOMETRY_GIT_SYMBOL_CLEAN:="⬢"}
  : ${GEOMETRY_GIT_SYMBOL_BARE:="⬢"}
  : ${GEOMETRY_GIT_SYMBOL_REBASE:="®"}
  : ${GEOMETRY_GIT_SYMBOL_UNPUSHED:="⇡"}
  : ${GEOMETRY_GIT_SYMBOL_UNPULLED:="⇣"}
  : ${GEOMETRY_GIT_SYMBOL_CONFLICTS_SOLVED:="◆"}
  : ${GEOMETRY_GIT_SYMBOL_CONFLICTS_UNSOLVED:="◈"}
  : ${GEOMETRY_GIT_SYMBOL_STASHES:="●"}

  # Flags
  : ${GEOMETRY_GIT_SHOW_CONFLICTS:=false}
  : ${GEOMETRY_GIT_SHOW_TIME:=true}
  : ${GEOMETRY_GIT_TIME_DETAILED:=false}
  : ${GEOMETRY_GIT_SHOW_STASHES:=true}

  # Misc configurations
  : ${GEOMETRY_GIT_NO_COMMITS_MESSAGE:="no commits"}

  $(command git rev-parse --is-bare-repository 2>/dev/null) \
    && ansi $GEOMETRY_GIT_COLOR_BARE $GEOMETRY_GIT_SYMBOL_BARE \
    && return

  echo -n $(_symbol) $(_branch) ${(pj.$GEOMETRY_GIT_SEPARATOR.)$(print -r \
    ${${(M)GEOMETRY_GIT_SHOW_CONFLICTS:#true}:+$(_conflicts)} \
    ${${(M)GEOMETRY_GIT_SHOW_TIME:#true}:+$(_time)} \
    ${${(M)GEOMETRY_GIT_SHOW_STASHES:#true}:+$(_stashes)} \
    $(_status) \
  )}
}
