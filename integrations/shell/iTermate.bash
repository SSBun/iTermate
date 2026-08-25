[[ $- == *i* ]] || return
[[ -n ${_ITERMATE_BASH_STATUS_LOADED:-} ]] && return

_ITERMATE_BASH_STATUS_LOADED=1
_ITERMATE_STATUS_REPORTER="$HOME/Library/Application Support/iTermate/integrations/iTermate-status.py"
_ITERMATE_STATUS_TTY=$(/usr/bin/tty 2>/dev/null)
[[ $_ITERMATE_STATUS_TTY == /dev/tty?* ]] || return
_ITERMATE_STATUS_REPORTER_ID=$(/usr/bin/uuidgen)
_ITERMATE_STATUS_SEQUENCE=0
_ITERMATE_STATUS_COMMAND_ACTIVE=0
_ITERMATE_STATUS_AT_PROMPT=0
_ITERMATE_STATUS_IN_PROMPT=1

_itermate_status_report() {
    _ITERMATE_STATUS_SEQUENCE=$((_ITERMATE_STATUS_SEQUENCE + 1))
    command "$_ITERMATE_STATUS_REPORTER" shell "$1" \
        "$_ITERMATE_STATUS_TTY" "$_ITERMATE_STATUS_REPORTER_ID" \
        "$_ITERMATE_STATUS_SEQUENCE" "${2:--}" \
        </dev/null >/dev/null 2>&1 &
    disown "$!" 2>/dev/null || true
}

_itermate_status_capture_debug_status() {
    _ITERMATE_STATUS_LAST_EXIT=$1
    return "$1"
}

_itermate_status_debug_trap() {
    local trap_status=$1
    if [[ $_ITERMATE_STATUS_IN_PROMPT -eq 0 && $_ITERMATE_STATUS_AT_PROMPT -eq 1 ]]; then
        _ITERMATE_STATUS_AT_PROMPT=0
        _ITERMATE_STATUS_COMMAND_ACTIVE=1
        _itermate_status_report running
    fi
    return "$trap_status"
}

_itermate_status_precmd() {
    local exit_status=${_ITERMATE_STATUS_LAST_EXIT:-0}
    _ITERMATE_STATUS_IN_PROMPT=1
    if [[ $_ITERMATE_STATUS_COMMAND_ACTIVE -eq 1 ]]; then
        _ITERMATE_STATUS_COMMAND_ACTIVE=0
        _itermate_status_report finished "$exit_status"
    fi
    return "$exit_status"
}

_itermate_status_prompt_ready() {
    _ITERMATE_STATUS_AT_PROMPT=1
    _ITERMATE_STATUS_IN_PROMPT=0
}

_ITERMATE_STATUS_ORIGINAL_DEBUG_SPEC=$(trap -p DEBUG)
_ITERMATE_STATUS_ORIGINAL_DEBUG_TRAP=
if [[ -n $_ITERMATE_STATUS_ORIGINAL_DEBUG_SPEC ]]; then
    _ITERMATE_STATUS_DEBUG_WORD=${_ITERMATE_STATUS_ORIGINAL_DEBUG_SPEC#trap -- }
    _ITERMATE_STATUS_DEBUG_WORD=${_ITERMATE_STATUS_DEBUG_WORD% DEBUG}
    eval "_ITERMATE_STATUS_ORIGINAL_DEBUG_TRAP=$_ITERMATE_STATUS_DEBUG_WORD"
fi

if [[ -n $_ITERMATE_STATUS_ORIGINAL_DEBUG_TRAP ]]; then
    trap "_itermate_status_capture_debug_status \"\$?\"; $_ITERMATE_STATUS_ORIGINAL_DEBUG_TRAP; _itermate_status_debug_trap \"\$?\"" DEBUG
else
    trap '_itermate_status_capture_debug_status "$?"; _itermate_status_debug_trap 0' DEBUG
fi

if (( BASH_VERSINFO[0] >= 5 )) \
    && [[ $(declare -p PROMPT_COMMAND 2>/dev/null) == "declare -a"* ]]; then
    _ITERMATE_STATUS_ORIGINAL_PROMPT_COMMAND=("${PROMPT_COMMAND[@]}")
    PROMPT_COMMAND=(
        _itermate_status_precmd
        "${_ITERMATE_STATUS_ORIGINAL_PROMPT_COMMAND[@]}"
        _itermate_status_prompt_ready
    )
else
    _ITERMATE_STATUS_ORIGINAL_PROMPT_COMMAND=${PROMPT_COMMAND-}
    PROMPT_COMMAND='_itermate_status_precmd;'
    if [[ -n $_ITERMATE_STATUS_ORIGINAL_PROMPT_COMMAND ]]; then
        PROMPT_COMMAND+="$_ITERMATE_STATUS_ORIGINAL_PROMPT_COMMAND;"
    fi
    PROMPT_COMMAND+='_itermate_status_prompt_ready'
fi
_itermate_status_report detached
