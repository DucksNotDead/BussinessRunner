import AppKit
import Foundation
import SwiftUI

@MainActor
final class Workspace: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProjectID: UUID?
    @Published var selectedTab: CanvasTab = .environment
    @Published var editingProcessID: UUID?
    @Published var cursorSnapshot: CursorInitSnapshot?
    @Published var cursorError: String?
    @Published var cursorBusy = false
    @Published var apiKeyPresent = false
    @Published var apiKeyMasked = ""
    @Published var saveMessage: String?
    @Published var saveError: String?
    @Published var presentNewProject = false
    @Published var presentBugSheet = false
    @Published var newProjectName = ""
    @Published var newProjectPath = ""
    @Published var agentLaunchMessage: String?

    private let api = CursorAPI()
    private let persistURL: URL

    var selectedProject: Project? {
        get { projects.first(where: { $0.id == selectedProjectID }) }
        set {
            guard let newValue, let index = projects.firstIndex(where: { $0.id == newValue.id }) else { return }
            projects[index] = newValue
        }
    }

    var selectedProjectBinding: Binding<Project>? {
        guard let id = selectedProjectID, let index = projects.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.projects[index] },
            set: { self.projects[index] = $0; self.persist() }
        )
    }

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("BussinessRunner", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        persistURL = support.appendingPathComponent("projects.json")
        loadPersisted()
        if SnapshotExport.requestedDirectory == nil {
            refreshKeyPresence()
        }
        if CommandLine.arguments.contains("--demo-seed") || CommandLine.arguments.contains("--demo-save") {
            seedDemoIfNeeded()
        }
        if CommandLine.arguments.contains("--demo-save") {
            saveSelected()
        }
        if let tabArg = CommandLine.arguments.first(where: { $0.hasPrefix("--tab=") }) {
            let raw = String(tabArg.dropFirst("--tab=".count))
            if let tab = CanvasTab(rawValue: raw) {
                selectedTab = tab
            }
        }
    }

    func refreshKeyPresence() {
        if let key = SecretStore.loadAPIKey() {
            apiKeyPresent = true
            apiKeyMasked = SecretStore.masked(key)
        } else {
            apiKeyPresent = false
            apiKeyMasked = ""
        }
    }

    func connectCursor() async {
        cursorBusy = true
        cursorError = nil
        defer { cursorBusy = false }
        guard let key = SecretStore.loadAPIKey() else {
            apiKeyPresent = false
            cursorError = CursorAPIError.missingKey.localizedDescription
            return
        }
        apiKeyPresent = true
        apiKeyMasked = SecretStore.masked(key)
        do {
            cursorSnapshot = try await api.initSession(apiKey: key)
        } catch {
            cursorSnapshot = nil
            cursorError = error.localizedDescription
        }
    }

    func saveAPIKey(_ raw: String) {
        do {
            try SecretStore.save(raw)
            refreshKeyPresence()
            cursorError = nil
        } catch {
            cursorError = error.localizedDescription
        }
    }

    func createProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = newProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var project = ProjectFactory.make(name: name, repoPath: path)
        ProjectFactory.ensureUser(&project)
        projects.append(project)
        selectedProjectID = project.id
        selectedTab = .environment
        editingProcessID = nil
        presentNewProject = false
        newProjectName = ""
        newProjectPath = ""
        persist()
    }

    func chooseRepo(for projectID: UUID? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Выбрать"
        panel.message = "Целевой git-репозиторий, куда Save запишет /.harness/"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let projectID, let index = projects.firstIndex(where: { $0.id == projectID }) {
            projects[index].repoPath = url.path
            persist()
        } else {
            newProjectPath = url.path
        }
    }

    func saveSelected() {
        saveError = nil
        saveMessage = nil
        guard let project = selectedProject else {
            saveError = "Сначала выберите проект."
            return
        }
        do {
            let result = try HarnessWriter.save(project: project)
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index] = result.project
            }
            persist()
            let tickets = result.newTickets.map(\.kind.rawValue).joined(separator: ", ")
            let ticketNote = result.newTickets.isEmpty ? "новых тикетов нет" : "тикеты: \(tickets)"
            saveMessage = "Записано \(result.writtenRelativePaths.count) файлов. \(ticketNote)."
            selectedTab = .tickets
        } catch {
            saveError = error.localizedDescription
        }
    }

    func addBug(title: String, body: String, entities: [String]) {
        guard var project = selectedProject, let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        project.tickets.append(Ticket(
            kind: .bug,
            title: title,
            body: "Тип тикета: bug.\n\(body)",
            affectedEntities: entities
        ))
        projects[index] = project
        persist()
    }

    func launchTicket(_ ticket: Ticket) async {
        agentLaunchMessage = nil
        guard let project = selectedProject else { return }
        guard let key = SecretStore.loadAPIKey() else {
            agentLaunchMessage = CursorAPIError.missingKey.localizedDescription
            return
        }
        let prompt = """
        Тип тикета: \(ticket.kind.rawValue).
        \(ticket.title)

        \(ticket.body)

        Прочитай /.harness/readme.md до работы. Не меняй /.harness/*.
        """
        do {
            try HarnessWriter.setSlotStatus(.ACTIVE, inRepo: project.repoPath)
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index].slotStatus = .ACTIVE
            }
            persist()
            let response = try await api.createAgent(
                apiKey: key,
                prompt: prompt,
                githubURL: project.githubURL.isEmpty ? nil : project.githubURL,
                modelID: cursorSnapshot?.models.first?.id
            )
            let name = response.agent?.name ?? response.name ?? "агент"
            let url = response.agent?.url ?? response.url ?? ""
            agentLaunchMessage = url.isEmpty ? "Запущен \(name)." : "Запущен \(name): \(url)"
        } catch {
            agentLaunchMessage = error.localizedDescription
            try? HarnessWriter.setSlotStatus(.idle, inRepo: project.repoPath)
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index].slotStatus = .idle
            }
        }
    }

    func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(projects)
            try data.write(to: persistURL, options: .atomic)
        } catch {
            saveError = "Не удалось сохранить канву локально."
        }
    }

    private func loadPersisted() {
        guard let data = try? Data(contentsOf: persistURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode([Project].self, from: data) {
            projects = loaded
            selectedProjectID = loaded.first?.id
        }
    }

    func seedDemoIfNeeded() {
        if projects.contains(where: { $0.name == "hmmml shop" }) {
            selectedProjectID = projects.first(where: { $0.name == "hmmml shop" })?.id
            return
        }
        let demoRoot = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("dev/BussinessRunner/.demo-target")
        try? FileManager.default.createDirectory(at: demoRoot, withIntermediateDirectories: true)
        let git = demoRoot.appendingPathComponent(".git")
        if !FileManager.default.fileExists(atPath: git.path) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            task.arguments = ["init"]
            task.currentDirectoryURL = demoRoot
            try? task.run()
            task.waitUntilExit()
        }
        let project = ProjectFactory.demoHmmmlShop(repoPath: demoRoot.path)
        projects.insert(project, at: 0)
        selectedProjectID = project.id
        selectedTab = .processes
        editingProcessID = project.processes.first?.id
        persist()
    }
}
