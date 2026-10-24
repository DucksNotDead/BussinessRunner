import SwiftUI

struct ProcessEditorView: View {
    @Binding var process: ProjectProcess
    @Binding var project: Project
    @EnvironmentObject private var workspace: Workspace

    var body: some View {
        HSplitView {
            editor
                .frame(minWidth: 440)
            ProcessDiagramView(process: process, project: project)
                .frame(minWidth: 300)
        }
    }

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BRCard {
                    HStack(spacing: 12) {
                        TextField("Имя процесса", text: $process.name)
                            .font(.title2.weight(.semibold))
                            .textFieldStyle(.plain)
                        Spacer()
                        Toggle(isOn: $process.isCritical) {
                            Label("Критичный", systemImage: "flag")
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        HashCapsule(hash: process.hash)
                    }
                }

                BRCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Упоминания")
                            .font(.subheadline.weight(.semibold))
                        HStack(spacing: 8) {
                            legend("_", "платформа", .indigo)
                            legend("!", "роль", .orange)
                            legend("?", "сущность", .purple)
                            legend("\"\"\"", "переменная", .teal)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                BRCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(title: "Действия", systemImage: "list.number")
                        ForEach(Array(process.actions.enumerated()), id: \.element.id) { index, _ in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 22)
                                ActionMentionField(
                                    action: $process.actions[index],
                                    project: project,
                                    forceKind: index == 0 ? workspace.snapshotMentionKind : nil
                                )
                                IconCircleButton(systemName: "xmark", role: .destructive) {
                                    process.actions.remove(at: index)
                                }
                            }
                        }
                        Button {
                            process.actions.append(ProcessAction(text: ""))
                        } label: {
                            Label("Действие", systemImage: "plus")
                        }
                        .brGlass()
                    }
                }

                BRCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(title: "Логические блоки", systemImage: "arrow.triangle.branch")
                        Text("Наследуют хеш процесса")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach($process.logicBlocks) { $block in
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Если / иначе / параллельно", text: $block.title)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .modifier(BRInset(radius: 12))
                                ForEach(process.actions) { action in
                                    Toggle(action.text.isEmpty ? "пустое действие" : action.text, isOn: bindingFor(blockID: block.id, actionID: action.id))
                                }
                            }
                        }
                        Button {
                            process.logicBlocks.append(LogicBlock(title: "Если"))
                        } label: {
                            Label("Блок", systemImage: "plus")
                        }
                        .brGlass()
                    }
                }

                BRCard {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(title: "Вложенный процесс", systemImage: "square.stack.3d.up")
                        let others = project.processes.filter { $0.id != process.id }
                        if others.isEmpty {
                            Text("Сначала создайте другой процесс.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(others) { other in
                                Toggle(other.name, isOn: nestedBinding(other.id))
                            }
                        }
                    }
                }

                BRCard {
                    stringList("Тест-кейсы", "checkmark.circle", $process.testCases, placeholder: "Ожидаемое поведение")
                }
                BRCard {
                    stringList("Критерии приёмки", "seal", $process.acceptanceCriteria, placeholder: "Для второго агента")
                }
            }
            .padding(18)
        }
    }

    private func legend(_ sample: String, _ title: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Text(sample)
                .font(.caption.monospaced())
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .fixedSize()
        .brCapsule(tint: color.opacity(0.35))
    }

    private func bindingFor(blockID: UUID, actionID: UUID) -> Binding<Bool> {
        Binding(
            get: {
                process.logicBlocks.first(where: { $0.id == blockID })?.actionIDs.contains(actionID) ?? false
            },
            set: { on in
                guard let index = process.logicBlocks.firstIndex(where: { $0.id == blockID }) else { return }
                var ids = process.logicBlocks[index].actionIDs
                if on {
                    if !ids.contains(actionID) { ids.append(actionID) }
                } else {
                    ids.removeAll { $0 == actionID }
                }
                process.logicBlocks[index].actionIDs = ids
            }
        )
    }

    private func nestedBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { process.nestedProcessIDs.contains(id) },
            set: { on in
                if on {
                    if !process.nestedProcessIDs.contains(id) { process.nestedProcessIDs.append(id) }
                } else {
                    process.nestedProcessIDs.removeAll { $0 == id }
                }
            }
        )
    }

    private func stringList(_ title: String, _ icon: String, _ items: Binding<[String]>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: title, systemImage: icon)
            ForEach(items.wrappedValue.indices, id: \.self) { index in
                HStack {
                    TextField(placeholder, text: items[index], axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .modifier(BRInset(radius: 12))
                    IconCircleButton(systemName: "xmark", role: .destructive) {
                        items.wrappedValue.remove(at: index)
                    }
                    .disabled(items.wrappedValue.count == 1)
                }
            }
            Button {
                items.wrappedValue.append("")
            } label: {
                Label("Добавить", systemImage: "plus")
            }
            .brGlass()
        }
    }
}
