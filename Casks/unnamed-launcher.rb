# The Homebrew cask. The release workflow updates version and sha256 on every tag.
#   brew tap juyanith/unnamed-launcher https://github.com/juyanith/unnamed-launcher
#   brew install --cask unnamed-launcher
cask "unnamed-launcher" do
  version "0.1.1"
  sha256 "842354ce18b4cff2e947b7b031c7a1a367a5053cf9c9c675cb069fcd5fb84a12"

  url "https://github.com/juyanith/unnamed-launcher/releases/download/v#{version}/UnnamedLauncher-#{version}.zip"
  name "Unnamed Launcher"
  desc "Leader-key launcher in the menu bar"
  homepage "https://github.com/juyanith/unnamed-launcher"

  app "UnnamedLauncher.app"

  # Quit the running copy before an upgrade or uninstall replaces it.
  uninstall quit: "net.unnamed.launcher"

  postflight do
    # The app is signed with the project's own certificate, not notarized, so
    # Gatekeeper would block it. Clear the download mark Homebrew adds.
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/UnnamedLauncher.app"]
    # Start it again after an install or upgrade.
    system_command "/usr/bin/open", args: ["#{appdir}/UnnamedLauncher.app"]
  end
end
