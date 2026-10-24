import SwiftUI

struct RootView: View {
    @EnvironmentObject private var workspace: Workspace

    var body: some View {
        HStack(spacing: 0) {
            CanvasSidebar()
                .frame(width: 240)
            VStack(spacing: 0) {
                ProjectTabBar()
                ZStack {
                    CanvasBackdrop()
                    if let id = workspace.selectedProjectID, workspace.selectedProject != nil {
                        CanvasView()
                            .id(id)
                    } else {
                        ContentUnavailableView(
                            "Создайте проект",
                            systemImage: "square.dashed",
                            description: Text("Нажмите + на панели вкладок, чтобы создать или выбрать папку. Save запишет туда /.harness/.")
                        )
                    }
                }
            }
        }
        .focusEffectDisabled()
        .sheet(isPresented: $workspace.presentBugSheet) {
            BugComposerSheet()
                .environmentObject(workspace)
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(alignment: .trailing, spacing: 10) {
                if let message = workspace.saveMessage, SnapshotExport.requestedDirectory == nil {
                    Text(message)
                        .font(.callout)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .brCapsule(tint: .green.opacity(0.35))
                        .onTapGesture { workspace.saveMessage = nil }
                }
                if workspace.selectedProject != nil {
                    ChangesBar()
                }
            }
            .padding(20)
        }
        .onAppear {
            NSApp.keyWindow?.makeFirstResponder(nil)
            Task { @MainActor in
                NSApp.keyWindow?.makeFirstResponder(nil)
                print("UI ready")
                if SnapshotExport.requestedDirectory == nil {
                    await workspace.connectCursor()
                    print("cursor init done")
                }
                if let directory = SnapshotExport.requestedDirectory {
                    if workspace.selectedProject == nil {
                        workspace.seedDemoIfNeeded()
                    }
                    SnapshotExport.dump(workspace: workspace, directory: directory)
                    if SnapshotExport.quitAfter {
                        NSApp.terminate(nil)
                    }
                }
            }
        }
        .alert("Harness", isPresented: Binding(
            get: { workspace.saveError != nil },
            set: { if !$0 { workspace.saveError = nil } }
        )) {
            Button("OK", role: .cancel) { workspace.saveError = nil }
        } message: {
            Text(workspace.saveError ?? "")
        }
    }

}

struct CanvasSidebar: View {
    @EnvironmentObject private var workspace: Workspace

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Канва")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(CanvasTab.allCases) { tab in
                        sidebarRow(
                            title: tab.title,
                            systemImage: tab.systemImage,
                            selected: workspace.selectedTab == tab
                        ) {
                            workspace.selectedTab = tab
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
        }
        .background(.ultraThinMaterial)
    }

    private func sidebarRow(title: String, systemImage: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Capsule()
                    .fill(selected ? Color.accentColor.opacity(0.85) : Color.clear)
                    .frame(width: 3, height: 14)
                Image(systemName: systemImage)
                    .font(.body)
                    .frame(width: 22)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(selected ? .primary : .secondary)
                Text(title)
                    .font(.body.weight(selected ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? .primary : .secondary)
            .padding(.leading, 7)
            .padding(.trailing, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                }
            }
        }
        .buttonStyle(.plain)
        .brNoFocusRing()
    }
}

struct BugComposerSheet: View {
    @EnvironmentObject private var workspace: Workspace
    @State private var title = ""
    @State private var bodyText = ""
    @State private var entities = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Новый баг")
                .font(.largeTitle.weight(.semibold))
            BRField(label: "Заголовок", prompt: "Что сломалось", text: $title)
            BRField(label: "Описание", prompt: "Шаги и ожидание", text: $bodyText, axis: .vertical)
            BRField(label: "Сущности", prompt: "User, Order", text: $entities)
            HStack {
                Spacer()
                Button("Отмена") { workspace.presentBugSheet = false }
                    .brGlass()
                Button("Создать") {
                    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    let list = entities.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    workspace.addBug(title: trimmed, body: bodyText, entities: list)
                    workspace.presentBugSheet = false
                }
                .brGlassProminent()
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(28)
        .frame(width: 480)
    }
}
