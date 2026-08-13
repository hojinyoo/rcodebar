# RCodeBar

`code .` on a remote host opens a local VS Code window on that exact path — no
pre-attached session, no unwanted home-directory window. A menu bar app on
the Mac owns the channel and shows per-host tunnel status.

## Requirements

- macOS 14 or later (`LSMinimumSystemVersion` 14.0, `Package.swift` targets
  `.macOS(.v14)`).
- A Swift toolchain on the Mac — Xcode or the Command Line Tools; `install.sh`
  runs `swift build -c release`.
- VS Code on the Mac with the Remote - SSH extension. RCodeBar only hands
  `vscode://vscode-remote/ssh-remote+…` URIs to `NSWorkspace.open`; VS Code
  does the connecting.
- ssh access to the remote from the Mac under a `Host` alias, and `bash`
  there (both `shell/code` and the status probe use bash's `/dev/tcp`).

## How it works

- `code` on the remote (`shell/code`, patched cold path only) tries the hot
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
- The menu bar icon carries a number: how many hosts are currently green.

## Install

```
./install.sh [host-alias]   # default alias: ldev
```

This builds the app (`swift build -c release`), packages it as
`~/Applications/RCodeBar.app` (ad-hoc signed, hardened runtime, no sandbox —
it needs to spawn `ssh` and open URLs), and prints the ssh config snippet
for the alias. It never edits your ssh config for you.

1. Launch the app: `open ~/Applications/RCodeBar.app`.
2. Add the host with the **+** button next to **Hosts** — the menu is
   populated by parsing `~/.ssh/config` (following `Include`), so real host
   aliases are a selection, not typing. "Type manually…" is the fallback for
   anything the parser misses; when there's nothing left to discover, **+**
   goes straight to the manual field.
3. Click the host's row to expand it — it tells you whether the
   RemoteForward is already there. If not, "Add RemoteForward…" shows the
   exact file it would create (`~/.ssh/config.d/rcodebar-<alias>`) and writes
   it only after you confirm; it never edits an existing file. Or add the
   `RemoteForward 47000 127.0.0.1:47000` line yourself.
   - That file only takes effect if `~/.ssh/config` actually pulls in
     `config.d` (`Include ~/.ssh/config.d/*`). Nothing here adds that
     `Include` for you — if the row still says "RemoteForward missing" right
     after a successful write, that's why.
4. Drop the existing ControlMaster so the new forward takes effect:
   `ssh -O exit <host-alias>`. Reconnect (any new ssh session, or just run
   `code .` on the remote) to pick up the forward.
5. Ship the patched remote-side script (`shell/code` in this repo) into your
   dotfiles yourself, replacing the remote's `code` command, and put the
   Mac-side alias in the remote's `~/.rcode.host` (or `$RCODE_HOST`). This
   repo does not touch your dotfiles or `~/.ssh` — that roll-in is a
   separate step you do.
6. Optionally turn on "Start at Login" at the bottom of the popover. macOS
   owns that list: verify (or revoke) it in System Settings › General ›
   Login Items.

## Adding another host

Same shape every time: pick the alias from **+** (or type it), confirm the
RemoteForward write from the expanded row (or add the
`RemoteForward 47000 127.0.0.1:47000` line yourself), drop its ControlMaster
once. No new port, no app changes.

## Per-host row details

The collapsed row shows the display name, the last path opened and how long
ago, and a status icon — distinct shape per status, not just hue. Hover it
for the full alias and the absolute open time. Right-click gives "Test Now",
"Copy RemoteForward Snippet" and "Remove Host…" without expanding.

Clicking the row expands it:

- **Display name** — cosmetic only, defaults to the alias. Edits commit as
  you type, so closing the popover can't drop them.
- **Default path** + **Open** — opens that path on that host directly from
  the Mac, without going through the remote at all. Handy for testing.
- **Allow auto-open** — off means the listener rejects that host exactly
  like an unknown one (`ERR unknown host`) and the row reads "Disabled";
  it's still in your list, just inert.
- **Tunnel** — the status again with its label, plus **Test Now**, which
  runs the probe immediately instead of waiting for the 30s cycle. When the
  result isn't green, the last few lines of ssh's stderr are shown under it
  (selectable, so you can copy them).
- **RemoteForward** — asks `ssh -G <host>` (which resolves `Include` and
  patterns the same way ssh itself does) whether the forward for our port is
  present. If it's missing you get "Add RemoteForward…" and "Copy Snippet".
- **Remove Host…** — confirms first, and only forgets RCodeBar's own state
  for the host. Your ssh config is left alone, including any
  `rcodebar-<alias>` file the app wrote.

## Diagnosing a failure

Statuses are refreshed every 30s and whenever you open the popover:

- ✅ **Connected** — tunnel is up end to end (`ssh` to the host can reach
  `127.0.0.1:47000` there).
- ⚠️ **RemoteForward missing** — ssh to the host works, but the probe
  couldn't reach the port there. Check the host's ssh config block for the
  `RemoteForward` line and that a fresh session (post `ssh -O exit`) picked
  it up. The probe needs bash on the remote side (`/dev/tcp` is a bash
  feature, zsh has no equivalent), so a non-bash login shell reads as this
  too.
- ❌ **No connection** — ssh itself can't reach the host (network/host
  down/auth).
- ○ **Checking…** — not probed yet.

If `code .` on the remote prints the clickable link instead of silently
opening a window:

1. Check RCodeBar is running and "Auto-open remote windows" is on — that
   toggle owns start/stop of the listener, and the line under it should read
   "Listening on 127.0.0.1:47000".
2. Check the host's row is Connected, and that **Allow auto-open** is on for
   it.
3. On the remote, confirm `~/.rcode.host` has the right alias (the ssh `Host`
   you connect with **from the Mac**, not the remote's own hostname).
4. If the channel send times out or connection-refuses, that's expected —
   the printed link is the always-available fallback, not a bug.

## Tests

```
swift test                    # unit: URI parsing, host whitelist, 4 KiB cap,
                               # ssh config discovery, RemoteForward detection
scripts/e2e_test.sh <host>    # end-to-end against a running listener
```

`e2e_test.sh` requires RCodeBar running with `<host>` already added, and
sends both a valid request (expects `OK`, and VS Code should open) and a
request for a bogus host (expects `ERR unknown host`).

## Developing

`./install.sh` replaces the app you're using. To poke at a dev build while
the installed one keeps the port:

```
defaults write RCodeBar autoOpenEnabled -bool false   # once, before first run
swift build && .build/debug/RCodeBar
defaults delete RCodeBar                              # cleanup
```

The unbundled SwiftPM binary has no bundle id, so it reads the UserDefaults
domain `RCodeBar` while the packaged app reads `dev.rcodebar.RCodeBar` —
separate host lists, and the `defaults write` above keeps the dev instance
from binding 47000. A launch argument won't do: `-autoOpenEnabled 0` lands in
the argument domain as a string and the `Bool` read falls back to `true`.
Don't flip the Auto-open switch in the dev popover — that starts its listener
and you're back to two apps fighting for the port.

## Uninstall

1. Turn "Start at Login" off in the popover (or remove RCodeBar in System
   Settings › General › Login Items), then Quit.
2. `rm -rf ~/Applications/RCodeBar.app`
3. `defaults delete dev.rcodebar.RCodeBar` — hosts, display names, default
   paths and the auto-open switch are all UserDefaults under that domain;
   there is no config file.
4. Optional: `rm ~/.ssh/config.d/rcodebar-*` for any snippet the app wrote,
   and drop the remote's `~/.rcode.host` and patched `code` script. Removing
   the app does none of this for you.
