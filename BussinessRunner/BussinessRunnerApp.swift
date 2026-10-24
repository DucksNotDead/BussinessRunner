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
                .toolbar(removing: .title)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1380, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Новый проект") {
                    workspace.createProjectFromFinder()
                }
                .keyboardShortcut("n", modifiers: .command)
                Button("Новая вкладка") {
                    workspace.createProjectFromFinder()
                }
                .keyboardShortcut("t", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Закрыть вкладку") {
                    workspace.closeSelectedProject()
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(workspace.selectedProjectID == nil)
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
