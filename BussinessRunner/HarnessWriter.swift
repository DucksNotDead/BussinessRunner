import Foundation

struct SaveResult {
    var project: Project
    var writtenRelativePaths: [String]
    var newTickets: [Ticket]
    var newVersions: [VersionRecord]
}

enum HarnessWriter {
    static let harnessDirectory = ".harness"

    static func save(project incoming: Project, now: Date = Date()) throws -> SaveResult {
        var project = incoming
        ProjectFactory.ensureUser(&project)
        guard !project.repoPath.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw HarnessError.noRepo
        }

        let previous = Snapshot(project: incoming)
        rehash(&project)
        let current = Snapshot(project: project)

        var newVersions: [VersionRecord] = []
        record(type: "platform", previous: previous.platforms, current: current.platforms, at: now, into: &newVersions)
        record(type: "entity", previous: previous.entities, current: current.entities, at: now, into: &newVersions)
        record(type: "role", previous: previous.roles, current: current.roles, at: now, into: &newVersions)
        record(type: "rule", previous: previous.rules, current: current.rules, at: now, into: &newVersions)
        record(type: "process", previous: previous.processes, current: current.processes, at: now, into: &newVersions)

        var newTickets: [Ticket] = []
        newTickets.append(contentsOf: processTickets(previous: previous, current: current, at: now))
        newTickets.append(contentsOf: migrationTickets(previous: previous, current: current, project: project, at: now))
        if !newTickets.isEmpty {
            try requirePlatform(project)
        }

        project.versions.append(contentsOf: newVersions)
        project.tickets.append(contentsOf: newTickets)
        project.slotStatus = .idle
        project.lastSavedAt = now

        let root = URL(fileURLWithPath: project.repoPath, isDirectory: true)
        let harness = root.appendingPathComponent(harnessDirectory, isDirectory: true)
        let features = harness.appendingPathComponent("features", isDirectory: true)
        try FileManager.default.createDirectory(at: features, withIntermediateDirectories: true)

        var written: [String] = []
        try write(entitiesMarkdown(project), to: harness.appendingPathComponent("entities.md"), relative: ".harness/entities.md", into: &written)
        try write(rolesMarkdown(project), to: harness.appendingPathComponent("roles.md"), relative: ".harness/roles.md", into: &written)
        try write(rulesMarkdown(project), to: harness.appendingPathComponent("rules.md"), relative: ".harness/rules.md", into: &written)
        try write(platformsMarkdown(project), to: harness.appendingPathComponent("platforms.md"), relative: ".harness/platforms.md", into: &written)
        try write(statusMarkdown(project), to: harness.appendingPathComponent("status.md"), relative: ".harness/status.md", into: &written)
        try write(readmeMarkdown(), to: harness.appendingPathComponent("readme.md"), relative: ".harness/readme.md", into: &written)
        try write(versionsMarkdown(project), to: harness.appendingPathComponent("versions.md"), relative: ".harness/versions.md", into: &written)

        let wantedFeatureFiles = Set(project.processes.map { featureFileName(for: $0.name) })
        for process in project.processes {
            let file = featureFileName(for: process.name)
            try write(featureMarkdown(process, project: project), to: features.appendingPathComponent(file), relative: ".harness/features/\(file)", into: &written)
        }
        if let existing = try? FileManager.default.contentsOfDirectory(atPath: features.path) {
            for leftover in existing where leftover.hasSuffix(".md") && !wantedFeatureFiles.contains(leftover) {
                try? FileManager.default.removeItem(at: features.appendingPathComponent(leftover))
            }
        }

        for leftoverName in ["migrations.md", "enviroments.md"] {
            let leftover = harness.appendingPathComponent(leftoverName)
            if FileManager.default.fileExists(atPath: leftover.path) {
                try FileManager.default.removeItem(at: leftover)
            }
        }

        let rulesDir = root.appendingPathComponent(".cursor/rules", isDirectory: true)
        try FileManager.default.createDirectory(at: rulesDir, withIntermediateDirectories: true)
        try write(cursorRuleMarkdown(), to: rulesDir.appendingPathComponent("read-harness.mdc"), relative: ".cursor/rules/read-harness.mdc", into: &written)

        return SaveResult(project: project, writtenRelativePaths: written, newTickets: newTickets, newVersions: newVersions)
    }

    static func pendingChanges(in project: Project) -> [PendingChange] {
        let previous = Snapshot(project: project)
        var hashed = project
        rehash(&hashed)
        return describeDiff(previous: previous, current: Snapshot(project: hashed))
    }

    private static func describeDiff(previous: Snapshot, current: Snapshot) -> [PendingChange] {
        var changes: [PendingChange] = []
        appendDiff(type: "platform", title: "Платформа", previous: previous.platforms, current: current.platforms, into: &changes)
        appendDiff(type: "entity", title: "Сущность", previous: previous.entities, current: current.entities, into: &changes)
        appendDiff(type: "role", title: "Роль", previous: previous.roles, current: current.roles, into: &changes)
        appendDiff(type: "rule", title: "Правило", previous: previous.rules, current: current.rules, into: &changes)
        appendDiff(type: "process", title: "Процесс", previous: previous.processes, current: current.processes, into: &changes)
        return changes
    }

    private static func appendDiff(
        type: String,
        title: String,
        previous: [String: String],
        current: [String: String],
        into changes: inout [PendingChange]
    ) {
        for name in Set(previous.keys).union(current.keys).sorted() {
            let old = previous[name] ?? ""
            let new = current[name] ?? ""
            if old == new, !old.isEmpty { continue }
            if old.isEmpty && new.isEmpty { continue }
            let status: PendingChange.Status
            if old.isEmpty {
                status = .added
            } else if new.isEmpty {
                status = .removed
            } else {
                status = .changed
            }
            changes.append(PendingChange(type: type, typeTitle: title, name: name, status: status))
        }
    }

    static func requirePlatform(_ project: Project) throws {
        if project.platforms.isEmpty {
            throw HarnessError.noPlatform
        }
    }

    static func setSlotStatus(_ status: SlotStatus, inRepo repoPath: String) throws {
        let url = URL(fileURLWithPath: repoPath)
            .appendingPathComponent(harnessDirectory)
            .appendingPathComponent("status.md")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "\(status.rawValue)\n".write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Hash / diff

    private struct Snapshot {
        var platforms: [String: String]
        var entities: [String: String]
        var roles: [String: String]
        var rules: [String: String]
        var processes: [String: String]

        init(project: Project) {
            var platformHashes: [String: String] = [:]
            var seen: [String: Int] = [:]
            for platform in project.platforms {
                let base = platform.versionName
                let n = seen[base, default: 0]
                seen[base] = n + 1
                let key = n == 0 ? base : "\(base) (\(n + 1))"
                platformHashes[key] = platform.hash
            }
            platforms = platformHashes
            entities = Dictionary(uniqueKeysWithValues: project.entities.map { ($0.name, $0.hash) })
            roles = Dictionary(uniqueKeysWithValues: project.roles.map { ($0.name, $0.hash) })
            rules = Dictionary(uniqueKeysWithValues: project.rules.map { ($0.name, $0.hash) })
            processes = Dictionary(uniqueKeysWithValues: project.processes.map { ($0.name, $0.hash) })
        }
    }

    private static func rehash(_ project: inout Project) {
        for i in project.platforms.indices {
            project.platforms[i].hash = ContentHash.platform(project.platforms[i])
        }
        for i in project.entities.indices {
            project.entities[i].hash = ContentHash.entity(project.entities[i])
        }
        for i in project.roles.indices {
            project.roles[i].hash = ContentHash.role(project.roles[i])
        }
        for i in project.rules.indices {
            project.rules[i].hash = ContentHash.rule(project.rules[i])
        }
        for i in project.processes.indices {
            for j in project.processes[i].actions.indices {
                for k in project.processes[i].actions[j].links.indices {
                    project.processes[i].actions[j].links[k] = refreshed(project.processes[i].actions[j].links[k], in: project)
                }
            }
            project.processes[i].hash = ContentHash.process(project.processes[i])
        }
    }

    private static func refreshed(_ link: ActionLink, in project: Project) -> ActionLink {
        var next = link
        switch link.kind {
        case .platform:
            if let platform = project.platforms.first(where: { $0.id == link.targetID }) {
                next.name = platform.kind.rawValue
                next.hash = platform.hash
            }
        case .role:
            if let role = project.roles.first(where: { $0.id == link.targetID }) {
                next.name = role.name
                next.hash = role.hash
            }
        case .entity:
            if let entity = project.entities.first(where: { $0.id == link.targetID }) {
                next.name = entity.name
                next.hash = entity.hash
            }
        case .variable:
            break
        }
        return next
    }

    private static func record(type: String, previous: [String: String], current: [String: String], at now: Date, into versions: inout [VersionRecord]) {
        let names = Set(previous.keys).union(current.keys).sorted()
        for name in names {
            let old = previous[name] ?? ""
            let new = current[name] ?? ""
            if old == new, !old.isEmpty { continue }
            if old.isEmpty && new.isEmpty { continue }
            versions.append(VersionRecord(
                type: type,
                name: name,
                oldHash: old.isEmpty ? "init" : old,
                newHash: new.isEmpty ? "deleted" : new,
                savedAt: now
            ))
        }
    }

    private static func processTickets(previous: Snapshot, current: Snapshot, at now: Date) -> [Ticket] {
        var tickets: [Ticket] = []
        let names = Set(previous.processes.keys).union(current.processes.keys)
        for name in names.sorted() {
            let old = previous.processes[name]
            let new = current.processes[name]
            if old == new { continue }
            let action: String
            if old == nil { action = "добавлен" }
            else if new == nil { action = "удалён" }
            else { action = "изменён" }
            tickets.append(Ticket(
                kind: .process,
                title: "process: \(name)",
                body: "Процесс «\(name)» \(action). Тип тикета: process.",
                createdAt: now,
                relatedObjectName: name
            ))
        }
        return tickets
    }

    private static func migrationTickets(previous: Snapshot, current: Snapshot, project: Project, at now: Date) -> [Ticket] {
        var tickets: [Ticket] = []
        let entityNames = Set(previous.entities.keys).union(current.entities.keys)
        var changedEntities: [String] = []
        for name in entityNames.sorted() where previous.entities[name] != current.entities[name] {
            changedEntities.append(name)
        }
        if changedEntities.isEmpty { return [] }
        tickets.append(Ticket(
            kind: .migration,
            title: "migration: модель данных",
            body: migrationBody(entities: changedEntities, project: project),
            affectedEntities: changedEntities,
            createdAt: now
        ))
        return tickets
    }

    private static func migrationBody(entities: [String], project: Project) -> String {
        var lines = [
            "Тип тикета: migration.",
            "Исполнитель не пишет /.harness/*.",
            "Критерии: entities.md = БД агента; тесты затронутых процессов; in-session сборка."
        ]
        if !entities.isEmpty {
            lines.append("Сущности: " + entities.joined(separator: ", "))
        }
        let touched = affectedProcessNames(project: project, entities: entities)
        if !touched.isEmpty {
            lines.append("Процессы: " + touched.joined(separator: ", "))
        }
        return lines.joined(separator: "\n")
    }

    private static func affectedProcessNames(project: Project, entities: [String]) -> [String] {
        let entitySet = Set(entities)
        return project.processes.filter { process in
            process.actions.contains { action in
                action.links.contains { $0.kind == .entity && entitySet.contains($0.name) }
            }
        }.map(\.name)
    }

    // MARK: - Markdown

    private static func write(_ text: String, to url: URL, relative: String, into written: inout [String]) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
        written.append(relative)
    }

    private static func entitiesMarkdown(_ project: Project) -> String {
        var md = "# Сущности\n\nИсточник правды для сверки с БД dev-environment агента.\n\n"
        for entity in project.entities {
            md += "## \(entity.name)\n\n"
            md += "- хеш: `\(entity.hash)`\n"
            if entity.fields.isEmpty {
                md += "- поля: нет\n"
            } else {
                md += "- поля:\n"
                for field in entity.fields {
                    md += "  - `\(field.name)`: \(field.type)\n"
                }
            }
            md += "- связи: \(entity.relations.isEmpty ? "нет" : entity.relations)\n\n"
        }
        return md
    }

    private static func rolesMarkdown(_ project: Project) -> String {
        if project.roles.isEmpty {
            return "# Роли\n\nДополнительных ролей нет.\n"
        }
        var md = "# Роли\n\n"
        for role in project.roles {
            md += "## \(role.name)\n\n"
            md += "- хеш: `\(role.hash)`\n"
            md += "- описание: \(role.description.isEmpty ? "—" : role.description)\n\n"
        }
        return md
    }

    private static func rulesMarkdown(_ project: Project) -> String {
        if project.rules.isEmpty {
            return "# Правила\n\nДополнительных правил нет.\n"
        }
        var md = "# Пользовательские правила\n\nАгент следует им только там, где они не противоречат `readme.md`.\n\n"
        for rule in project.rules {
            md += "## \(rule.name)\n\n"
            md += "- хеш: `\(rule.hash)`\n\n"
            md += "\(rule.body)\n\n"
        }
        return md
    }

    private static func platformsMarkdown(_ project: Project) -> String {
        if project.platforms.isEmpty {
            return "# Платформы\n\nПлатформ нет.\n"
        }
        var md = "# Платформы\n\nПишет платформа BussinessRunner. Кодирующий агент файл не меняет.\n\n"
        for platform in project.platforms {
            md += "## \(platform.kind.rawValue)\n\n"
            md += "- хеш: `\(platform.hash)`\n"
            md += "- фреймворк: \(platform.framework)\n\n"
        }
        return md
    }

    private static func statusMarkdown(_ project: Project) -> String {
        "\(project.slotStatus.rawValue)\n"
    }

    private static func versionsMarkdown(_ project: Project) -> String {
        var md = "# История хешей\n\nтип | имя | старый хеш → новый хеш | timestamp/save\n\n"
        let formatter = ISO8601DateFormatter()
        for record in project.versions {
            md += "\(record.type) | \(record.name) | \(record.oldHash) → \(record.newHash) | \(formatter.string(from: record.savedAt))\n"
        }
        return md
    }

    private static func featureMarkdown(_ process: ProjectProcess, project: Project) -> String {
        var md = "# \(process.name)\n\n"
        md += "- хеш процесса: `\(process.hash)`\n"
        md += "- критически важный: \(process.isCritical ? "да" : "нет")\n"
        md += "- вложенные процессы: \(nestedNames(process, project: project))\n\n"
        md += "## Действия\n\n"
        if process.actions.isEmpty {
            md += "Нет действий.\n\n"
        } else {
            for (index, action) in process.actions.enumerated() {
                md += "\(index + 1). \(action.text)\n"
            }
            md += "\n"
        }
        md += "## Логические блоки\n\n"
        if process.logicBlocks.isEmpty {
            md += "Нет отдельных логических блоков. Действия и блоки наследуют хеш процесса.\n\n"
        } else {
            for block in process.logicBlocks {
                md += "### \(block.title)\n\n"
                md += "Связанные действия: \(block.actionIDs.map(\.uuidString).joined(separator: ", "))\n\n"
            }
        }
        md += "## Упоминания\n\n"
        let links = process.actions.flatMap(\.links)
        if links.isEmpty {
            md += "Нет.\n\n"
        } else {
            for link in links {
                let target = link.targetID?.uuidString ?? "—"
                md += "- \(link.kind.rawValue): \(link.name) id=`\(target)` хеш=`\(link.hash)`\n"
            }
            md += "\n"
        }
        md += "## Тест-кейсы\n\n"
        let tests = process.testCases.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if tests.isEmpty {
            md += "Нет тест-кейсов.\n\n"
        } else {
            for test in tests { md += "- \(test)\n" }
            md += "\n"
        }
        md += "## Критерии приёмки\n\n"
        let criteria = process.acceptanceCriteria.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if criteria.isEmpty {
            md += "Нет критериев.\n\n"
        } else {
            for item in criteria { md += "- \(item)\n" }
            md += "\n"
        }
        md += "Действия и логические блоки своего хеша не имеют — наследуют хеш процесса.\n"
        return md
    }

    private static func nestedNames(_ process: ProjectProcess, project: Project) -> String {
        let names = process.nestedProcessIDs.compactMap { id in project.processes.first(where: { $0.id == id })?.name }
        return names.isEmpty ? "нет" : names.joined(separator: ", ")
    }

    static func featureFileName(for processName: String) -> String {
        let cleaned = processName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleaned.isEmpty ? "process" : cleaned) + ".md"
    }

    static func readmeMarkdown() -> String {
        """
        # Обязательные правила для кодирующих агентов

        Источник правды. `.cursor/rules` только заставляет прочитать этот файл до промпта.

        1. Менять `/.harness/*` **строго запрещено**. Harness пишет только платформа BussinessRunner.
        2. Если в промпте не указан тип тикета (`process` / `bug` / `migration`) — остановиться и вернуть ровно: `Не указан тип тикета`.
        3. Если платформа не указана (`/.harness/platforms.md` без платформ) — остановиться и вернуть ровно: `Не указана платформа`.
        4. Целевой проект собирается по платформам. Код лежит в `<корень репозитория>/platforms/<platform>/`, где `<platform>` — одно из: `web:api`, `web:ui`, `ios`, `android`, `macos`, `windows`. Кодирующий агент пишет **только** в папку платформы тикета. Файлы вне `platforms/<platform>/` не трогать.
        5. Перед работой прочитать `/.harness/status.md`. Если там `ACTIVE` — ждать, пока закончится другой тикет.
        6. Каждый блок кода в комментариях связан с процессом и/или платформой **именем и хешем**, понятным машине и человеку. Смена хеша → обновить комментарии в том же тикете.
        7. Перед исполнением тикета сверить `/.harness/entities.md` с БД агента. При расхождении привести БД к `/.harness/entities.md` (документация побеждает).
        8. Каждый созданный процесс покрыт тест-кейсами из `/.harness/features/{имя процесса}.md`.
        9. Критерии приёмки процесса проверяет **не** тот агент, который его реализовывал, а второй прогон Cursor.
        10. **Тикет bug** успешен только если: проходят все тесты затронутых процессов (любое касание code block'ов, связанных с другими процессами, тоже входит); проблема из промпта решена; in-session сборка всех затронутых систем проходит.
        11. **Тикет process** (добавить / удалить / изменить процесс) успешен только если: проходят все тесты затронутых процессов (то же правило связанных code block'ов); выполнены все критерии приёмки этого процесса; in-session сборка всех затронутых систем проходит. Критически важный процесс меняется тем же типом `process` и теми же правилами успеха.
        12. **Тикет migration** (изменение сущностей): БД = `entities.md`, тесты процессов, которые трогают изменения, сборка затронутых систем. Файла `migrations.md` нет. Файла `enviroments.md` нет.
        13. Если в ходе исполнения или ревью описание процесса неполное (нет тестов, нет приёмки или нет самого процесса) или неверное (нет нужных связей) — остановить изменения и вернуть, что именно не так.
        14. Следовать `/.harness/rules.md` только там, где они **не противоречат** `/.harness/readme.md`.

        Вложенный процесс: его тесты входят в «затронутые», если тронуты его code block'и.
        """
    }

    private static func cursorRuleMarkdown() -> String {
        """
        ---
        description: Сначала прочитай /.harness/readme.md
        alwaysApply: true
        ---

        Перед исполнением любого промпта прочитай файл `/.harness/readme.md` целиком и следуй ему.
        Не изменяй `/.harness/*`. Пакет harness пишет только платформа BussinessRunner.
        """
    }

    enum HarnessError: LocalizedError {
        case noRepo
        case noPlatform

        var errorDescription: String? {
            switch self {
            case .noRepo: return "Укажите путь к целевому git-репозиторию."
            case .noPlatform: return "Не указана платформа"
            }
        }
    }
}
