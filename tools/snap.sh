#!/bin/zsh
# Snapshots of every settings page in light and dark, against a test config in /tmp.
# Usage: tools/snap.sh            all pages
#        APP_SNAPSHOT_PAGES=bindings,general tools/snap.sh
#        tools/snap.sh -AppleShowScrollBars Always     see the scroll bars as people with a mouse see them
set -u
app=~/Applications/UnnamedLauncher.app/Contents/MacOS/UnnamedLauncher
config=/tmp/UnnamedLauncher-test.json
shots=/tmp/UnnamedLauncher-shots
# A crashed run leaves saved window state, and the next launch would wait on a "reopen windows?" alert.
rm -rf ~/Library/Saved\ Application\ State/net.unnamed.launcher.savedState
rm -f $config
rm -rf $shots
APP_STORE=$config APP_SNAPSHOT=$shots $app "$@"
