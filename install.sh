#!/usr/bin/env bash
# Build and install RCodeBar.app, then print (never silently apply) the
# ssh config snippet needed to wire up a host's RemoteForward.
#
# Usage:
#   ./install.sh [host-alias]     # default alias: ldev
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
alias_name="${1:-ldev}"

app_name="RCodeBar"
bundle_id="dev.rcodebar.RCodeBar"
dest="$HOME/Applications/${app_name}.app"

echo "== building ${app_name} (release) =="
(cd "$here" && swift build -c release)

bin="$here/.build/release/${app_name}"
[ -x "$bin" ] || { echo "install.sh: build did not produce $bin" >&2; exit 1; }

echo "== packaging ${dest} =="
rm -rf "$dest"
mkdir -p "$dest/Contents/MacOS"
cp "$bin" "$dest/Contents/MacOS/${app_name}"

cat > "$dest/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${app_name}</string>
    <key>CFBundleDisplayName</key>
    <string>${app_name}</string>
    <key>CFBundleIdentifier</key>
    <string>${bundle_id}</string>
    <key>CFBundleExecutable</key>
    <string>${app_name}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "== codesigning (ad hoc, hardened runtime, sandbox off) =="
codesign --force --sign - --options runtime "$dest"

echo "== installed: $dest =="
echo "Launch it once (open \"$dest\") and add \"${alias_name}\" from the popover."
echo

snippet="RemoteForward 47000 127.0.0.1:47000"
suggested_file="$HOME/.ssh/config.d/rcodebar-${alias_name}"

cat <<MSG
== ssh config snippet for host '${alias_name}' ==

Add this line inside the '${alias_name}' Host block (e.g. in
${suggested_file}, alongside your existing Host config.d files):

    ${snippet}

A file under config.d/ only counts if ~/.ssh/config includes it
('Include ~/.ssh/config.d/*'); otherwise put the line in the Host block
in ~/.ssh/config itself.

This script will NOT edit your ssh config. After adding it, drop any
existing ControlMaster for the host so the new RemoteForward takes effect:

    ssh -O exit ${alias_name}

Then reconnect (a fresh ssh/ControlMaster will carry the forward), and on
the remote side, ship the patched cold-path script from this repo
(shell/code) into your dotfiles yourself — install.sh does not touch your
dotfiles or ~/.ssh.
MSG
