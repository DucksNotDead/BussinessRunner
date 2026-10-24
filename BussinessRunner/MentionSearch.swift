import SwiftUI

struct MentionCandidate: Identifiable {
    var id: String
    var link: ActionLink
    var subtitle: String
}

struct ActionMentionField: View {
    @Binding var action: ProcessAction
    var project: Project
    var forceKind: MentionKind? = nil

    @State private var openKind: MentionKind?
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("действие", text: $action.text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .padding(10)
                .modifier(BRInset(radius: 14))
                .onChange(of: action.text) { _, newValue in
                    if let token = MentionScan.activeToken(in: newValue) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            openKind = token.kind
                            query = token.query
                        }
                    } else if forceKind == nil {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            openKind = nil
                            query = ""
                        }
                    }
                }
            if !action.links.isEmpty {
                HStack(spacing: 6) {
                    ForEach(action.links) { link in
                        MentionChip(mention: Mention(link))
                    }
                }
            }
            if let kind = openKind ?? forceKind {
                palette(kind: kind)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: openKind)
        .onAppear {
            if forceKind != nil {
                openKind = forceKind
            }
        }
    }

    private func palette(kind: MentionKind) -> some View {
        let items = candidates(kind: kind, query: query)
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(kind.trigger) \(kind.title.lowercased())")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if items.isEmpty && !(kind == .variable && !query.trimmingCharacters(in: .whitespaces).isEmpty) {
                Text("Нет совпадений")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(items) { item in
                Button {
                    pick(item.link)
                } label: {
                    HStack {
                        Text(item.link.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if !item.subtitle.isEmpty {
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
            if kind == .variable {
                let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty, !items.contains(where: { $0.link.name.caseInsensitiveCompare(name) == .orderedSame }) {
                    Button("Вставить \(name)") {
                        pick(ActionLink(kind: .variable, targetID: nil, name: name))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func candidates(kind: MentionKind, query: String) -> [MentionCandidate] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch kind {
        case .platform:
            return project.platforms.compactMap { platform in
                let name = platform.kind.rawValue
                if !needle.isEmpty, !name.lowercased().contains(needle), !platform.framework.lowercased().contains(needle) {
                    return nil
                }
                return MentionCandidate(
                    id: platform.id.uuidString,
                    link: ActionLink(kind: .platform, targetID: platform.id, name: name, hash: platform.hash),
                    subtitle: platform.database.isEmpty ? platform.framework : "\(platform.framework) · \(platform.database)"
                )
            }
        case .role:
            return project.roles.compactMap { role in
                if !needle.isEmpty, !role.name.lowercased().contains(needle) { return nil }
                return MentionCandidate(
                    id: role.id.uuidString,
                    link: ActionLink(kind: .role, targetID: role.id, name: role.name, hash: role.hash),
                    subtitle: ""
                )
            }
        case .entity:
            return project.entities.compactMap { entity in
                if !needle.isEmpty, !entity.name.lowercased().contains(needle) { return nil }
                return MentionCandidate(
                    id: entity.id.uuidString,
                    link: ActionLink(kind: .entity, targetID: entity.id, name: entity.name, hash: entity.hash),
                    subtitle: ""
                )
            }
        case .variable:
            var names = Set(project.processes.flatMap(\.actions).flatMap(\.links).filter { $0.kind == .variable }.map(\.name))
            if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                names.insert(query.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return names.sorted().compactMap { name in
                if !needle.isEmpty, !name.lowercased().contains(needle) { return nil }
                return MentionCandidate(
                    id: "var-\(name)",
                    link: ActionLink(kind: .variable, targetID: nil, name: name),
                    subtitle: ""
                )
            }
        }
    }

    private func pick(_ link: ActionLink) {
        let token = MentionScan.activeToken(in: action.text)
        let next = MentionScan.insert(label: link.name, replacing: token, in: action.text)
        action.text = next
        if !action.links.contains(where: { $0.kind == link.kind && $0.targetID == link.targetID && $0.name == link.name }) {
            action.links.append(link)
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            openKind = nil
            query = ""
        }
    }
}
