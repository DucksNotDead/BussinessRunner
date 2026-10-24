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
        let pendingBefore = HarnessWriter.pendingChanges(in: project)
        guard pendingBefore.contains(where: { $0.type == "entity" && $0.name == "User" && $0.status == .added }) else {
            throw TestError.message("unsaved User should appear in pending changes")
        }
        guard pendingBefore.contains(where: { $0.type == "platform" && $0.name.contains("web:ui") }) else {
            throw TestError.message("unsaved platform should appear in pending changes")
        }
        let first = try HarnessWriter.save(project: project)
        project = first.project
        try assertExists(temp, "entities.md")
        try assertExists(temp, "roles.md")
        try assertExists(temp, "rules.md")
        try assertExists(temp, "platforms.md")
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
        let enviroments = temp.appendingPathComponent(".harness/enviroments.md")
        if FileManager.default.fileExists(atPath: enviroments.path) {
            throw TestError.message("enviroments.md must not exist")
        }
        let entities = try String(contentsOf: temp.appendingPathComponent(".harness/entities.md"), encoding: .utf8)
        guard entities.contains("## User"), entities.contains("хеш:") else {
            throw TestError.message("User entity/hash missing")
        }
        let readme = try String(contentsOf: temp.appendingPathComponent(".harness/readme.md"), encoding: .utf8)
        guard readme.contains("Не указан тип тикета") else {
            throw TestError.message("readme missing ticket-type stop rule")
        }
        guard readme.contains("Не указана платформа") else {
            throw TestError.message("readme missing platform stop rule")
        }
        guard readme.contains("platforms/<platform>/"), readme.contains("web:api"), readme.contains("web:ui") else {
            throw TestError.message("readme missing platforms/<platform>/ layout rule")
        }
        let versions = try String(contentsOf: temp.appendingPathComponent(".harness/versions.md"), encoding: .utf8)
        guard versions.contains("entity | User | init →") else {
            throw TestError.message("versions.md missing User init hash")
        }
        guard versions.contains("platform | web:ui · Next | init →") else {
            throw TestError.message("versions.md missing platform hash")
        }
        let platforms = try String(contentsOf: temp.appendingPathComponent(".harness/platforms.md"), encoding: .utf8)
        guard platforms.contains("## web:ui"), platforms.contains("Next") else {
            throw TestError.message("platforms.md missing web:ui")
        }
        guard platforms.contains("## web:api"), platforms.contains("Node/Express"), platforms.contains("субд: PostgreSQL") else {
            throw TestError.message("platforms.md missing web:api database")
        }
        guard MentionScan.activeToken(in: "каталог _web")?.kind == .platform else {
            throw TestError.message("_ should open platform search")
        }
        guard MentionScan.activeToken(in: "роль !кас")?.kind == .role else {
            throw TestError.message("! should open role search")
        }
        guard MentionScan.activeToken(in: "сущность ?Us")?.kind == .entity else {
            throw TestError.message("? should open entity search")
        }
        guard MentionScan.activeToken(in: "env \"\"\"STOCK")?.kind == .variable else {
            throw TestError.message("\"\"\" should open variable insert")
        }
        guard MentionScan.activeToken(in: "каталог на web:ui.") == nil else {
            throw TestError.message("wrap-markup must not be treated as a mention")
        }
        guard PlatformKind.webAPI.frameworks.contains("Nest"),
              PlatformKind.webAPI.frameworks.contains("Fastify"),
              PlatformKind.webAPI.frameworks.contains("Axum") else {
            throw TestError.message("web:api frameworks must include Nest, Fastify, Axum")
        }
        guard PlatformKind.webUI.frameworks.contains("Nuxt"),
              PlatformKind.ios.frameworks.contains("Flutter"),
              PlatformKind.windows.frameworks.contains("MAUI") else {
            throw TestError.message("platform frameworks must include Nuxt, Flutter, MAUI")
        }
        guard PlatformKind.webAPI.databases.contains("PostgreSQL"),
              PlatformKind.webAPI.databases.contains("MongoDB"),
              PlatformKind.webUI.databases.isEmpty else {
            throw TestError.message("СУБД must be available on web:api only")
        }
        var hashedAPI = ProjectPlatform(kind: .webAPI, framework: "Nest", database: "PostgreSQL")
        let hashPostgres = ContentHash.platform(hashedAPI)
        hashedAPI.database = "MongoDB"
        guard hashPostgres != ContentHash.platform(hashedAPI) else {
            throw TestError.message("platform hash must include database")
        }
        let typedPlatform = "Клиент открывает каталог _"
        guard let platformToken = MentionScan.activeToken(in: typedPlatform), platformToken.kind == .platform else {
            throw TestError.message("_ should open platform pick")
        }
        let insertedPlatform = MentionScan.insert(label: "web:ui", replacing: platformToken, in: typedPlatform)
        guard insertedPlatform == "Клиент открывает каталог web:ui " else {
            throw TestError.message("platform pick should insert a plain name, got \(insertedPlatform)")
        }
        guard !insertedPlatform.contains("_web:ui_"), !insertedPlatform.contains("_web:ui") else {
            throw TestError.message("insert must not keep wrap-markup")
        }
        let typedVariable = "порог \"\"\"ST"
        guard let variableToken = MentionScan.activeToken(in: typedVariable), variableToken.kind == .variable else {
            throw TestError.message("\"\"\" should open variable pick")
        }
        let insertedVariable = MentionScan.insert(label: "STOCK_THRESHOLD", replacing: variableToken, in: typedVariable)
        guard insertedVariable.contains("STOCK_THRESHOLD"), !insertedVariable.contains("\"\"\"STOCK") else {
            throw TestError.message("variable pick should drop triple quotes, got \(insertedVariable)")
        }
        let demoLinks = first.project.processes[0].actions.flatMap(\.links)
        guard demoLinks.contains(where: { $0.kind == .platform && $0.name == "web:ui" && $0.targetID != nil && !$0.hash.isEmpty }) else {
            throw TestError.message("action should store platform link with id/hash")
        }
        let feature = try String(contentsOf: temp.appendingPathComponent(".harness/features/Оформление заказа.md"), encoding: .utf8)
        guard feature.contains("platform: web:ui"), feature.contains("id=`"), feature.contains("хеш=`") else {
            throw TestError.message("feature markdown missing stored mention id/hash")
        }
        guard first.newTickets.contains(where: { $0.kind == .process }) else {
            throw TestError.message("first save should create process ticket")
        }

        if let index = project.entities.firstIndex(where: { $0.name == "Product" }) {
            project.entities[index].fields.append(EntityField(name: "sku", type: "String"))
        }
        let second = try HarnessWriter.save(project: project)
        guard second.newTickets.contains(where: { $0.kind == .migration }) else {
            throw TestError.message("entity change must create migration ticket")
        }
        guard !second.newTickets.contains(where: { $0.kind == .process }) else {
            throw TestError.message("unchanged process must not spawn another process ticket")
        }

        project = second.project
        let pendingAfterSave = HarnessWriter.pendingChanges(in: project)
        guard pendingAfterSave.isEmpty else {
            throw TestError.message("pending changes should clear after Save, got \(pendingAfterSave.map(\.name))")
        }
        if let index = project.entities.firstIndex(where: { $0.name == "Product" }) {
            project.entities[index].relations += " sku"
        }
        let pendingEdit = HarnessWriter.pendingChanges(in: project)
        guard pendingEdit.contains(where: { $0.type == "entity" && $0.name == "Product" && $0.status == .changed }) else {
            throw TestError.message("edited Product should show as changed")
        }
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

        var blocked = project
        blocked.platforms = []
        blocked.processes[0].testCases.append("ещё один кейс")
        do {
            _ = try HarnessWriter.save(project: blocked)
            throw TestError.message("save must refuse tickets without a platform")
        } catch HarnessWriter.HarnessError.noPlatform {
            // expected
        }

        let fresh = ProjectFactory.make(name: "без платформы", repoPath: temp.path)
        do {
            _ = try HarnessWriter.save(project: fresh)
            throw TestError.message("first save without platform must refuse User migration ticket")
        } catch HarnessWriter.HarnessError.noPlatform {
            // expected
        }
        do {
            try HarnessWriter.requirePlatform(fresh)
            throw TestError.message("requirePlatform must throw")
        } catch HarnessWriter.HarnessError.noPlatform {
            // expected
        }

        try assertCloseTabs()
    }

    private static func assertCloseTabs() throws {
        let first = Project(name: "Первый", repoPath: "/tmp/one")
        let second = Project(name: "Второй", repoPath: "/tmp/two")
        let third = Project(name: "Третий", repoPath: "/tmp/three")
        var projects = [first, second, third]
        var selected: UUID? = first.id
        var editing: UUID? = UUID()

        ProjectTabs.close(second.id, projects: &projects, selectedID: &selected, editingProcessID: &editing)
        guard projects.map(\.id) == [first.id, third.id], selected == first.id, editing != nil else {
            throw TestError.message("closing a background tab must keep the selected project")
        }

        ProjectTabs.close(first.id, projects: &projects, selectedID: &selected, editingProcessID: &editing)
        guard projects.map(\.id) == [third.id], selected == third.id else {
            throw TestError.message("closing the selected tab must select the neighbor")
        }

        projects = [first, second, third]
        selected = third.id
        editing = UUID()
        ProjectTabs.close(third.id, projects: &projects, selectedID: &selected, editingProcessID: &editing)
        guard projects.map(\.id) == [first.id, second.id], selected == second.id else {
            throw TestError.message("closing the last selected tab must select the previous")
        }
        projects = [third]
        selected = third.id

        ProjectTabs.close(third.id, projects: &projects, selectedID: &selected, editingProcessID: &editing)
        guard projects.isEmpty, selected == nil, editing == nil else {
            throw TestError.message("closing the last tab must clear selection")
        }

        ProjectTabs.close(first.id, projects: &projects, selectedID: &selected, editingProcessID: &editing)
        guard projects.isEmpty, selected == nil else {
            throw TestError.message("closing an unknown tab must be a no-op")
        }
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
