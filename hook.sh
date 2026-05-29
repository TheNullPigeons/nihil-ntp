# nihil-ntp shell hook - applies (or clears) the DC time offset for THIS shell.
# Sourced at shell startup, and re-sourced by the nihil-ntp() wrapper so a set /
# enable / disable takes effect immediately in the current terminal.
# Safe to source when nihil-ntp is unconfigured.

_nihil_ntp_apply() {
    local conf="${NIHIL_NTP_CONF:-/etc/nihil-ntp.conf}"
    local enabled=0 mode="" off="" lib=""

    if [ -f "$conf" ]; then
        # shellcheck disable=SC1090
        . "$conf" 2>/dev/null
        enabled="${NIHIL_NTP_ENABLED:-0}"
        mode="${NIHIL_NTP_MODE:-}"
        off="${NIHIL_NTP_FAKETIME_OFFSET:-}"
        lib="${NIHIL_NTP_FAKETIME_LIB:-}"
    fi

    if [ "$enabled" = "1" ] && [ "$mode" = "faketime" ] && \
       [ -n "$off" ] && [ -n "$lib" ] && [ -e "$lib" ]; then
        # Apply: preload libfaketime with the stored offset.
        export FAKETIME="$off"
        export FAKETIME_NO_CACHE=1
        case ":${LD_PRELOAD:-}:" in
            *":${lib}:"*) ;;
            *) export LD_PRELOAD="${lib}${LD_PRELOAD:+:$LD_PRELOAD}" ;;
        esac
    else
        # Clear: drop any libfaketime entry we (or `faketime`) put in LD_PRELOAD.
        unset FAKETIME FAKETIME_NO_CACHE
        case ":${LD_PRELOAD:-}:" in
            *faketime*)
                LD_PRELOAD="$(printf '%s' "$LD_PRELOAD" | tr ':' '\n' | grep -v faketime | paste -sd: -)"
                [ -z "$LD_PRELOAD" ] && unset LD_PRELOAD || export LD_PRELOAD
                ;;
        esac
    fi
}

_nihil_ntp_apply

# Refresh in the background (throttled inside nihil-ntp), without blocking the
# prompt or printing job-control noise.
if command -v nihil-ntp >/dev/null 2>&1; then
    ( nihil-ntp _maybe_refresh >/dev/null 2>&1 & ) 2>/dev/null
fi
