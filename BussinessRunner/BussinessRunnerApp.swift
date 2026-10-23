import AppKit
import SwiftUI

@main
struct Entrypoint {
    @MainActor
    static func main() {
        setbuf(stdout, nil)
        setbuf(stderr, nil)
        if CommandLine.arguments.contains("--self-test") {
            exit(Int32(SelfTest.run()))
        }
        if let directory = SnapshotExport.requestedDirectory {
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
            let workspace = Workspace()
            if workspace.selectedProject == nil {
                workspace.seedDemoIfNeeded()
            }
            if CommandLine.arguments.contains("--demo-save") {
                workspace.saveSelected()
            }
            SnapshotExport.dump(workspace: workspace, directory: directory)
            exit(0)
        }
        BussinessRunnerApp.main()
    }
}

struct BussinessRunnerApp: App {
    @StateObject private var workspace = Workspace()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(workspace)
                .frame(minWidth: 1180, minHeight: 760)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1380, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Новый проект") {
                    workspace.presentNewProject = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu("Harness") {
                Button("Сохранить в /.harness/") {
                    workspace.saveSelected()
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
    }
}
