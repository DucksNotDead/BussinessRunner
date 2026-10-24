import SwiftUI

struct ProjectTabBar: View {
    @EnvironmentObject private var workspace: Workspace
    @State private var hoveredID: UUID?

    var body: some View {
        HStack(spacing: 3) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(workspace.projects) { project in
                        ProjectTabItem(
                            project: project,
                            selected: workspace.selectedProjectID == project.id,
                            hovered: hoveredID == project.id,
                            onSelect: {
                                workspace.selectedProjectID = project.id
                            },
                            onClose: {
                                let id = project.id
                                hoveredID = nil
                                Task { @MainActor in
                                    workspace.closeProject(id)
                                }
                            }
                        )
                        .onHover { inside in
                            hoveredID = inside ? project.id : (hoveredID == project.id ? nil : hoveredID)
                        }
                    }
                    Button(action: workspace.createProjectFromFinder) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .brNoFocusRing()
                    .help("Новая вкладка проекта")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .frame(height: 44)
    }
}

private struct ProjectTabItem: View {
    var project: Project
    var selected: Bool
    var hovered: Bool
    var onSelect: () -> Void
    var onClose: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 6) {
            if selected || hovered {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .brNoFocusRing()
                .help("Закрыть вкладку")
            } else {
                Image(systemName: "shippingbox")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 14, height: 14)
            }
            Text(project.name)
                .font(.callout.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .frame(minWidth: 128, idealWidth: 168, maxWidth: 220)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.accentColor.opacity(scheme == .dark ? 0.34 : 0.20))
            } else if hovered {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            }
        }
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(scheme == .dark ? 0.9 : 0.75), lineWidth: 1.5)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onTapGesture(perform: onSelect)
        .help(project.repoPath.isEmpty ? project.name : project.repoPath)
        .contextMenu {
            Button("Закрыть вкладку", action: onClose)
        }
        .id(project.id)
    }
}
