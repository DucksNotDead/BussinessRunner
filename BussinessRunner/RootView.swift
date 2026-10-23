import SwiftUI

struct RootView: View {
    @EnvironmentObject private var workspace: Workspace

    var body: some View {
        HStack(spacing: 0) {
            ProjectSidebar()
                .frame(width: 280)
            ZStack {
                CanvasBackdrop()
                VStack(spacing: 0) {
                    topBar
                    if workspace.selectedProjectBinding != nil {
                        CanvasView()
                    } else {
                        ContentUnavailableView(
                            "Создайте проект",
                            systemImage: "square.dashed",
                            description: Text("Новый проект откроет Finder — создайте или выберите папку. Save запишет туда /.harness/.")
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $workspace.presentBugSheet) {
            BugComposerSheet()
                .environmentObject(workspace)
        }
        .overlay(alignment: .bottomTrailing) {
            if let message = workspace.saveMessage, SnapshotExport.requestedDirectory == nil {
                Text(message)
                    .font(.callout)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .brCapsule(tint: .green.opacity(0.35))
                    .padding(20)
                    .onTapGesture { workspace.saveMessage = nil }
            }
        }
        .onAppear {
            Task { @MainActor in
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

    private var topBar: some View {
        HStack(spacing: 10) {
            if let name = workspace.selectedProject?.name {
                Text(name)
                    .font(.headline)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct ProjectSidebar: View {
    @EnvironmentObject private var workspace: Workspace

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                Text("BussinessRunner")
                    .font(.headline)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sidebarSection("Проект") {
                        ForEach(workspace.projects) { project in
                            sidebarRow(
                                title: project.name,
                                subtitle: project.repoPath.isEmpty ? "без репозитория" : URL(fileURLWithPath: project.repoPath).lastPathComponent,
                                systemImage: "shippingbox.fill",
                                selected: workspace.selectedProjectID == project.id
                            ) {
                                workspace.selectedProjectID = project.id
                            }
                        }
                    }
                    sidebarSection("Канва") {
                        ForEach(CanvasTab.allCases) { tab in
                            sidebarRow(
                                title: tab.title,
                                subtitle: nil,
                                systemImage: tab.systemImage,
                                selected: workspace.selectedTab == tab
                            ) {
                                workspace.selectedTab = tab
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }

            VStack(spacing: 10) {
                connectionChip
                Button {
                    workspace.createProjectFromFinder()
                } label: {
                    Label("Новый проект", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .brGlassProminent()
                .controlSize(.large)
            }
            .padding(14)
        }
        .background(.ultraThinMaterial)
    }

    private func sidebarSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            content()
        }
    }

    private func sidebarRow(title: String, subtitle: String?, systemImage: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.body)
                    .frame(width: 22)
                    .symbolRenderingMode(.hierarchical)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.body.weight(.medium))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, subtitle == nil ? 8 : 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(selected ? Color.accentColor.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: BR.sidebar, style: .continuous))
            .brSurface(radius: BR.sidebar, interactive: selected, tint: selected ? .accentColor : nil, apply: selected)
        }
        .buttonStyle(FullRowButtonStyle())
    }

    private var connectionChip: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(workspace.cursorSnapshot != nil ? Color.green : Color.secondary.opacity(0.45))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(workspace.cursorSnapshot != nil ? "Cursor подключён" : "Нет сессии")
                    .font(.caption.weight(.semibold))
                if workspace.apiKeyPresent {
                    Text(workspace.apiKeyMasked)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(10)
        .brSurface(radius: 14, interactive: false)
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
