import SwiftUI

enum BR {
    static let card: CGFloat = 24
    static let chip: CGFloat = 14
    static let field: CGFloat = 14
    static let sidebar: CGFloat = 16
}

struct CanvasBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.52, 0.48], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: scheme == .dark
                ? [
                    Color(red: 0.07, green: 0.08, blue: 0.12),
                    Color(red: 0.10, green: 0.12, blue: 0.20),
                    Color(red: 0.08, green: 0.09, blue: 0.16),
                    Color(red: 0.12, green: 0.10, blue: 0.18),
                    Color(red: 0.16, green: 0.14, blue: 0.28),
                    Color(red: 0.09, green: 0.14, blue: 0.22),
                    Color(red: 0.06, green: 0.07, blue: 0.10),
                    Color(red: 0.08, green: 0.11, blue: 0.16),
                    Color(red: 0.07, green: 0.09, blue: 0.14)
                ]
                : [
                    Color(red: 0.93, green: 0.94, blue: 0.98),
                    Color(red: 0.88, green: 0.91, blue: 0.99),
                    Color(red: 0.94, green: 0.93, blue: 0.98),
                    Color(red: 0.90, green: 0.88, blue: 0.97),
                    Color(red: 0.84, green: 0.86, blue: 0.97),
                    Color(red: 0.89, green: 0.93, blue: 0.99),
                    Color(red: 0.95, green: 0.95, blue: 0.98),
                    Color(red: 0.91, green: 0.93, blue: 0.97),
                    Color(red: 0.93, green: 0.94, blue: 0.97)
                ]
        )
        .ignoresSafeArea()
    }
}

struct BRSurface: ViewModifier {
    var radius: CGFloat = BR.card
    var interactive: Bool = true
    var tint: Color? = nil
    var apply: Bool = true

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if !apply {
            content
        } else if SnapshotExport.requestedDirectory != nil {
            content
                .background(
                    (tint ?? Color.clear).opacity(tint == nil ? 0 : 0.28),
                    in: shape
                )
                .background(.ultraThinMaterial, in: shape)
        } else if let tint {
            content.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else if interactive {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content.glassEffect(.regular, in: shape)
        }
    }
}

extension View {
    func brSurface(radius: CGFloat = BR.card, interactive: Bool = true, tint: Color? = nil, apply: Bool = true) -> some View {
        modifier(BRSurface(radius: radius, interactive: interactive, tint: tint, apply: apply))
    }

    @ViewBuilder
    func brGlassProminent() -> some View {
        if SnapshotExport.requestedDirectory != nil {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(.glassProminent)
        }
    }

    @ViewBuilder
    func brGlass() -> some View {
        if SnapshotExport.requestedDirectory != nil {
            self.buttonStyle(.bordered)
        } else {
            self.buttonStyle(.glass)
        }
    }

    func brCapsule(tint: Color? = nil) -> some View {
        let shape = Capsule()
        if SnapshotExport.requestedDirectory != nil {
            return AnyView(background(.ultraThinMaterial, in: shape))
        }
        if let tint {
            return AnyView(glassEffect(.regular.tint(tint).interactive(), in: shape))
        }
        return AnyView(glassEffect(.regular, in: shape))
    }
}

struct AddCapsuleButton: View {
    var title: String = "Добавить"
    var help: String = ""
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .padding(.horizontal, 6)
        }
        .buttonBorderShape(.capsule)
        .controlSize(.regular)
        .brGlassProminent()
        .help(help)
    }
}

struct BRSelectOpenPreference: PreferenceKey {
    static var defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

struct BRSelect<Value: Hashable>: View {
    var title: String = ""
    var options: [Value]
    var label: (Value) -> String
    var forceExpanded: Bool = false
    @Binding var selection: Value
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(label(selection))
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .brSurface(radius: 14)

            if isOpen {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                selection = option
                                expanded = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(label(option))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                if option == selection {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.tint)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .background(
                                option == selection ? Color.accentColor.opacity(0.18) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .brSurface(radius: 16, interactive: false)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                    removal: .opacity
                ))
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: isOpen)
        .preference(key: BRSelectOpenPreference.self, value: isOpen)
        .zIndex(isOpen ? 20 : 0)
        .onAppear {
            if forceExpanded {
                expanded = true
            }
        }
        .onChange(of: forceExpanded) { _, next in
            expanded = next
        }
    }

    private var isOpen: Bool { expanded || forceExpanded }
}

struct FullRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 20
    var radius: CGFloat = BR.card
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .brSurface(radius: radius)
    }
}

struct BRField: View {
    var label: String
    var prompt: String = ""
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !label.isEmpty {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Group {
                if axis == .vertical {
                    TextField(prompt, text: $text, axis: .vertical)
                        .lineLimit(2...6)
                } else {
                    TextField(prompt, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(.body)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .brSurface(radius: BR.field, interactive: false)
        }
    }
}

struct IconCircleButton: View {
    var systemName: String
    var role: ButtonRole? = nil
    var action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.medium))
                .frame(width: 28, height: 28)
        }
        .brGlass()
        .buttonBorderShape(.circle)
        .controlSize(.small)
    }
}

struct HashCapsule: View {
    var hash: String

    var body: some View {
        Text(hash.isEmpty ? "хеш после Save" : ContentHash.short(hash))
            .font(.system(.caption, design: .monospaced).weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .brCapsule()
            .help(hash)
    }
}

struct StatusPill: View {
    var status: SlotStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status == .ACTIVE ? Color.orange : Color.green.opacity(0.85))
                .frame(width: 7, height: 7)
            Text(status == .ACTIVE ? "ACTIVE" : "idle")
                .font(.caption.weight(.semibold))
                .monospaced()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
            .brCapsule()
    }
}

struct TicketKindBadge: View {
    var kind: TicketKind

    var body: some View {
        Text(kind.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .brCapsule(tint: color.opacity(0.45))
    }

    private var color: Color {
        switch kind {
        case .process: return .blue
        case .bug: return .red
        case .migration: return .purple
        }
    }
}

struct EmptyHint: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionLabel: View {
    var title: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.headline)
        }
    }
}

struct MentionChip: View {
    var mention: Mention

    var body: some View {
        Text(label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .brCapsule(tint: color.opacity(0.4))
    }

    private var label: String {
        mention.name
    }

    private var color: Color {
        switch mention.kind {
        case .platform: return .indigo
        case .role: return .orange
        case .entity: return .purple
        case .variable: return .teal
        }
    }
}
