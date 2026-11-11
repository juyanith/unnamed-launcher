import Foundation
import Testing
@testable import UnnamedLauncherKit

@Suite("App icons in the Guide (S-054)")
struct AppIconTests {
    let config = try! ConfigLoader.load(Data("""
    { "version": 1,
      "entries": [
        { "keys": "Hyper+Space", "title": "Commands" },
        { "keys": "Hyper+Space E", "title": "Editor", "action": "editor" },
        { "keys": "Hyper+Space A", "title": "Apps" },
        { "keys": "Hyper+Space A T", "title": "Terminal", "action": "terminal" },
        { "keys": "Hyper+Space F", "title": "Find", "action": "find" },
        { "keys": "Hyper+Space N", "title": "Notes", "action": "notes" },
        { "keys": "Hyper+T", "title": "Terminal", "action": "terminal" }
      ],
      "actions": {
        "editor": { "type": "application", "bundleId": "dev.zed.Zed" },
        "terminal": { "type": "application", "bundleId": "com.apple.Terminal", "mode": "start" },
        "find": { "type": "contextual", "variants": { "browser": { "type": "application", "bundleId": "com.apple.Safari" } } },
        "notes": { "type": "open", "target": "~/Notes" }
      },
      "contexts": [{ "id": "browser", "apps": ["com.apple.Safari"] }] }
    """.utf8)).get()

    func node(_ keys: String) -> BindingNode {
        let path = KeySequence(parsing: keys)!
        var node = config.leader(for: path.leader)!
        for step in path.steps { node = node.child(for: step.key)! }
        return node
    }

    @Test func useApplicationCarriesItsBundleId() {
        #expect(config.appBundleId(node("Hyper+Space E")) == "dev.zed.Zed")
        #expect(config.appBundleId(node("Hyper+Space A T")) == "com.apple.Terminal")
        #expect(config.appBundleId(node("Hyper+T")) == "com.apple.Terminal")
    }

    @Test func menusAndOtherActionsCarryNone() {
        #expect(config.appBundleId(node("Hyper+Space")) == nil)
        #expect(config.appBundleId(node("Hyper+Space A")) == nil)
        #expect(config.appBundleId(node("Hyper+Space F")) == nil)
        #expect(config.appBundleId(node("Hyper+Space N")) == nil)
    }

    @Test func everyAppOnce() {
        #expect(config.appBundleIds == ["dev.zed.Zed", "com.apple.Terminal"])
    }
}
