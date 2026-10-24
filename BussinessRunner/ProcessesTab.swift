import SwiftUI

struct ProcessesTab: View {
    @Binding var project: Project
    @EnvironmentObject private var workspace: Workspace

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
                    description: Text("Выберите процесс слева или нажмите + в заголовке.")
                )
            }
        }
        .padding(.trailing, 8)
        .padding(.bottom, 8)
    }

    private var processList: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                            .contentShape(Rectangle())
                            .background(
                                workspace.editingProcessID == process.id
                                    ? Color.primary.opacity(0.10)
                                    : Color.primary.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                        }
                        .buttonStyle(FullRowButtonStyle())
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
                .padding(.top, 10)
            }
        }
    }
}
