import SwiftUI

struct ProcessDiagramView: View {
    var process: ProjectProcess
    var project: Project

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(title: "Схема", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                Text("Связи из упоминаний в действиях")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(process.actions.enumerated()), id: \.element.id) { index, action in
                    diagramNode(index: index, action: action)
                    if index < process.actions.count - 1 {
                        Image(systemName: "arrow.down")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }
                }

                if !process.logicBlocks.isEmpty {
                    Text("Логика")
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 8)
                    ForEach(process.logicBlocks) { block in
                        BRCard(padding: 14, radius: 18, tint: .orange) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(block.title).font(.subheadline.weight(.medium))
                                let linked = process.actions.filter { block.actionIDs.contains($0.id) }
                                if linked.isEmpty {
                                    Text("нет связанных действий").foregroundStyle(.secondary).font(.caption)
                                } else {
                                    ForEach(linked) { action in
                                        Text(action.text).font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }

                let nested = project.processes.filter { process.nestedProcessIDs.contains($0.id) }
                if !nested.isEmpty {
                    Text("Вложенные").font(.subheadline.weight(.semibold))
                    ForEach(nested) { child in
                        BRCard(padding: 12, radius: 16) {
                            HStack {
                                Image(systemName: "arrow.triangle.branch")
                                Text(child.name)
                                Spacer()
                                HashCapsule(hash: child.hash)
                            }
                        }
                    }
                }

                let mentions = process.actions.flatMap(\.links).map(Mention.init)
                if !mentions.isEmpty {
                    Text("Impact").font(.subheadline.weight(.semibold))
                    FlexibleMentionRow(mentions: mentions)
                }
            }
            .padding(18)
        }
    }

    private func diagramNode(index: Int, action: ProcessAction) -> some View {
        let mentions = action.links.map(Mention.init)
        return BRCard(padding: 16, radius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(index + 1). \(action.text.isEmpty ? "пустое действие" : action.text)")
                    .font(.body)
                if !mentions.isEmpty {
                    FlexibleMentionRow(mentions: mentions)
                }
            }
        }
    }
}

struct FlexibleMentionRow: View {
    var mentions: [Mention]

    var body: some View {
        HStack {
            ForEach(mentions) { mention in
                MentionChip(mention: mention)
            }
            Spacer(minLength: 0)
        }
    }
}
