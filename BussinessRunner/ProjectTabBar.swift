import SwiftUI

struct ProjectTabBar: View {
    @EnvironmentObject private var workspace: Workspace
    @Environment(\.colorScheme) private var scheme
    @State private var hoveredID: UUID?

    var body: some View {
        HStack(spacing: 8) {
            Color.clear.frame(width: 70)
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
                                workspace.closeProject(project.id)
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
            Spacer(minLength: 8)
            connectionDot
        }
        .padding(.trailing, 14)
        .frame(height: 44)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
            Rectangle()
                .fill(scheme == .dark ? Color.black.opacity(0.22) : Color.white.opacity(0.35))
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var connectionDot: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(workspace.cursorSnapshot != nil ? Color.green : Color.secondary.opacity(0.45))
                .frame(width: 7, height: 7)
            if workspace.apiKeyPresent {
                Text(workspace.apiKeyMasked)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .help(workspace.cursorSnapshot != nil ? "Cursor подключён" : "Нет сессии")
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
                .foregroundStyle(selected ? .primary : .secondary)
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
                    .fill(scheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.72))
            } else if hovered {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            }
        }
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.white.opacity(scheme == .dark ? 0.10 : 0.35), lineWidth: 1)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onTapGesture(perform: onSelect)
        .help(project.repoPath.isEmpty ? project.name : project.repoPath)
        .contextMenu {
            Button("Закрыть вкладку", action: onClose)
        }
    }
}
