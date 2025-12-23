import Combine
import Foundation

@MainActor
final class AppController: ObservableObject {
    @Published private(set) var taskLogs: [TaskLog] = []
    @Published private(set) var runningTaskIDs: Set<String> = []
    @Published var selectedTaskID: String?
    @Published var alertMessage: String?

    let store: BottleStore
    let runtimeManager: RuntimeManager
    let taskRunner: TaskRunner
    let wineService: WineService
    let exportImportService: ExportImportService

    private var cancelledTaskIDs: Set<String> = []

    init(store: BottleStore, runtimeManager: RuntimeManager, taskRunner: TaskRunner) {
        self.store = store
        self.runtimeManager = runtimeManager
        self.taskRunner = taskRunner
        self.wineService = WineService(runtimeManager: runtimeManager, taskRunner: taskRunner)
        self.exportImportService = ExportImportService()
    }

    func refreshRuntime() async {
        await runtimeManager.detectRuntime()
    }

    func installRuntime(from url: URL) async {
        let logID = startLog(title: "Install Runtime")
        do {
            guard runtimeManager.runtime == nil else {
                appendLogLine(taskID: logID, line: "Runtime already installed.")
                finishLog(taskID: logID, status: .success, exitCode: 0)
                return
            }
            appendLogLine(taskID: logID, line: "Installing runtime...")
            let runtime = try await runtimeManager.installRuntime(from: url)
            appendLogLine(taskID: logID, line: "Installed: \(runtime.name) \(runtime.version)")
            finishLog(taskID: logID, status: .success, exitCode: 0)
        } catch {
            appendLogLine(taskID: logID, line: "Error: \(error.localizedDescription)")
            finishLog(taskID: logID, status: .failed, exitCode: 1)
            alertMessage = error.localizedDescription
        }
    }

    func createBottle(
        name: String,
        winVersion: WindowsVersion,
        arch: BottleArch,
        environment: [String: String]
    ) async {
        do {
            let runtime = try runtimeManager.requireRuntime()
            let bottle = try store.createBottle(
                name: name,
                winVersion: winVersion,
                arch: arch,
                runtimeID: runtime.id,
                environment: environment
            )
            let boot = try wineService.createPrefix(bottle: bottle)
            let bootExit = await runTask(boot)
            guard bootExit == 0 else { return }
            let cfg = try wineService.setWindowsVersion(bottle: bottle)
            _ = await runTask(cfg)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func deleteBottle(id: String) {
        do {
            try store.deleteBottle(id: id)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func cloneBottle(id: String, newName: String) {
        do {
            _ = try store.cloneBottle(id: id, newName: newName)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func refreshShortcuts(for bottle: Bottle) {
        let shortcuts = wineService.scanShortcuts(bottle: bottle)
        var updated = bottle
        updated.shortcuts = shortcuts
        do {
            try store.updateBottle(updated)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func updateBottle(_ bottle: Bottle) {
        do {
            try store.updateBottle(bottle)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func applyWindowsVersion(bottle: Bottle) async {
        do {
            let handle = try wineService.setWindowsVersion(bottle: bottle)
            _ = await runTask(handle)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func runInstaller(bottle: Bottle, installerURL: URL) async {
        do {
            let handle = try wineService.runInstaller(bottle: bottle, installerURL: installerURL)
            _ = await runTask(handle)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func runExe(bottle: Bottle, exeURL: URL) async {
        do {
            let handle = try wineService.runExe(bottle: bottle, exeURL: exeURL, arguments: [])
            _ = await runTask(handle)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func runWinetricks(bottle: Bottle, verb: String) async {
        do {
            let handle = try wineService.runWinetricks(bottle: bottle, verb: verb)
            _ = await runTask(handle)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func runShortcut(bottle: Bottle, shortcut: Shortcut) async {
        do {
            let handle = try wineService.runExe(bottle: bottle, exeURL: URL(fileURLWithPath: shortcut.exePath), arguments: shortcut.arguments.isEmpty ? [] : [shortcut.arguments])
            _ = await runTask(handle)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func exportBottle(_ bottle: Bottle, to destinationURL: URL) {
        do {
            try exportImportService.exportBottle(bottle, to: destinationURL)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func importBottle(from archiveURL: URL) {
        do {
            _ = try exportImportService.importBottle(from: archiveURL, store: store)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func stopTask(taskID: String) async {
        cancelledTaskIDs.insert(taskID)
        await taskRunner.terminate(taskID: taskID)
    }

    private func runTask(_ handle: TaskHandle) async -> Int32 {
        let log = TaskLog(
            id: handle.id,
            title: handle.title,
            status: .running,
            startedAt: Date(),
            endedAt: nil,
            lines: [],
            exitCode: nil
        )
        taskLogs.insert(log, at: 0)
        runningTaskIDs.insert(handle.id)
        selectedTaskID = handle.id

        var exitCode: Int32 = 0
        for await event in handle.stream {
            switch event {
            case .output(let output):
                if let index = taskLogs.firstIndex(where: { $0.id == handle.id }) {
                    taskLogs[index].lines.append(output.line)
                    if taskLogs[index].lines.count > 2000 {
                        taskLogs[index].lines.removeFirst(taskLogs[index].lines.count - 2000)
                    }
                }
            case .finished(let code):
                exitCode = code
            }
        }

        if let index = taskLogs.firstIndex(where: { $0.id == handle.id }) {
            taskLogs[index].endedAt = Date()
            taskLogs[index].exitCode = exitCode
            if cancelledTaskIDs.contains(handle.id) {
                taskLogs[index].status = .cancelled
                cancelledTaskIDs.remove(handle.id)
            } else {
                taskLogs[index].status = exitCode == 0 ? .success : .failed
            }
        }
        runningTaskIDs.remove(handle.id)
        return exitCode
    }

    private func startLog(title: String) -> String {
        let id = UUID().uuidString
        let log = TaskLog(
            id: id,
            title: title,
            status: .running,
            startedAt: Date(),
            endedAt: nil,
            lines: [],
            exitCode: nil
        )
        taskLogs.insert(log, at: 0)
        runningTaskIDs.insert(id)
        selectedTaskID = id
        return id
    }

    private func appendLogLine(taskID: String, line: String) {
        guard let index = taskLogs.firstIndex(where: { $0.id == taskID }) else { return }
        taskLogs[index].lines.append(line)
    }

    private func finishLog(taskID: String, status: TaskStatus, exitCode: Int32) {
        guard let index = taskLogs.firstIndex(where: { $0.id == taskID }) else { return }
        taskLogs[index].status = status
        taskLogs[index].endedAt = Date()
        taskLogs[index].exitCode = exitCode
        runningTaskIDs.remove(taskID)
    }
}
