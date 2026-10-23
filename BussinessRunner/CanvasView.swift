import SwiftUI

struct CanvasView: View {
    @EnvironmentObject private var workspace: Workspace

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            tabBody
        }
    }

    @ViewBuilder
    private var tabBody: some View {
        if let binding = workspace.selectedProjectBinding {
            switch workspace.selectedTab {
            case .environment:
                EnvironmentTab(project: binding)
            case .entities:
                EntitiesTab(project: binding)
            case .roles:
                RolesTab(project: binding)
            case .rules:
                RulesTab(project: binding)
            case .processes:
                ProcessesTab(project: binding)
            case .tickets:
                TicketsTab(project: binding)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: workspace.selectedTab.systemImage)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            Text(workspace.selectedTab.title)
                .font(.largeTitle.weight(.semibold))
            Spacer(minLength: 8)
            if let binding = workspace.selectedProjectBinding, !binding.wrappedValue.githubURL.isEmpty {
                Text(binding.wrappedValue.githubURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Button(action: addInCurrentTab) {
                Image(systemName: "plus")
            }
            .brGlassProminent()
            .help(addHelp)
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var addHelp: String {
        switch workspace.selectedTab {
        case .environment: return "Добавить среду"
        case .entities: return "Добавить сущность"
        case .roles: return "Добавить роль"
        case .rules: return "Добавить правило"
        case .processes: return "Добавить процесс"
        case .tickets: return "Новый баг"
        }
    }

    private func addInCurrentTab() {
        guard var project = workspace.selectedProject else { return }
        switch workspace.selectedTab {
        case .environment:
            project.environments.append(
                DevEnvironment(name: "dev-\(project.environments.count + 1)", technologies: "", hardware: "")
            )
        case .entities:
            project.entities.append(Entity(name: "NewEntity"))
        case .roles:
            project.roles.append(Role(name: ""))
        case .rules:
            project.rules.append(UserRule(name: "", body: ""))
        case .processes:
            let process = ProjectProcess(
                name: "Новый процесс",
                actions: [ProcessAction(text: "")],
                testCases: [""],
                acceptanceCriteria: [""]
            )
            project.processes.append(process)
            workspace.editingProcessID = process.id
        case .tickets:
            workspace.presentBugSheet = true
            return
        }
        workspace.selectedProject = project
        workspace.persist()
    }
}
