import SwiftUI

struct PlatformsTab: View {
    @Binding var project: Project
    @EnvironmentObject private var workspace: Workspace

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if project.platforms.isEmpty {
                    GlassCard {
                        EmptyHint(text: "Добавьте платформу. Без неё тикеты не создаются и не принимаются.")
                    }
                }
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach($project.platforms) { $platform in
                        platformCard($platform)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func platformCard(_ platform: Binding<ProjectPlatform>) -> some View {
        PlatformCard(
            platform: platform,
            project: $project,
            forceExpandFramework: workspace.snapshotExpandedSelect && platform.wrappedValue.kind == .webAPI
        )
    }
}

private struct PlatformCard: View {
    @Binding var platform: ProjectPlatform
    @Binding var project: Project
    var forceExpandFramework: Bool
    @State private var selectOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BRSelect(
                title: "Платформа",
                options: Array(PlatformKind.allCases),
                label: { $0.rawValue },
                selection: $platform.kind
            )
            .onChange(of: platform.kind) { _, kind in
                if !kind.frameworks.contains(platform.framework) {
                    platform.framework = kind.frameworks.first ?? ""
                }
            }
            BRSelect(
                title: "Фреймворк",
                options: platform.kind.frameworks,
                label: { $0 },
                forceExpanded: forceExpandFramework,
                selection: $platform.framework
            )
            Spacer(minLength: 0)
            HStack {
                HashCapsule(hash: platform.hash)
                Spacer()
                IconCircleButton(systemName: "trash", role: .destructive) {
                    project.platforms.removeAll { $0.id == platform.id }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .modifier(SquareWhenClosed(enabled: !selectOpen && !forceExpandFramework))
        .brSurface(radius: BR.card)
        .onPreferenceChange(BRSelectOpenPreference.self) { selectOpen = $0 }
        .zIndex(selectOpen || forceExpandFramework ? 8 : 0)
    }
}

private struct SquareWhenClosed: ViewModifier {
    var enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.aspectRatio(1, contentMode: .fit)
        } else {
            content
        }
    }
}
