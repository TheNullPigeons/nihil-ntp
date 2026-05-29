# nihil-ntp

Sync the container clock to a target NTP server, typically the Domain
Controller, so Kerberos stops rejecting tickets for clock skew. Once a server
is set, every terminal opened in the container uses it.

## Usage

```bash
nihil-ntp 10.10.10.1          # set the DC as NTP source and enable (syncs now)
nihil-ntp --clock 10.10.10.1  # same, but set the real system clock
nihil-ntp status              # show state and the live offset to the server
nihil-ntp disable             # stop syncing
nihil-ntp enable              # re-enable with the stored server
nihil-ntp sync                # force a sync now
```

Setting an IP enables syncing by default.

## How it works

Two modes:

- **faketime (default)** - never touches the real clock. `nihil-ntp` measures
  the offset to the server with an NTP query (no privilege needed) and applies
  it through `libfaketime` (`LD_PRELOAD`) in each shell, so every command sees
  DC time. Safe everywhere, but only shifts dynamically-linked libc programs
  (Python tooling like impacket / netexec / certipy), **not** static or Go
  binaries.
- **clock (`--clock`)** - sets the real system clock with `ntpdate`/`sntp`.
  Needs a privileged container (`CAP_SYS_TIME`) and covers every tool, but in
  Docker the clock is shared with the host. It is verified by re-measuring the
  offset (ntpdate exits 0 even when it could not step the clock); if it did not
  actually move, nihil-ntp falls back to faketime.

State lives in `/etc/nihil-ntp.conf` (override with `NIHIL_NTP_CONF`). A shell
hook (`hook.sh`, installed under `/opt/nihil/config/nihil-ntp/`) is sourced by
every interactive shell: it applies the offset and refreshes it in the
background when stale.

## Notes

- A shell function wrapper (installed in the shell rc) re-applies the offset to
  the current shell right after `nihil-ntp <ip>` / `enable` / `disable`, so the
  change is immediate, no new terminal needed. Other already-open terminals pick
  it up on their next nihil-ntp command or when restarted.
- Requires the `ntp` package (provides `ntpdate`/`sntp`) and `libfaketime`.
  Both ship in the nihil base image.
