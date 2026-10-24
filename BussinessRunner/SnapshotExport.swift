import AppKit
import SwiftUI

enum SnapshotExport {
    static var requestedDirectory: URL? {
        guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--snapshot-dir=") }) else { return nil }
        return URL(fileURLWithPath: String(arg.dropFirst("--snapshot-dir=".count)), isDirectory: true)
    }

    static var quitAfter: Bool {
        CommandLine.arguments.contains("--quit-after-snapshot")
    }

    @MainActor
    static func dump(workspace: Workspace, directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        print("SNAPSHOT start")
        if workspace.selectedProject == nil || workspace.selectedProject?.platforms.isEmpty == true {
            workspace.seedDemoIfNeeded()
        }
        let size = CGSize(width: 1440, height: 900)

        workspace.selectedTab = .processes
        workspace.editingProcessID = workspace.selectedProject?.processes.first?.id
        workspace.changesBarExpanded = false
        workspace.snapshotExpandedSelect = false
        write(RootView().environmentObject(workspace), size: size, to: directory.appendingPathComponent("01-process-editor.png"))

        workspace.snapshotMentionKind = .platform
        write(RootView().environmentObject(workspace), size: size, to: directory.appendingPathComponent("07-mention-search.png"))
        workspace.snapshotMentionKind = nil

        workspace.selectedTab = .platforms
        workspace.snapshotExpandedSelect = true
        write(RootView().environmentObject(workspace), size: size, to: directory.appendingPathComponent("06-platforms.png"))
        workspace.snapshotExpandedSelect = false

        workspace.selectedTab = .entities
        write(RootView().environmentObject(workspace), size: size, to: directory.appendingPathComponent("03-entities.png"))

        workspace.selectedTab = .tickets
        write(RootView().environmentObject(workspace), size: size, to: directory.appendingPathComponent("04-tickets.png"))

        workspace.selectedTab = .roles
        write(RootView().environmentObject(workspace), size: size, to: directory.appendingPathComponent("05-roles.png"))

        workspace.selectedTab = .processes
        workspace.changesBarExpanded = true
        write(RootView().environmentObject(workspace), size: size, to: directory.appendingPathComponent("08-changes-bar.png"))
        workspace.changesBarExpanded = false

        if let id = workspace.selectedProjectID,
           let index = workspace.projects.firstIndex(where: { $0.id == id }) {
            let saved = workspace.projects[index]
            workspace.projects[index].platforms = []
            workspace.selectedTab = .platforms
            write(RootView().environmentObject(workspace), size: size, to: directory.appendingPathComponent("09-empty-tab.png"))
            workspace.projects[index] = saved
        }

        print("SNAPSHOT_OK \(directory.path)")
    }

    @MainActor
    private static func write<V: View>(_ view: V, size: CGSize, to url: URL) {
        let hosted = view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark)
            .preferredColorScheme(.dark)
        let nsView = NSHostingView(rootView: hosted)
        nsView.frame = NSRect(origin: .zero, size: size)
        nsView.wantsLayer = true
        nsView.layoutSubtreeIfNeeded()
        guard let rep = nsView.bitmapImageRepForCachingDisplay(in: nsView.bounds) else {
            fputs("snapshot failed \(url.lastPathComponent): no bitmap\n", stderr)
            return
        }
        nsView.cacheDisplay(in: nsView.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            fputs("snapshot failed \(url.lastPathComponent): no png\n", stderr)
            return
        }
        do {
            try png.write(to: url)
            print("wrote \(url.path) (\(png.count) bytes)")
        } catch {
            fputs("snapshot write \(url.lastPathComponent): \(error)\n", stderr)
        }
    }
}
