import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: BottleStore
    @EnvironmentObject private var controller: AppController
    @EnvironmentObject private var runtimeManager: RuntimeManager

    @State private var selectedBottleID: String?
    @State private var searchText = ""
    @State private var sortAscending = true
    @State private var showingCreateSheet = false
    @State private var showingRuntimeInstall = false

    private var filteredBottles: [Bottle] {
        let filtered = store.bottles.filter { bottle in
            searchText.isEmpty || bottle.name.localizedCaseInsensitiveContains(searchText)
        }
        return filtered.sorted {
            sortAscending
                ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending
        }
    }

    private var selectedBottle: Bottle? {
        guard let id = selectedBottleID else { return nil }
        return store.bottles.first(where: { $0.id == id })
    }

    private var isInstallingRuntime: Bool {
        controller.taskLogs.contains {
            $0.status == .running && $0.title == "Install Runtime"
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selectedBottleID) {
                    ForEach(filteredBottles) { bottle in
                        VStack(alignment: .leading) {
                            Text(bottle.name)
                            Text(bottle.winVersion.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(bottle.id)
                    }
                }
                .searchable(text: $searchText)

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Runtime")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let runtime = runtimeManager.runtime {
                            Text("\(runtime.name) - \(runtime.version)")
                                .font(.caption2)
                        } else {
                            Text(runtimeManager.statusMessage ?? "Not detected")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                    Spacer()
                    if runtimeManager.runtime == nil {
                        Button("Install Runtime") {
                            showingRuntimeInstall = true
                        }
                        .disabled(isInstallingRuntime)
                    }
                    if isInstallingRuntime {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                    }
                    Button("Check") { Task { await controller.refreshRuntime() } }
                }
                .padding(8)

                Text("Made by GUNNA-at")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)
            }
            .toolbar {
                ToolbarItemGroup {
                    Button(action: { showingCreateSheet = true }) {
                        Label("New Bottle", systemImage: "plus")
                    }
                    Button("Import") {
                        if let url = FilePanel.pickArchive() {
                            controller.importBottle(from: url)
                        }
                    }
                    Button(sortAscending ? "Sort Z-A" : "Sort A-Z") {
                        sortAscending.toggle()
                    }
                }
            }
        } detail: {
            if let bottle = selectedBottle {
                BottleDetailView(bottle: bottle)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 12) {
                        Text("Select a bottle to get started.")
                            .font(.headline)
                        Text("Create a new bottle or import an archive.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

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
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            BottleCreationView()
        }
        .sheet(isPresented: $showingRuntimeInstall) {
            RuntimeInstallView { url in
                Task { await controller.installRuntime(from: url) }
            }
        }
        .task {
            await controller.refreshRuntime()
        }
        .alert("Error", isPresented: Binding(get: {
            controller.alertMessage != nil
        }, set: { _ in
            controller.alertMessage = nil
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(controller.alertMessage ?? "")
        }
    }
}
