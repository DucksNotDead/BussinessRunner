import Foundation

struct EnvVariable: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var value: String
}

struct DevEnvironment: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var hardware: String
    var variables: [EnvVariable] = []
    var hash: String = ""
}

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
        case .webAPI: return ["Node/Express", "FastAPI", "Django", "Go", "Spring"]
        case .webUI: return ["React", "Vue", "Svelte", "Next", "Angular"]
        case .ios: return ["SwiftUI", "UIKit"]
        case .android: return ["Jetpack Compose", "Views"]
        case .macos: return ["SwiftUI", "AppKit"]
        case .windows: return ["WinUI", "WPF"]
        }
    }
}

struct ProjectPlatform: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: PlatformKind
    var framework: String
    var hash: String = ""

    var versionName: String { "\(kind.rawValue) · \(framework)" }
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

struct ProcessAction: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
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
    var environments: [DevEnvironment] = []
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
    case environment
    case platforms
    case entities
    case roles
    case rules
    case processes
    case tickets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .environment: return "Среда"
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
        case .environment: return "cpu"
        case .platforms: return "laptopcomputer.and.iphone"
        case .entities: return "cylinder.split.1x2"
        case .roles: return "person.2"
        case .rules: return "checkmark.seal"
        case .processes: return "point.3.filled.connected.trianglepath.dotted"
        case .tickets: return "ticket"
        }
    }
}

enum MentionKind: String {
    case technology
    case role
    case entity
    case variable
    case platform
}

struct Mention: Hashable, Identifiable {
    var kind: MentionKind
    var name: String
    var id: String { "\(kind.rawValue):\(name)" }
}

enum MentionParser {
    static func parse(_ text: String) -> [Mention] {
        var result: [Mention] = []
        collect(#"_([^_\n]+)_"#, in: text, kind: .technology, into: &result)
        collect(#"!([^!\n]+)!"#, in: text, kind: .role, into: &result)
        collect(#"\?([^?\n]+)\?"#, in: text, kind: .entity, into: &result)
        collect(#"\"\"\"([^\"\n]+)\"\"\""#, in: text, kind: .variable, into: &result)
        collect(#"\+([^\+\n]+)\+"#, in: text, kind: .platform, into: &result)
        return result
    }

    private static func collect(_ pattern: String, in text: String, kind: MentionKind, into result: inout [Mention]) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: range) {
            guard match.numberOfRanges > 1, let swiftRange = Range(match.range(at: 1), in: text) else { continue }
            let name = String(text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                result.append(Mention(kind: kind, name: name))
            }
        }
    }
}

enum ProjectFactory {
    static func make(name: String, repoPath: String) -> Project {
        var project = Project(name: name, repoPath: repoPath)
        project.environments = [
            DevEnvironment(name: "dev", hardware: "")
        ]
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
        project.platforms = [
            ProjectPlatform(kind: .webUI, framework: "Next"),
            ProjectPlatform(kind: .webAPI, framework: "Node/Express")
        ]
        project.environments = [
            DevEnvironment(
                name: "dev",
                hardware: "Mac mini",
                variables: [
                    EnvVariable(name: "DATABASE_URL", value: "postgres://localhost:5432/dev"),
                    EnvVariable(name: "STOCK_THRESHOLD", value: "3")
                ]
            )
        ]
        project.entities = [
            makeUser(),
            Entity(
                name: "Product",
                fields: [
                    EntityField(name: "id", type: "UUID"),
                    EntityField(name: "title", type: "String"),
                    EntityField(name: "stock", type: "Int")
                ],
                relations: "Product принадлежит каталогу; заказ ссылается на Product"
            ),
            Entity(
                name: "Order",
                fields: [
                    EntityField(name: "id", type: "UUID"),
                    EntityField(name: "userId", type: "UUID"),
                    EntityField(name: "status", type: "String")
                ],
                relations: "Order → User, Order → Product"
            )
        ]
        project.roles = [
            Role(name: "Кассир", description: "Подтверждает оплату на точке")
        ]
        project.rules = [
            UserRule(name: "Сток", body: "Не продавать товар с stock ниже STOCK_THRESHOLD без явного подтверждения.")
        ]
        let checkout = ProjectProcess(
            name: "Оформление заказа",
            actions: [
                ProcessAction(text: "Клиент ?User? открывает каталог на +web:ui+."),
                ProcessAction(text: "Система проверяет остаток ?Product? против \"\"\"STOCK_THRESHOLD\"\"\"."),
                ProcessAction(text: "Роль !Кассир! подтверждает оплату и создаёт ?Order?.")
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
