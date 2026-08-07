# RCodeBar

`code .` on a remote pod opens a local VS Code window on that exact path — no
pre-attached session, no unwanted `/home/jovyan` window. A menu bar app on
the Mac owns the channel and shows per-host tunnel status.

## How it works

- `code` on the pod (`shell/code`, patched cold path only) tries the hot
  path first (an already-live VS Code IPC socket) exactly as before.
- If there's no live window, it now tries a TCP send to
  `127.0.0.1:47000` — the port end of an ssh `RemoteForward` back to the Mac.
  It sends one line, `vscode://vscode-remote/ssh-remote+{host}{abs-path}\n`,
  and reads one line back.
  - `OK` → RCodeBar opened the window on the Mac. Exit quietly.
  - Anything else, including a failed connect (no forward, app not running)
    → fall back to the original clickable `vscode://` link. The fallback is
    never removed; the channel is always best-effort.
- RCodeBar (the Mac app) listens on `127.0.0.1:47000`, bound to loopback
  only. It checks the request is prefixed
  `vscode://vscode-remote/ssh-remote+`, extracts the host, checks it against
  the hosts you've added in the popover, and only then calls
  `NSWorkspace.open` — never on an unrecognized prefix or an unregistered
  host.
- Multiple hosts share the one port: the host lives inside the URI, so
  adding a host is just one more `RemoteForward 47000 127.0.0.1:47000` line
  in that host's ssh config, plus adding the alias in the RCodeBar popover.

## Install

```
./install.sh <host-alias>   # default alias: ldev
```

This builds the app (`swift build -c release`), packages it as
`~/Applications/RCodeBar.app` (ad-hoc signed, hardened runtime, no sandbox —
it needs to spawn `ssh` and open URLs), and prints the ssh config snippet
for `<host-alias>`. It never edits your ssh config for you.

1. Launch the app: `open ~/Applications/RCodeBar.app`.
2. Add `<host-alias>` from the popover ("Add" field).
3. Add the printed `RemoteForward 47000 127.0.0.1:47000` line to that host's
   `Host` block in your ssh config (e.g. under `~/.ssh/config.d/`).
4. Drop the existing ControlMaster so the new forward takes effect:
   `ssh -O exit <host-alias>`. Reconnect (any new ssh session, or just run
   `code .` on the pod) to pick up the forward.
5. Ship the patched pod-side script (`shell/code` in this repo) into your
   dotfiles yourself, replacing the pod's `code` command. This repo does
   not touch `~/.local/share/chezmoi` or `~/.ssh` — that roll-in is a
   separate step you do.
6. Optionally turn on "Start at Login" in the popover.

## Adding another host

Same shape every time: add a `RemoteForward 47000 127.0.0.1:47000` line to
that host's ssh config block, add the alias in the popover ("Copy ssh
config snippet" gives you the line for any registered host), drop its
ControlMaster once. No new port, no app changes.

## Diagnosing a failure

The popover shows one row per host with a status dot, refreshed every 30s
and whenever you open the menu:

- 🟢 green — tunnel is up end to end (`ssh` to the host can reach
  `127.0.0.1:47000` there).
- 🟡 amber — ssh to the host works, but the RemoteForward isn't there. Check
  the host's ssh config block for the `RemoteForward` line and that a
  fresh session (post `ssh -O exit`) picked it up.
- ⚪️ grey — ssh itself can't reach the host (network/host down/auth).

If `code .` on the pod prints the clickable link instead of silently
opening a window:

1. Check RCodeBar is running and "Auto-open" is on (it also owns
   start/stop of the listener — the toggle is the switch).
2. Check the host's row is green in the popover.
3. On the pod, confirm `~/.rcode.host` has the right alias (the ssh `Host`
   you connect with **from the Mac**, not the pod's own hostname).
4. If the channel send times out or connection-refuses, that's expected —
   the printed link is the always-available fallback, not a bug.

## Tests

```
swift test                    # unit: URI parsing, host whitelist, 4 KiB cap
scripts/e2e_test.sh <host>    # end-to-end against a running listener
```

`e2e_test.sh` requires RCodeBar running with `<host>` already added, and
sends both a valid request (expects `OK`, and VS Code should open) and a
request for a bogus host (expects `ERR unknown host`).
