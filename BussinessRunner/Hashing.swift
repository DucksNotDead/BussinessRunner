import CryptoKit
import Foundation

enum ContentHash {
    static func sha256(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func short(_ hash: String) -> String {
        String(hash.prefix(12))
    }

    static func environment(_ env: DevEnvironment) -> String {
        let vars = env.variables
            .map { "\($0.name)=\($0.value)" }
            .sorted()
            .joined(separator: "\n")
        return sha256(["environment", env.name, env.technologies, env.hardware, vars].joined(separator: "\n"))
    }

    static func entity(_ entity: Entity) -> String {
        let fields = entity.fields
            .map { "\($0.name):\($0.type)" }
            .sorted()
            .joined(separator: "\n")
        return sha256(["entity", entity.name, fields, entity.relations].joined(separator: "\n"))
    }

    static func role(_ role: Role) -> String {
        sha256(["role", role.name, role.description].joined(separator: "\n"))
    }

    static func rule(_ rule: UserRule) -> String {
        sha256(["rule", rule.name, rule.body].joined(separator: "\n"))
    }

    static func process(_ process: ProjectProcess) -> String {
        let actions = process.actions.map(\.text).joined(separator: "\n")
        let blocks = process.logicBlocks.map { "\($0.title):\($0.actionIDs.map(\.uuidString).sorted().joined(separator: ","))" }.joined(separator: "\n")
        let nested = process.nestedProcessIDs.map(\.uuidString).sorted().joined(separator: ",")
        let tests = process.testCases.joined(separator: "\n")
        let acceptance = process.acceptanceCriteria.joined(separator: "\n")
        return sha256([
            "process",
            process.name,
            actions,
            blocks,
            nested,
            tests,
            acceptance,
            process.isCritical ? "critical" : "normal"
        ].joined(separator: "\n"))
    }
}
