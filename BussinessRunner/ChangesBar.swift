import SwiftUI

struct ChangesBar: View {
    @EnvironmentObject private var workspace: Workspace
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let changes = currentChanges
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
                        workspace.changesBarExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "pencil.and.list.clipboard")
                            .font(.body.weight(.semibold))
                            .symbolRenderingMode(.hierarchical)
                        Text(summary(for: changes))
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                        Image(systemName: "chevron.up")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(workspace.changesBarExpanded ? 180 : 0))
                    }
                    .foregroundStyle(.primary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if workspace.changesBarExpanded {
                    expandedList(changes)
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(
                minWidth: workspace.changesBarExpanded ? 260 : 0,
                maxWidth: workspace.changesBarExpanded ? 360 : 220,
                alignment: .leading
            )

            Button(action: { workspace.saveSelected() }) {
                Text("Сохранить")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 8)
            }
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .brGlassProminent()
            .help("Сохранить harness (⌘S)")
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.regularMaterial)
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(scheme == .dark ? Color.black.opacity(0.42) : Color.white.opacity(0.72))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.12), radius: 18, y: 8)
        .animation(.spring(response: 0.36, dampingFraction: 0.8), value: workspace.changesBarExpanded)
        .animation(.spring(response: 0.36, dampingFraction: 0.8), value: changes.count)
    }

    private var currentChanges: [PendingChange] {
        guard let project = workspace.selectedProject else { return [] }
        return HarnessWriter.pendingChanges(in: project)
    }

    private func summary(for changes: [PendingChange]) -> String {
        if changes.isEmpty {
            return "Нет изменений"
        }
        return ruCount(changes.count, one: "изменение", few: "изменения", many: "изменений")
    }

    @ViewBuilder
    private func expandedList(_ changes: [PendingChange]) -> some View {
        if changes.isEmpty {
            Text("Harness совпадает с канвой.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(changes) { change in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(change.typeTitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 78, alignment: .leading)
                            Text(change.name)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(change.status.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(statusColor(change.status))
                        }
                    }
                }
            }
            .frame(maxHeight: 180)
        }
    }

    private func statusColor(_ status: PendingChange.Status) -> Color {
        switch status {
        case .added: return .green
        case .changed: return .orange
        case .removed: return .red
        }
    }

    private func ruCount(_ n: Int, one: String, few: String, many: String) -> String {
        let n10 = n % 10
        let n100 = n % 100
        if n10 == 1 && n100 != 11 {
            return "\(n) \(one)"
        }
        if (2...4).contains(n10) && !(12...14).contains(n100) {
            return "\(n) \(few)"
        }
        return "\(n) \(many)"
    }
}
