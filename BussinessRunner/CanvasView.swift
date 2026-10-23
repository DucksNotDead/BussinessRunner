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
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if let tab = Optional(workspace.selectedTab) {
                Image(systemName: tab.systemImage)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                Text(tab.title)
                    .font(.largeTitle.weight(.semibold))
            }
            Spacer()
            if let binding = workspace.selectedProjectBinding, !binding.wrappedValue.githubURL.isEmpty {
                Text(binding.wrappedValue.githubURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }
}
