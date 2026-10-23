import SwiftUI

struct PlatformsTab: View {
    @Binding var project: Project

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if project.platforms.isEmpty {
                    GlassCard {
                        EmptyHint(text: "Добавьте платформу. Без неё тикеты не создаются и не принимаются.")
                    }
                }
                ForEach($project.platforms) { $platform in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                Picker("Платформа", selection: $platform.kind) {
                                    ForEach(PlatformKind.allCases) { kind in
                                        Text(kind.rawValue).tag(kind)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .onChange(of: platform.kind) { _, kind in
                                    if !kind.frameworks.contains(platform.framework) {
                                        platform.framework = kind.frameworks.first ?? ""
                                    }
                                }
                                Picker("Фреймворк", selection: $platform.framework) {
                                    ForEach(platform.kind.frameworks, id: \.self) { name in
                                        Text(name).tag(name)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                Spacer()
                                HashCapsule(hash: platform.hash)
                                IconCircleButton(systemName: "trash", role: .destructive) {
                                    project.platforms.removeAll { $0.id == platform.id }
                                }
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
    }
}
