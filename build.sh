#!/bin/zsh
# Builds UnnamedLauncher and installs it to ~/Applications/UnnamedLauncher.app.
# Build products live in ~/Library/Developer/UnnamedLauncher, outside the repo
# (and outside Dropbox or iCloud, which would try to sync them).
#
# Usage: ./build.sh              release build, install
#        ./build.sh --debug      debug build, install
#        ./build.sh --open       install, then quit the running copy and open the new one
#        ./build.sh --out DIR    put the app in DIR instead of ~/Applications (CI, releases)
#
# Environment:
#   APP_VERSION     CFBundleShortVersionString (default 0.1); releases set it from the tag
#   SIGN_IDENTITY   codesign identity; a "Developer ID Application" identity also turns on
#                   the hardened runtime and a secure timestamp, which notarization needs
set -euo pipefail
here=${0:A:h}
name="UnnamedLauncher"
scratch="$HOME/Library/Developer/$name/build"
config=release
out="$HOME/Applications"
open_after=0
while (( $# )); do
  case "$1" in
    --debug) config=debug ;;
    --open) open_after=1 ;;
    --out) [[ $# -ge 2 ]] || { echo "--out needs a directory"; exit 2; }; out=$2; shift ;;
    *) echo "unknown option: $1"; exit 2 ;;
  esac
  shift
done
version="${APP_VERSION:-0.1}"

# Signing, first match wins:
#   1. SIGN_IDENTITY
#   2. "Unnamed Launcher Code Signing", the self-signed certificate the GitHub
#      releases are signed with. Local builds then have the same signature as
#      the releases, so macOS keeps Device Control and Input Monitoring granted
#      across rebuilds and updates. It isn't trusted, so look without -v.
#   3. Your Apple Development certificate (Xcode > Settings > Accounts).
#   4. Ad hoc, which macOS treats as a new app after every build.
self_signed="Unnamed Launcher Code Signing"
identity="${SIGN_IDENTITY:-}"
if [[ -z "$identity" ]] && security find-identity -p codesigning 2>/dev/null | grep -q "\"$self_signed\""; then
  identity=$self_signed
fi
if [[ -z "$identity" ]]; then
  identity=$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 -o '"Apple Development: [^"]*"' | tr -d '"' || true)
fi
[[ -n "$identity" ]] || identity=-

build_log=$(mktemp)
build_ok=1
swift build -c "$config" --package-path "$here" --scratch-path "$scratch" > "$build_log" 2>&1 || build_ok=0
grep -E "error|warning|Build complete" "$build_log" | grep -v "^\[" || true
rm -f "$build_log"
[[ "$build_ok" == 1 ]] || { echo "build failed"; exit 1; }
bin="$scratch/$config/$name"
[[ -x "$bin" ]] || { echo "build failed"; exit 1; }
# swift build can report success while an edited file failed to compile. Catch that.
stale=$(find "$here/Sources" -name '*.swift' -newer "$bin" | head -1)
if [[ -n "$stale" ]]; then
  echo "build failed: binary is older than $stale"
  swift build -c $config --package-path "$here" --scratch-path "$scratch" 2>&1 | grep -E "error" | head -20
  exit 1
fi

mkdir -p "$out"
app="${out:A}/$name.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/$name"
sed -e "s/__BUILD__/$(date +%Y%m%d%H%M)/" -e "s/__VERSION__/$version/" "$here/Info.plist.in" > "$app/Contents/Info.plist"
# The icon: Icon/AppIcon.icon -> Resources/Assets.car + AppIcon.icns, rebuilt when it changed.
if [[ -d "$here/Icon/AppIcon.icon" ]]; then
  car="$here/Resources/Assets.car"
  if [[ ! -f "$car" || -n "$(find "$here/Icon/AppIcon.icon" -newer "$car" | head -1)" ]]; then
    "$here/tools/make_icon.sh"
  fi
  cp -X "$car" "$here/Resources/AppIcon.icns" "$app/Contents/Resources/"
fi
xattr -cr "$app"
sign_opts=()
[[ "$identity" == "Developer ID Application"* ]] && sign_opts=(--options runtime --timestamp)
codesign --force "${sign_opts[@]}" --sign "$identity" "$app" 2>&1 | grep -v "replacing existing signature" || true
codesign --verify --strict "$app" || { echo "signature check failed"; exit 1; }
echo "installed $app (version $version, signed: ${identity})"

if (( open_after )); then
  osascript -e "quit app \"$name\"" 2>/dev/null || true
  sleep 0.5
  open "$app"
fi
