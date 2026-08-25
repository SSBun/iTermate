[[ -o interactive ]] || return
[[ -n ${_ITERMATE_ZSH_STATUS_LOADED:-} ]] && return

typeset -g _ITERMATE_ZSH_STATUS_LOADED=1
typeset -g _ITERMATE_STATUS_REPORTER="$HOME/Library/Application Support/iTermate/integrations/iTermate-status.py"
typeset -g _ITERMATE_STATUS_TTY="$(/usr/bin/tty 2>/dev/null)"
[[ $_ITERMATE_STATUS_TTY == /dev/tty?* ]] || return
typeset -g _ITERMATE_STATUS_REPORTER_ID="$(/usr/bin/uuidgen)"
typeset -gi _ITERMATE_STATUS_SEQUENCE=0
typeset -gi _ITERMATE_STATUS_COMMAND_ACTIVE=0

_itermate_status_report() {
    (( _ITERMATE_STATUS_SEQUENCE += 1 ))
    command "$_ITERMATE_STATUS_REPORTER" shell "$1" \
        "$_ITERMATE_STATUS_TTY" "$_ITERMATE_STATUS_REPORTER_ID" \
        "$_ITERMATE_STATUS_SEQUENCE" "${2:--}" \
        </dev/null >/dev/null 2>&1 &!
}

_itermate_status_preexec() {
    _ITERMATE_STATUS_COMMAND_ACTIVE=1
    _itermate_status_report running
}

_itermate_status_precmd() {
    local exit_status="$?"
    (( _ITERMATE_STATUS_COMMAND_ACTIVE )) || return
    _ITERMATE_STATUS_COMMAND_ACTIVE=0
    _itermate_status_report finished "$exit_status"
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _itermate_status_preexec
add-zsh-hook precmd _itermate_status_precmd
_itermate_status_report detached
