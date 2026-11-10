import Foundation
import Testing
@testable import UnnamedLauncherKit

@Suite("JSON Schema (S-039)")
struct ConfigSchemaTests {
    let schema = try! JSONSerialization.jsonObject(with: Data(ConfigSchema.json.utf8)) as! [String: Any]
    let keys = try! NSRegularExpression(pattern: ConfigSchema.keysPattern)

    func matches(_ text: String) -> Bool {
        keys.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    @Test("The schema is valid JSON and requires version and entries")
    func shape() {
        #expect(schema["required"] as? [String] == ["version", "entries"])
        #expect(schema["additionalProperties"] as? Bool == false)
    }

    @Test("The keys pattern accepts every key path the app accepts", arguments: [
        "Hyper+Space", "Hyper+Space A T", "hyper+space e", "Ctrl+Alt+L", "Primary+F", "F13 F24",
        "Ctrl+Alt+Shift+Cmd+PageUp", "Hyper+Space Space", "Hyper+Space LeftBracket",
        "Meh+T", "meh+w 1", "CAG+Space", "cag+space A",
    ])
    func accepts(_ text: String) {
        #expect(matches(text))
        #expect(KeySequence(parsing: text) != nil)
    }

    @Test("The keys pattern rejects what the app rejects", arguments: [
        "Hyper+Spcae", "Meta+A", "Ctrl+", "", "Hyper+Space  ++A", "Space Bar",
    ])
    func rejects(_ text: String) {
        #expect(!matches(text))
        #expect(KeySequence(parsing: text) == nil)
    }

    @Test("Every entry key in the sample config matches")
    func fixture() throws {
        let config = try JSONDecoder().decode(Config.self, from: Data(ConfigLoader.starterJSON.utf8))
        #expect(config.entries.allSatisfy { matches($0.keys) })
    }

    @Test("Action types match the app's, and delays can't be negative")
    func types() throws {
        let defs = schema["$defs"] as! [String: Any]
        let variants = (defs["action"] as! [String: Any])["oneOf"] as! [[String: Any]]
        let types = variants.map { (($0["properties"] as! [String: Any])["type"] as! [String: Any])["const"] as! String }
        #expect(types == ConfigSchema.actionTypes)
        let props = schema["properties"] as! [String: Any]
        let runtime = (props["runtime"] as! [String: Any])["properties"] as! [String: Any]
        #expect((runtime["hudDelayMs"] as! [String: Any])["minimum"] as? Int == 0)
    }

    @Test("The starter config points at the schema, and loading ignores $schema")
    func starter() throws {
        #expect(ConfigLoader.starterJSON.contains(#""$schema": "./config.schema.json""#))
        #expect((try? ConfigLoader.load(Data(ConfigLoader.starterJSON.utf8)).get()) != nil)
    }
}
