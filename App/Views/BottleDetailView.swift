import SwiftUI
import UniformTypeIdentifiers

struct BottleDetailView: View {
    @EnvironmentObject private var controller: AppController
    let bottle: Bottle

    @State private var showingSettings = false
    @State private var showingDeleteConfirm = false
    @State private var showingWinetricks = false
    @State private var winetricksVerb = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(bottle.name)
                        .font(.title2)
                    Text("\(bottle.winVersion.displayName) - \(bottle.arch.displayName)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button("Run...") { runExecutable() }
                    Button("Install...") { installExecutable() }
                    Button("Winetricks...") { showingWinetricks = true }
                    Button("Settings...") { showingSettings = true }
                    Button("Export...") { exportBottle() }
                    Button("Delete") { showingDeleteConfirm = true }
                        .tint(.red)
                }
            }

            HStack {
                Text("Shortcuts")
                    .font(.headline)
                Spacer()
                Button("Refresh") { controller.refreshShortcuts(for: bottle) }
            }

            if bottle.shortcuts.isEmpty {
                Text("No shortcuts detected yet. Refresh to scan Program Files.")
                    .foregroundStyle(.secondary)
            } else {
                List(bottle.shortcuts) { shortcut in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(shortcut.name)
                            Text(shortcut.exePath).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Run") {
                            Task { await controller.runShortcut(bottle: bottle, shortcut: shortcut) }
                        }
                    }
                }
                .frame(minHeight: 200)
            }

            Divider()

            Text("Task Logs")
                .font(.headline)

            LogViewer(
                selectedTaskID: $controller.selectedTaskID,
                taskLogs: controller.taskLogs,
                runningTaskIDs: controller.runningTaskIDs,
                onStop: { taskID in
                    Task { await controller.stopTask(taskID: taskID) }
                }
            )
        }
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                let ext = url.pathExtension.lowercased()
                guard ext == "exe" || ext == "msi" else { return }
                Task { await controller.runInstaller(bottle: bottle, installerURL: url) }
            }
            return true
        }
        .padding(20)
        .sheet(isPresented: $showingSettings) {
            BottleSettingsView(bottle: bottle) { updated in
                controller.updateBottle(updated)
                Task { await controller.applyWindowsVersion(bottle: updated) }
            }
        }
        .sheet(isPresented: $showingWinetricks) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Winetricks")
                    .font(.headline)
                TextField("Verb (e.g. corefonts)", text: $winetricksVerb)
                HStack {
                    Spacer()
                    Button("Cancel") { showingWinetricks = false }
                    Button("Run") {
                        Task {
                            await controller.runWinetricks(bottle: bottle, verb: winetricksVerb)
                            showingWinetricks = false
                        }
                    }
                    .disabled(winetricksVerb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 360)
        }
        .confirmationDialog("Delete Bottle?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) { controller.deleteBottle(id: bottle.id) }
        }
    }

    private func runExecutable() {
        guard let url = FilePanel.pickFile(allowedExtensions: ["exe"]) else { return }
        Task { await controller.runExe(bottle: bottle, exeURL: url) }
    }

    private func installExecutable() {
        guard let url = FilePanel.pickFile(allowedExtensions: ["exe", "msi"]) else { return }
        Task { await controller.runInstaller(bottle: bottle, installerURL: url) }
    }

    private func exportBottle() {
        guard let url = FilePanel.saveArchive(defaultName: "\(bottle.name).zip") else { return }
        controller.exportBottle(bottle, to: url)
    }
}
