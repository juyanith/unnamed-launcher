# The Homebrew cask. The release workflow updates version and sha256 on every tag.
#   brew tap juyanith/unnamed-launcher https://github.com/juyanith/unnamed-launcher
#   brew install --cask unnamed-launcher
cask "unnamed-launcher" do
  version "0.1.3"
  sha256 "d0a25ef0b84bc1c9260f6d49c3c5037080d00a797661c49eee8296649494ff9d"

  url "https://github.com/juyanith/unnamed-launcher/releases/download/v#{version}/UnnamedLauncher-#{version}.zip"
  name "Unnamed Launcher"
  desc "Leader-key launcher in the menu bar"
  homepage "https://github.com/juyanith/unnamed-launcher"

  app "UnnamedLauncher.app"

  # Quit the running copy before an upgrade or uninstall replaces it.
  # brew upgrade reopens the apps it quit, so an update restarts the launcher.
  # (Install steps run in a sandbox where open can't start an app.)
  uninstall quit: "net.unnamed.launcher"

  postflight_steps do
    # The app is signed with the project's own certificate, not notarized, so
    # Gatekeeper would block it. Clear the download mark Homebrew adds.
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/UnnamedLauncher.app"]
  end
end
