import SwiftUI

struct PlatformsTab: View {
    @Binding var project: Project
    @EnvironmentObject private var workspace: Workspace

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach($project.platforms) { $platform in
                    PlatformCard(
                        platform: $platform,
                        project: $project,
                        forceExpandFramework: workspace.snapshotExpandedSelect && platform.kind == .webAPI
                    )
                    .zIndex(workspace.snapshotExpandedSelect && platform.kind == .webAPI ? 8 : 0)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PlatformCard: View {
    @Binding var platform: ProjectPlatform
    @Binding var project: Project
    var forceExpandFramework: Bool
    @State private var selectOpen = false

    var body: some View {
        BRCard(padding: 18, square: true) {
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
                    if kind.databases.isEmpty {
                        platform.database = ""
                    } else if !kind.databases.contains(platform.database) {
                        platform.database = kind.databases.first ?? ""
                    }
                }
                BRSelect(
                    title: "Фреймворк",
                    options: platform.kind.frameworks,
                    label: { $0 },
                    forceExpanded: forceExpandFramework,
                    selection: $platform.framework
                )
                if !platform.kind.databases.isEmpty {
                    BRSelect(
                        title: "СУБД",
                        options: platform.kind.databases,
                        label: { $0 },
                        selection: $platform.database
                    )
                }
                Spacer(minLength: 0)
                HStack {
                    HashCapsule(hash: platform.hash)
                    Spacer()
                    IconCircleButton(systemName: "trash", role: .destructive) {
                        project.platforms.removeAll { $0.id == platform.id }
                    }
                }
            }
        }
        .onPreferenceChange(BRSelectOpenKey.self) { selectOpen = $0 }
        .zIndex(selectOpen || forceExpandFramework ? 24 : 0)
    }
}
