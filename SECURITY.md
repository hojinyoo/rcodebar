# Security

## Trust model

RCodeBar exists to turn a line of text from a remote machine into an opened
window on your Mac. That is a trust boundary, so it is deliberately narrow:

- **Loopback only.** The listener binds `127.0.0.1:47000` with
  `requiredInterfaceType = .loopback`. It is unreachable from any real network
  interface; the only way in is an ssh `RemoteForward` you configured, which
  means an ssh session you authenticated.
- **One fixed prefix.** A request is ignored unless it starts with
  `vscode://vscode-remote/ssh-remote+`. Nothing else is ever handed to
  `NSWorkspace.open`.
- **Host whitelist.** The alias inside the URI must match a host you added in
  the popover. Unknown hosts get `ERR unknown host`, and a host with **Allow
  auto-open** off is rejected exactly like an unknown one.
- **Bounded input.** Requests are read a line at a time with a 4 KiB cap;
  anything longer is answered `ERR too long` and dropped.
- **No ssh config edits without confirmation.** "Add RemoteForward…" writes one
  new file under `~/.ssh/config.d/` and only after you confirm the exact
  contents. It never edits an existing file.

What this does **not** defend against: anyone who can already open an ssh
session to your Mac's forwarded port as you — that is, anyone with your ssh
access to a machine you enabled — can ask VS Code to open a path on that host.
The remote end of the forward is as trusted as the remote itself. Do not enable
hosts you would not hand a shell to.

The app is ad-hoc signed and not notarized, so macOS will quarantine a
downloaded build until you clear it.

## Reporting a vulnerability

Please report privately through GitHub's **Report a vulnerability** button on
the Security tab rather than opening a public issue. Include what you sent, what
happened, and the macOS and app version.
