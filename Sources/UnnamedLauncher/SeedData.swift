import Foundation
import UnnamedLauncherKit

/// Sample config for snapshots and the self-test. Everything in it can be
/// written in the config file today, and created in the Bindings window
/// once M4 lands.
enum SeedData {
    static let fixtureJSON = """
    {
      "version": 1,
      "entries": [
        { "keys": "Hyper+Space", "title": "Commands" },
        { "keys": "Hyper+Space Space", "title": "Spotlight", "action": "spotlight" },
        { "keys": "Hyper+Space E", "title": "Editor", "action": "open-editor" },
        { "keys": "Hyper+Space B", "title": "Browser", "action": "open-browser" },
        { "keys": "Hyper+Space A", "title": "Applications" },
        { "keys": "Hyper+Space A T", "title": "Terminal", "action": "open-terminal" },
        { "keys": "Hyper+Space A M", "title": "Messages", "action": "open-messages" },
        { "keys": "Hyper+Space N", "title": "Notes for the weekly planning meeting", "action": "notes" },
        { "keys": "Hyper+Space S", "title": "Screenshot", "action": "screenshot" },
        { "keys": "Hyper+Space L", "title": "Address Bar", "action": "address-bar" },
        { "keys": "Hyper+Space F", "title": "Find", "action": "find" },
        { "keys": "Meh+W", "title": "Workspace" },
        { "keys": "Meh+W 1", "title": "Workspace 1", "action": "workspace-1" },
        { "keys": "CAG+T", "title": "Terminal", "action": "open-terminal" }
      ],
      "actions": {
        "spotlight": { "type": "send", "keys": "Cmd+Space" },
        "open-editor": { "type": "application", "bundleId": "dev.zed.Zed" },
        "open-browser": { "type": "application", "bundleId": "com.apple.Safari" },
        "open-terminal": { "type": "application", "bundleId": "com.apple.Terminal" },
        "open-messages": { "type": "application", "bundleId": "com.apple.MobileSMS" },
        "notes": { "type": "open", "target": "~/Documents/Notes" },
        "screenshot": { "type": "send", "keys": "Cmd+Shift+4" },
        "workspace-1": { "type": "send", "keys": "Ctrl+1" },
        "address-bar": { "type": "contextual", "variants": { "browser": { "type": "send", "keys": "Cmd+L" } } },
        "find": {
          "type": "contextual",
          "variants": { "browser": { "type": "send", "keys": "Cmd+F" } },
          "fallback": { "type": "send", "keys": "Cmd+F" }
        }
      },
      "contexts": [
        { "id": "browser", "apps": ["com.apple.Safari", "com.google.Chrome"] }
      ]
    }
    """

    static var fixture: LoadedConfig {
        // The fixture is part of the app, so a failure here is a bug in it.
        try! ConfigLoader.load(Data(fixtureJSON.utf8)).get()
    }

    /// The Guide as it looks right after pressing the leader.
    static var guideContent: GuideContent {
        let config = fixture
        let leader = config.leaders[0]
        // In Notes, so the browser-only Address Bar shows as unavailable.
        return GuideContent(menu: leader, path: [leader.title], config: config,
                            frontApp: "com.apple.Notes", frontAppName: "Notes")
    }
}
