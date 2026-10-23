import Foundation

enum SelfTest {
    static func run() -> Int {
        do {
            try execute()
            print("SELFTEST OK")
            return 0
        } catch {
            fputs("SELFTEST FAIL: \(error)\n", stderr)
            return 1
        }
    }

    private static func execute() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("br-selftest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        var project = ProjectFactory.demoProject(repoPath: temp.path)
        let first = try HarnessWriter.save(project: project)
        project = first.project
        try assertExists(temp, "entities.md")
        try assertExists(temp, "roles.md")
        try assertExists(temp, "rules.md")
        try assertExists(temp, HarnessWriter.environmentsFileName)
        try assertExists(temp, "status.md")
        try assertExists(temp, "readme.md")
        try assertExists(temp, "versions.md")
        try assertExists(temp, "features/Оформление заказа.md")
        let cursorRule = temp.appendingPathComponent(".cursor/rules/read-harness.mdc")
        guard FileManager.default.fileExists(atPath: cursorRule.path) else {
            throw TestError.missing(".cursor/rules/read-harness.mdc")
        }
        let migrations = temp.appendingPathComponent(".harness/migrations.md")
        if FileManager.default.fileExists(atPath: migrations.path) {
            throw TestError.message("migrations.md must not exist")
        }
        let entities = try String(contentsOf: temp.appendingPathComponent(".harness/entities.md"), encoding: .utf8)
        guard entities.contains("## User"), entities.contains("хеш:") else {
            throw TestError.message("User entity/hash missing")
        }
        let readme = try String(contentsOf: temp.appendingPathComponent(".harness/readme.md"), encoding: .utf8)
        guard readme.contains("Не указан тип тикета") else {
            throw TestError.message("readme missing ticket-type stop rule")
        }
        let versions = try String(contentsOf: temp.appendingPathComponent(".harness/versions.md"), encoding: .utf8)
        guard versions.contains("entity | User | init →") else {
            throw TestError.message("versions.md missing User init hash")
        }
        guard first.newTickets.contains(where: { $0.kind == .process }) else {
            throw TestError.message("first save should create process ticket")
        }
        guard first.project.environments.contains(where: { !$0.hash.isEmpty }) else {
            throw TestError.message("environment hash missing")
        }

        if let index = project.entities.firstIndex(where: { $0.name == "Product" }) {
            project.entities[index].fields.append(EntityField(name: "sku", type: "String"))
        }
        if var env = project.environments.first {
            env.variables.append(EnvVariable(name: "NEW_FLAG", value: "1"))
            project.environments[0] = env
        }
        let second = try HarnessWriter.save(project: project)
        guard second.newTickets.contains(where: { $0.kind == .migration }) else {
            throw TestError.message("entity/env change must create migration ticket")
        }
        guard !second.newTickets.contains(where: { $0.kind == .process }) else {
            throw TestError.message("unchanged process must not spawn another process ticket")
        }

        project = second.project
        if let index = project.processes.firstIndex(where: { $0.name == "Оформление заказа" }) {
            project.processes[index].testCases.append("Повторный заказ тем же User.")
        }
        let third = try HarnessWriter.save(project: project)
        guard third.newTickets.contains(where: { $0.kind == .process }) else {
            throw TestError.message("process change must create process ticket")
        }

        try HarnessWriter.setSlotStatus(.ACTIVE, inRepo: temp.path)
        let status = try String(contentsOf: temp.appendingPathComponent(".harness/status.md"), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard status == "ACTIVE" else { throw TestError.message("status.md ACTIVE failed") }
    }

    private static func assertExists(_ repo: URL, _ name: String) throws {
        let url = repo.appendingPathComponent(".harness").appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: url.path) {
            throw TestError.missing(".harness/\(name)")
        }
    }

    enum TestError: LocalizedError {
        case missing(String)
        case message(String)

        var errorDescription: String? {
            switch self {
            case .missing(let path): return "missing \(path)"
            case .message(let text): return text
            }
        }
    }
}
