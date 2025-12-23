import Foundation

@MainActor
final class WineService {
    private let runtimeManager: RuntimeManager
    private let taskRunner: TaskRunner

    init(runtimeManager: RuntimeManager, taskRunner: TaskRunner) {
        self.runtimeManager = runtimeManager
        self.taskRunner = taskRunner
    }

    func createPrefix(bottle: Bottle) throws -> TaskHandle {
        let runtime = try runtimeManager.requireRuntime()
        let tool = wineTool("wineboot", runtime: runtime)
        var env = baseEnvironment(for: bottle)
        env["WINEARCH"] = bottle.arch.rawValue
        let command = runtimeManager.commandForExecutable(tool.path, arguments: tool.arguments + ["-u"])
        return try taskRunner.run(
            title: "Create Prefix",
            launchPath: command.path,
            arguments: command.arguments,
            environment: env
        )
    }

    func setWindowsVersion(bottle: Bottle) throws -> TaskHandle {
        let runtime = try runtimeManager.requireRuntime()
        let tool = wineTool("winecfg", runtime: runtime)
        let version = bottle.winVersion.rawValue
        let command = runtimeManager.commandForExecutable(tool.path, arguments: tool.arguments + ["-v", version])
        return try taskRunner.run(
            title: "Set Windows Version",
            launchPath: command.path,
            arguments: command.arguments,
            environment: baseEnvironment(for: bottle)
        )
    }

    func runInstaller(bottle: Bottle, installerURL: URL) throws -> TaskHandle {
        let runtime = try runtimeManager.requireRuntime()
        let ext = installerURL.pathExtension.lowercased()
        if ext == "msi" {
            let command = runtimeManager.commandForExecutable(runtime.winePath, arguments: ["msiexec", "/i", installerURL.path])
            return try taskRunner.run(
                title: "Install MSI",
                launchPath: command.path,
                arguments: command.arguments,
                environment: baseEnvironment(for: bottle)
            )
        }
        if ext == "exe" {
            let command = runtimeManager.commandForExecutable(runtime.winePath, arguments: [installerURL.path])
            return try taskRunner.run(
                title: "Install EXE",
                launchPath: command.path,
                arguments: command.arguments,
                environment: baseEnvironment(for: bottle)
            )
        }
        throw NSError(domain: "WineService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unsupported installer type"])
    }

    func runExe(bottle: Bottle, exeURL: URL, arguments: [String]) throws -> TaskHandle {
        let runtime = try runtimeManager.requireRuntime()
        let command = runtimeManager.commandForExecutable(runtime.winePath, arguments: [exeURL.path] + arguments)
        return try taskRunner.run(
            title: "Run EXE",
            launchPath: command.path,
            arguments: command.arguments,
            environment: baseEnvironment(for: bottle)
        )
    }

    func runWinetricks(bottle: Bottle, verb: String) throws -> TaskHandle {
        _ = try runtimeManager.requireRuntime()
        return try taskRunner.run(
            title: "Winetricks \(verb)",
            launchPath: "/usr/bin/env",
            arguments: ["winetricks", "-q", verb],
            environment: baseEnvironment(for: bottle)
        )
    }

    func scanShortcuts(bottle: Bottle) -> [Shortcut] {
        let candidates = [
            bottle.prefixPath.appendingPathComponent("drive_c/Program Files", isDirectory: true),
            bottle.prefixPath.appendingPathComponent("drive_c/Program Files (x86)", isDirectory: true)
        ]
        var shortcuts: [Shortcut] = []
        let fm = FileManager.default

        for root in candidates where fm.fileExists(atPath: root.path) {
            if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    if fileURL.pathExtension.lowercased() == "exe" {
                        let name = fileURL.deletingPathExtension().lastPathComponent
                        shortcuts.append(Shortcut(id: UUID().uuidString, name: name, exePath: fileURL.path, arguments: "", iconPath: nil))
                    }
                }
            }
        }
        return shortcuts.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
    }

    private func baseEnvironment(for bottle: Bottle) -> [String: String] {
        var env = bottle.environment
        env["WINEPREFIX"] = bottle.prefixPath.path
        if !bottle.dllOverrides.isEmpty {
            let overrides = bottle.dllOverrides.map { "\($0.key)=\($0.value)" }.joined(separator: ";")
            env["WINEDLLOVERRIDES"] = overrides
        }
        return env
    }

    private func wineTool(_ name: String, runtime: Runtime) -> (path: String, arguments: [String]) {
        let binDir = URL(fileURLWithPath: runtime.winePath).deletingLastPathComponent()
        let toolURL = binDir.appendingPathComponent(name)
        if FileManager.default.isExecutableFile(atPath: toolURL.path) {
            return (toolURL.path, [])
        }
        return (runtime.winePath, [name])
    }
}
