import Foundation
import Testing
@testable import UnnamedLauncherKit

@Suite("Icons in the Guide (S-054, S-055)")
struct IconTests {
    let config = try! ConfigLoader.load(Data("""
    { "version": 1,
      "entries": [
        { "keys": "Hyper+Space", "title": "Commands" },
        { "keys": "Hyper+Space E", "title": "Editor", "action": "editor" },
        { "keys": "Hyper+Space A", "title": "Apps" },
        { "keys": "Hyper+Space A T", "title": "Terminal", "action": "terminal" },
        { "keys": "Hyper+Space F", "title": "Find", "action": "find" },
        { "keys": "Hyper+Space N", "title": "Notes", "action": "notes" },
        { "keys": "Hyper+Space W", "title": "Site", "action": "site" },
        { "keys": "Hyper+Space P", "title": "Apps Folder", "action": "apps" },
        { "keys": "Hyper+Space X", "title": "Bad", "action": "bad" },
        { "keys": "Hyper+T", "title": "Terminal", "action": "terminal" }
      ],
      "actions": {
        "editor": { "type": "application", "bundleId": "dev.zed.Zed" },
        "terminal": { "type": "application", "bundleId": "com.apple.Terminal", "mode": "start" },
        "find": { "type": "contextual", "variants": { "browser": { "type": "application", "bundleId": "com.apple.Safari" } } },
        "notes": { "type": "open", "target": "~/Notes" },
        "site": { "type": "open", "target": "https://example.com" },
        "apps": { "type": "open", "target": "/Applications" },
        "bad": { "type": "open", "target": "Notes" }
      },
      "contexts": [{ "id": "browser", "apps": ["com.apple.Safari"] }] }
    """.utf8)).get()

    func node(_ keys: String) -> BindingNode {
        let path = KeySequence(parsing: keys)!
        var node = config.leader(for: path.leader)!
        for step in path.steps { node = node.child(for: step.key)! }
        return node
    }

    let home = URL(fileURLWithPath: "/Users/someone")

    func icon(_ keys: String) -> IconSource? { config.iconSource(node(keys), home: home) }

    @Test func useApplicationCarriesItsBundleId() {
        #expect(icon("Hyper+Space E") == .app("dev.zed.Zed"))
        #expect(icon("Hyper+Space A T") == .app("com.apple.Terminal"))
        #expect(icon("Hyper+T") == .app("com.apple.Terminal"))
    }

    @Test func openCarriesItsFileOrURL() {
        #expect(icon("Hyper+Space N") == .file("/Users/someone/Notes"))
        #expect(icon("Hyper+Space P") == .file("/Applications"))
        #expect(icon("Hyper+Space W") == .url(URL(string: "https://example.com")!))
        #expect(icon("Hyper+Space X") == nil)
    }

    @Test func menusAndOtherActionsCarryNone() {
        #expect(icon("Hyper+Space") == nil)
        #expect(icon("Hyper+Space A") == nil)
        #expect(icon("Hyper+Space F") == nil)
    }

    @Test func everyIconOnce() {
        #expect(config.iconSources(home: home) == [.app("dev.zed.Zed"), .app("com.apple.Terminal"),
                                                    .file("/Users/someone/Notes"), .file("/Applications"),
                                                    .url(URL(string: "https://example.com")!)])
    }
}
