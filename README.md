# RCodeBar

`code .` on a remote host opens a local VS Code window on that exact path — no
pre-attached session, no unwanted home-directory window. A menu bar app on the
Mac owns the channel and shows per-host tunnel status.

## Requirements

- macOS 14 or later.
- A Swift toolchain (Xcode or the Command Line Tools) — only to build from
  source; [Releases](https://github.com/hojinyoo/rcodebar/releases/latest)
  carries a signed, notarized binary.
- VS Code on the Mac with the Remote - SSH extension; it does the connecting.
- ssh access to the remote under a `Host` alias, and `bash` there — both
  `shell/code` and the status probe use bash's `/dev/tcp`.

## How it works

1. `code` on the remote (`shell/code`) first tries the hot path — an
   already-live VS Code IPC socket — exactly as before.
2. With no live window it sends one line to `127.0.0.1:47000`, the remote end
   of an ssh `RemoteForward` back to the Mac:
   `vscode://vscode-remote/ssh-remote+{host}{abs-path}`.
3. RCodeBar replies `OK` once it has opened the window. Anything else — bad
   reply, no forward, app not running — falls back to printing the clickable
   `vscode://` link. That fallback is never removed; the channel is only ever
   an optimization.

The listener is bound to loopback only, and opens a URI only when it carries
the `vscode://vscode-remote/ssh-remote+` prefix **and** names a host you added
in the popover — see [SECURITY.md](SECURITY.md) for the full trust model. Every
host shares the one port, since the host lives inside the URI. The menu bar icon
shows how many are currently connected.

## Install

Prebuilt: download `RCodeBar.zip` from
[Releases](https://github.com/hojinyoo/rcodebar/releases/latest), unzip, and
move `RCodeBar.app` to `/Applications` — Developer ID signed and notarized,
so Gatekeeper opens it without ceremony.

Or build from source:

```
./install.sh [host-alias]   # default alias: myhost
```

Builds, packages `~/Applications/RCodeBar.app` (ad-hoc signed, hardened
runtime, no sandbox — it spawns `ssh` and opens URLs), and prints the ssh
snippet for the alias. It never edits your ssh config.

1. `open ~/Applications/RCodeBar.app`.
2. Add the host with **+** next to **Hosts**. The menu is parsed out of
   `~/.ssh/config` (following `Include`), so aliases are a selection, not
   typing — "Type manually…" covers what the parser misses.
3. Click the row to expand it. If the RemoteForward is missing, "Add
   RemoteForward…" writes `~/.ssh/config.d/rcodebar-<alias>` after you
   confirm — a new file, never an edit into an existing one. Or add
   `RemoteForward 47000 127.0.0.1:47000` to the host's block yourself.
4. `ssh -O exit <host-alias>`, then reconnect, so the existing ControlMaster
   doesn't keep serving the old session without the forward.
5. Ship `shell/code` into your dotfiles as the remote's `code` command, and put
   the Mac-side alias in the remote's `~/.rcode.host` (or `$RCODE_HOST`). This
   repo touches neither your dotfiles nor `~/.ssh`.
6. Optionally turn on "Start at Login" at the bottom of the popover. macOS owns
   that list — verify or revoke it in System Settings › General › Login Items.

> **`config.d` only counts if it's included.** `~/.ssh/config` needs
> `Include ~/.ssh/config.d/*` for any file written there to apply. Nothing here
> adds that line. A row still reading "RemoteForward missing" right after a
> successful write is almost always this.

Every further host is the same three moves: add from **+**, write the forward,
drop that host's ControlMaster once. No new port, no app changes.

## The host row

Collapsed, it shows the display name, the last path opened and when, and a
status icon — a distinct shape per status, not just a hue. Hover for the full
alias and absolute time. Right-click for Test Now, Copy RemoteForward Snippet
and Remove Host… without expanding.

| Expanded field | What it does |
| --- | --- |
| **Display name** | Cosmetic, defaults to the alias. Commits as you type, so closing the popover can't drop an edit. |
| **Default path** + **Open** | Opens that path from the Mac directly, without involving the remote. Handy for testing. |
| **Allow auto-open** | Off and the listener rejects the host exactly like an unknown one (`ERR unknown host`); the row reads "Disabled". |
| **Tunnel** + **Test Now** | Probes immediately instead of on the 30s cycle. Not green shows ssh's stderr tail, selectable. |
| **RemoteForward** | Asks `ssh -G <host>`, so `Include` and patterns resolve the way ssh resolves them. Offers "Add RemoteForward…" and "Copy Snippet" when absent. |
| **Remove Host…** | Confirms, then forgets only RCodeBar's own state. Your ssh config, including any `rcodebar-<alias>` file, is left alone. |

## Diagnosing

Statuses refresh every 30s and whenever the popover opens.

| Status | Means |
| --- | --- |
| ✅ **Connected** | Tunnel is up end to end. |
| ⚠️ **RemoteForward missing** | ssh reaches the host, but nothing answers on `127.0.0.1:47000` there. Check the `RemoteForward` line and that a post-`ssh -O exit` session picked it up. A non-bash login shell also lands here — `/dev/tcp` is a bash feature. |
| ❌ **No connection** | ssh itself can't reach the host: network, host down, or auth. |
| ○ **Checking…** | Not probed yet. |

If `code .` prints the clickable link instead of opening a window:

1. RCodeBar running, "Auto-open remote windows" on — that toggle owns the
   listener, and the line under it should read "Listening on 127.0.0.1:47000".
2. The row is Connected and **Allow auto-open** is on.
3. `~/.rcode.host` on the remote holds the alias you `ssh` with **from the
   Mac**, not the remote's own hostname.
4. A send that times out or is refused is the fallback working as designed, not
   a bug.

## Tests

```
swift test                    # URI parsing, host whitelist, 4 KiB cap,
                              # ssh config discovery, RemoteForward detection
scripts/e2e_test.sh <host>    # against a running listener
```

`e2e_test.sh` needs RCodeBar running with `<host>` added; it sends a valid
request (expects `OK`, VS Code opens) and a bogus one (expects
`ERR unknown host`).

## Developing

`./install.sh` replaces the app you're using. To run a dev build beside it,
without a fight over port 47000:

```
defaults write RCodeBar autoOpenEnabled -bool false   # once, before first run
swift build && .build/debug/RCodeBar
defaults delete RCodeBar                              # cleanup
```

The unbundled binary has no bundle id, so it reads the UserDefaults domain
`RCodeBar` while the packaged app reads `dev.rcodebar.RCodeBar` — separate host
lists. A launch argument won't work in place of that `defaults write`:
`-autoOpenEnabled 0` arrives as a string and the `Bool` read falls back to
`true`. Don't flip Auto-open in the dev popover either; that starts its
listener.

What CI runs, and what to run before pushing:

```
swift test
swift format --recursive --in-place Sources Tests   # fix, then:
swift format lint --recursive --strict Sources Tests
shellcheck -S warning install.sh scripts/e2e_test.sh shell/code
```

`swift format` ships with the toolchain and reads `.swift-format` (4-space
indent, 110 columns). shellcheck is the one extra install; the two
suppressions in `shell/code` are deliberate and carry their reason inline.
Tagging `v*` runs `.github/workflows/release.yml`: it signs the `.app` with
the Developer ID from the repository secrets, notarizes and staples it, and
attaches `RCodeBar.zip` and its `.sha256` to the release. The secrets it needs
are listed at the top of that file.

## Uninstall

1. Turn "Start at Login" off in the popover (or in System Settings › General ›
   Login Items), then Quit.
2. `rm -rf ~/Applications/RCodeBar.app`
3. `defaults delete dev.rcodebar.RCodeBar` — hosts, names, paths and the
   auto-open switch all live there. There is no config file.
4. Optional: `rm ~/.ssh/config.d/rcodebar-*`, and drop `~/.rcode.host` and the
   patched `code` on the remote. Uninstalling does none of that for you.

## License

MIT — see [LICENSE](LICENSE).
