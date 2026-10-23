import SwiftUI

struct ProcessesTab: View {
    @Binding var project: Project
    @EnvironmentObject private var workspace: Workspace
    @State private var draftName = ""

    var body: some View {
        HSplitView {
            processList
                .frame(minWidth: workspace.editingProcessID == nil ? 280 : 200, idealWidth: workspace.editingProcessID == nil ? 300 : 220)
            if let processID = workspace.editingProcessID,
               let index = project.processes.firstIndex(where: { $0.id == processID }) {
                ProcessEditorView(process: $project.processes[index], project: $project)
            } else {
                ContentUnavailableView(
                    "Процесс",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("Выберите процесс слева или создайте новый — список сожмётся.")
                )
            }
        }
        .padding(.trailing, 8)
        .padding(.bottom, 8)
    }

    private var processList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Процессы")
                .font(.headline)
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 10)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(project.processes) { process in
                        Button {
                            workspace.editingProcessID = process.id
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(process.name)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if process.isCritical {
                                        Image(systemName: "flag.fill")
                                            .foregroundStyle(.red)
                                            .font(.caption)
                                    }
                                }
                                HashCapsule(hash: process.hash)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .brSurface(
                                radius: 18,
                                tint: workspace.editingProcessID == process.id ? .accentColor : nil
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Удалить", role: .destructive) {
                                project.processes.removeAll { $0.id == process.id }
                                if workspace.editingProcessID == process.id {
                                    workspace.editingProcessID = nil
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
            }
            HStack(spacing: 8) {
                TextField("Имя процесса", text: $draftName)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .brSurface(radius: 12, interactive: false)
                    .onSubmit(addProcess)
                Button(action: addProcess) {
                    Image(systemName: "plus")
                }
                .brGlassProminent()
                .disabled(draftName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(14)
        }
    }

    private func addProcess() {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let process = ProjectProcess(
            name: name,
            actions: [ProcessAction(text: "")],
            testCases: [""],
            acceptanceCriteria: [""]
        )
        project.processes.append(process)
        workspace.editingProcessID = process.id
        draftName = ""
        workspace.persist()
    }
}
