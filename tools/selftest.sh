#!/bin/zsh
# Runs the in-app self-test against a fresh config in /tmp. Exit code 0 when every check passed.
set -u
rm -rf ~/Library/Saved\ Application\ State/net.unnamed.launcher.savedState
config=/tmp/UnnamedLauncher-self.json
rm -f $config
APP_STORE=$config ~/Applications/UnnamedLauncher.app/Contents/MacOS/UnnamedLauncher --selftest
