import Foundation

enum PlatformKind: String, Codable, CaseIterable, Identifiable {
    case webAPI = "web:api"
    case webUI = "web:ui"
    case ios
    case android
    case macos
    case windows

    var id: String { rawValue }

    var frameworks: [String] {
        switch self {
        case .webAPI:
            return [
                "Node/Express", "Nest", "Fastify", "Hono", "FastAPI", "Django", "Flask",
                "Gin", "Fiber", "Echo", "Spring", "Ktor", "ASP.NET", "Laravel", "Rails",
                "Phoenix", "Axum"
            ]
        case .webUI:
            return ["React", "Next", "Vue", "Nuxt", "Svelte", "SvelteKit", "Angular", "Remix", "Astro", "Solid"]
        case .ios:
            return ["SwiftUI", "UIKit", "Flutter", "React Native"]
        case .android:
            return ["Jetpack Compose", "Views", "Flutter", "React Native", "Kotlin Multiplatform"]
        case .macos:
            return ["SwiftUI", "AppKit", "Catalyst", "Electron", "Tauri"]
        case .windows:
            return ["WinUI", "WPF", "WinForms", "MAUI", "Electron", "Tauri", "Flutter"]
        }
    }

    var databases: [String] {
        switch self {
        case .webAPI:
            return [
                "PostgreSQL", "MySQL", "MariaDB", "SQLite", "SQL Server", "Oracle",
                "MongoDB", "Redis", "CockroachDB", "DynamoDB", "Firestore", "Cassandra",
                "ClickHouse", "Supabase", "PlanetScale"
            ]
        default:
            return []
        }
    }
}

struct ProjectPlatform: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: PlatformKind
    var framework: String
    var database: String = ""
    var hash: String = ""

    enum CodingKeys: String, CodingKey {
        case id, kind, framework, database, hash
    }

    var versionName: String {
        if database.isEmpty {
            return "\(kind.rawValue) · \(framework)"
        }
        return "\(kind.rawValue) · \(framework) · \(database)"
    }

    init(kind: PlatformKind, framework: String, database: String = "", hash: String = "", id: UUID = UUID()) {
        self.id = id
        self.kind = kind
        self.framework = framework
        self.database = database.isEmpty ? (kind.databases.first ?? "") : database
        self.hash = hash
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try container.decode(PlatformKind.self, forKey: .kind)
        framework = try container.decode(String.self, forKey: .framework)
        hash = try container.decodeIfPresent(String.self, forKey: .hash) ?? ""
        let stored = try container.decodeIfPresent(String.self, forKey: .database) ?? ""
        if kind.databases.isEmpty {
            database = ""
        } else if kind.databases.contains(stored) {
            database = stored
        } else {
            database = kind.databases.first ?? ""
        }
    }
}

struct EntityField: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var type: String
}

struct Entity: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var fields: [EntityField] = []
    var relations: String = ""
    var hash: String = ""
}

struct Role: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var description: String = ""
    var hash: String = ""
}

struct UserRule: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var body: String = ""
    var hash: String = ""
}

struct ActionLink: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var kind: MentionKind
    var targetID: UUID?
    var name: String
    var hash: String = ""
}

struct ProcessAction: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var links: [ActionLink] = []
}

struct LogicBlock: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var actionIDs: [UUID] = []
}

struct ProjectProcess: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var actions: [ProcessAction] = []
    var logicBlocks: [LogicBlock] = []
    var nestedProcessIDs: [UUID] = []
    var testCases: [String] = [""]
    var acceptanceCriteria: [String] = [""]
    var isCritical: Bool = false
    var hash: String = ""
}

enum TicketKind: String, Codable, CaseIterable, Identifiable {
    case process
    case bug
    case migration

    var id: String { rawValue }
}

struct Ticket: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: TicketKind
    var title: String
    var body: String
    var affectedEntities: [String] = []
    var affectedEnvVars: [String] = []
    var createdAt: Date = Date()
    var relatedObjectName: String = ""
}

struct VersionRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var type: String
    var name: String
    var oldHash: String
    var newHash: String
    var savedAt: Date = Date()
}

enum SlotStatus: String, Codable {
    case idle
    case ACTIVE
}

struct Project: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var repoPath: String
    var githubURL: String = ""
    var platforms: [ProjectPlatform] = []
    var entities: [Entity] = []
    var roles: [Role] = []
    var rules: [UserRule] = []
    var processes: [ProjectProcess] = []
    var tickets: [Ticket] = []
    var versions: [VersionRecord] = []
    var slotStatus: SlotStatus = .idle
    var lastSavedAt: Date? = nil
}

enum CanvasTab: String, CaseIterable, Identifiable {
    case platforms
    case entities
    case roles
    case rules
    case processes
    case tickets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .platforms: return "Платформы"
        case .entities: return "Сущности"
        case .roles: return "Роли"
        case .rules: return "Правила"
        case .processes: return "Процессы"
        case .tickets: return "Тикеты"
        }
    }

    var systemImage: String {
        switch self {
        case .platforms: return "laptopcomputer.and.iphone"
        case .entities: return "cylinder.split.1x2"
        case .roles: return "person.2"
        case .rules: return "checkmark.seal"
        case .processes: return "point.3.filled.connected.trianglepath.dotted"
        case .tickets: return "ticket"
        }
    }

    var emptyTitle: String {
        switch self {
        case .platforms: return "Целевые платформы продукта"
        case .entities: return "Сущности модели данных"
        case .roles: return "Роли участников"
        case .rules: return "Пользовательские правила"
        case .processes: return "Процессы, которые ведёт PM"
        case .tickets: return "Тикеты process, bug и migration"
        }
    }

    var emptyDetail: String {
        switch self {
        case .platforms:
            return "Закрытый список: web:api, web:ui, ios, android, macos, windows. Без платформы тикеты не создаются и не принимаются."
        case .entities:
            return "User есть всегда. Остальные сущности заводятся здесь."
        case .roles:
            return "Необязательно — вкладку можно оставить пустой. У каждой роли будет хеш после Save."
        case .rules:
            return "Необязательно. Агент следует им только там, где они не противоречат readme."
        case .processes:
            return "Нужен хотя бы один процесс, чтобы Save записал harness. Действия связываются через _ ! ? \"\"\"."
        case .tickets:
            return "process и migration появляются при Save. Баг заводится здесь. Без платформы тикет не принимается."
        }
    }
}

struct PendingChange: Identifiable, Equatable {
    enum Status: String, Equatable {
        case added
        case changed
        case removed

        var title: String {
            switch self {
            case .added: return "добавлено"
            case .changed: return "изменено"
            case .removed: return "удалено"
            }
        }
    }

    var type: String
    var typeTitle: String
    var name: String
    var status: Status

    var id: String { "\(type)|\(name)|\(status.rawValue)" }
}

enum MentionKind: String, Codable, CaseIterable {
    case platform
    case role
    case entity
    case variable

    var trigger: String {
        switch self {
        case .platform: return "_"
        case .role: return "!"
        case .entity: return "?"
        case .variable: return "\"\"\""
        }
    }

    var title: String {
        switch self {
        case .platform: return "Платформа"
        case .role: return "Роль"
        case .entity: return "Сущность"
        case .variable: return "Переменная"
        }
    }
}

struct Mention: Hashable, Identifiable {
    var kind: MentionKind
    var name: String
    var hash: String = ""
    var id: String { "\(kind.rawValue):\(name):\(hash)" }

    init(kind: MentionKind, name: String, hash: String = "") {
        self.kind = kind
        self.name = name
        self.hash = hash
    }

    init(_ link: ActionLink) {
        kind = link.kind
        name = link.name
        hash = link.hash
    }
}

enum MentionScan {
    struct Token {
        var kind: MentionKind
        var query: String
        var start: String.Index
    }

    static func activeToken(in text: String) -> Token? {
        let start: String.Index
        if let space = text.lastIndex(where: { $0.isWhitespace || $0 == "\n" }) {
            start = text.index(after: space)
        } else {
            start = text.startIndex
        }
        let token = String(text[start...])
        if token.hasPrefix("\"\"\"") {
            return Token(kind: .variable, query: String(token.dropFirst(3)), start: start)
        }
        if token.hasPrefix("_") {
            return Token(kind: .platform, query: String(token.dropFirst()), start: start)
        }
        if token.hasPrefix("!") {
            return Token(kind: .role, query: String(token.dropFirst()), start: start)
        }
        if token.hasPrefix("?") {
            return Token(kind: .entity, query: String(token.dropFirst()), start: start)
        }
        return nil
    }

    static func insert(label: String, replacing token: Token?, in text: String) -> String {
        let prefix: String
        if let token {
            prefix = String(text[..<token.start])
        } else {
            prefix = text
        }
        let needsSpace = !prefix.isEmpty && !prefix.hasSuffix(" ") && !prefix.hasSuffix("\n")
        return prefix + (needsSpace ? " " : "") + label + " "
    }
}

enum ProjectTabs {
    static func close(
        _ id: UUID,
        projects: inout [Project],
        selectedID: inout UUID?,
        editingProcessID: inout UUID?
    ) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        let wasSelected = selectedID == id
        projects.remove(at: index)
        guard wasSelected else { return }
        let next = projects.indices.contains(index) ? projects[index] : projects.last
        selectedID = next?.id
        editingProcessID = next.flatMap { $0.processes.first?.id }
    }
}

enum ProjectFactory {
    static func make(name: String, repoPath: String) -> Project {
        var project = Project(name: name, repoPath: repoPath)
        project.entities = [makeUser()]
        return project
    }

    static func makeUser() -> Entity {
        Entity(
            name: "User",
            fields: [
                EntityField(name: "id", type: "UUID"),
                EntityField(name: "email", type: "String")
            ],
            relations: ""
        )
    }

    static func ensureUser(_ project: inout Project) {
        if !project.entities.contains(where: { $0.name == "User" }) {
            project.entities.insert(makeUser(), at: 0)
        }
    }

    static func demoProject(repoPath: String) -> Project {
        var project = make(name: "Демо", repoPath: repoPath)
        project.githubURL = ""
        let webUI = ProjectPlatform(kind: .webUI, framework: "Next")
        let webAPI = ProjectPlatform(kind: .webAPI, framework: "Node/Express")
        project.platforms = [webUI, webAPI]
        let user = makeUser()
        let product = Entity(
            name: "Product",
            fields: [
                EntityField(name: "id", type: "UUID"),
                EntityField(name: "title", type: "String"),
                EntityField(name: "stock", type: "Int")
            ],
            relations: "Product принадлежит каталогу; заказ ссылается на Product"
        )
        let order = Entity(
            name: "Order",
            fields: [
                EntityField(name: "id", type: "UUID"),
                EntityField(name: "userId", type: "UUID"),
                EntityField(name: "status", type: "String")
            ],
            relations: "Order → User, Order → Product"
        )
        project.entities = [user, product, order]
        let cashier = Role(name: "Кассир", description: "Подтверждает оплату на точке")
        project.roles = [cashier]
        project.rules = [
            UserRule(name: "Сток", body: "Не продавать товар с stock ниже STOCK_THRESHOLD без явного подтверждения.")
        ]
        let checkout = ProjectProcess(
            name: "Оформление заказа",
            actions: [
                ProcessAction(
                    text: "Клиент User открывает каталог на web:ui.",
                    links: [
                        ActionLink(kind: .entity, targetID: user.id, name: "User"),
                        ActionLink(kind: .platform, targetID: webUI.id, name: "web:ui")
                    ]
                ),
                ProcessAction(
                    text: "Система проверяет остаток Product.",
                    links: [
                        ActionLink(kind: .entity, targetID: product.id, name: "Product")
                    ]
                ),
                ProcessAction(
                    text: "Роль Кассир подтверждает оплату и создаёт Order.",
                    links: [
                        ActionLink(kind: .role, targetID: cashier.id, name: "Кассир"),
                        ActionLink(kind: .entity, targetID: order.id, name: "Order")
                    ]
                )
            ],
            logicBlocks: [
                LogicBlock(title: "Если сток ниже порога")
            ],
            nestedProcessIDs: [],
            testCases: [
                "При достаточном стоке заказ создаётся и stock уменьшается на 1.",
                "При stock ниже порога заказ не создаётся без подтверждения кассира."
            ],
            acceptanceCriteria: [
                "В БД dev есть Order, связанный с User и Product.",
                "Покрытие тест-кейсами из harness этого процесса."
            ],
            isCritical: true
        )
        project.processes = [checkout]
        if let firstID = project.processes.first?.id,
           var block = project.processes[0].logicBlocks.first {
            if let second = project.processes[0].actions.dropFirst().first?.id {
                block.actionIDs = [second]
                project.processes[0].logicBlocks = [block]
            }
            _ = firstID
        }
        return project
    }
}
