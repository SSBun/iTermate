# Managed by iTermate.
status is-interactive; or return
set -q _ITERMATE_FISH_STATUS_LOADED; and return

set -g _ITERMATE_FISH_STATUS_LOADED 1
set -g _ITERMATE_STATUS_REPORTER "$HOME/Library/Application Support/iTermate/integrations/iTermate-status.py"
set -g _ITERMATE_STATUS_TTY (/usr/bin/tty 2>/dev/null)
string match -qr '^/dev/tty.+' -- "$_ITERMATE_STATUS_TTY"; or return
set -g _ITERMATE_STATUS_REPORTER_ID (/usr/bin/uuidgen)
set -g _ITERMATE_STATUS_SEQUENCE 0

function _itermate_status_report --argument-names state exit_status
    set -g _ITERMATE_STATUS_SEQUENCE (math $_ITERMATE_STATUS_SEQUENCE + 1)
    test -n "$exit_status"; or set exit_status -
    command "$_ITERMATE_STATUS_REPORTER" shell "$state" \
        "$_ITERMATE_STATUS_TTY" "$_ITERMATE_STATUS_REPORTER_ID" \
        "$_ITERMATE_STATUS_SEQUENCE" "$exit_status" \
        </dev/null >/dev/null 2>&1 &
    disown $last_pid 2>/dev/null
end

function _itermate_status_preexec --on-event fish_preexec
    _itermate_status_report running
end

function _itermate_status_postexec --on-event fish_postexec
    set -l exit_status $status
    _itermate_status_report finished $exit_status
end

_itermate_status_report detached
