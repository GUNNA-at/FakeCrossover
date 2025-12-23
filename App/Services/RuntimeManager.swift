import Combine
import Foundation

@MainActor
final class RuntimeManager: ObservableObject {
    @Published private(set) var runtime: Runtime?
    @Published private(set) var runtimes: [Runtime] = []
    @Published private(set) var statusMessage: String?
    @Published private(set) var isChecking = false

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private var indexURL: URL {
        AppPaths.runtimesRoot.appendingPathComponent("runtimes.json")
    }

    init() {
        do {
            try AppPaths.ensureDirectories()
            try loadRuntimes()
        } catch {
            runtimes = []
        }
    }

    func detectRuntime() async {
        isChecking = true
        defer { isChecking = false }

        do {
            try loadRuntimes()
            if let installed = runtimes.first {
                runtime = installed
                statusMessage = nil
                return
            }
            if let path = findWinePath() {
                let command = commandForExecutable(path, arguments: ["--version"])
                let result = try ProcessRunner.run(command.path, arguments: command.arguments)
                if result.exitCode == 0 {
                    let version = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                    runtime = Runtime(
                        id: "homebrew-wine",
                        name: "Homebrew Wine",
                        winePath: path,
                        version: version.isEmpty ? "unknown" : version,
                        rootPath: "",
                        sourceURL: nil,
                        installedAt: Date()
                    )
                    statusMessage = nil
                    return
                }
            }
            runtime = nil
            statusMessage = "No runtime installed. Install a Wine runtime."
        } catch {
            runtime = nil
            statusMessage = "Wine detection failed: \(error.localizedDescription)"
        }
    }

    func requireRuntime() throws -> Runtime {
        if let runtime {
            return runtime
        }
        throw NSError(domain: "RuntimeManager", code: 1, userInfo: [NSLocalizedDescriptionKey: statusMessage ?? "Wine runtime missing"])
    }

    func installRuntime(from sourceURL: URL) async throws -> Runtime {
        try AppPaths.ensureDirectories()
        let root = AppPaths.runtimesRoot
        let isAppleSilicon = Platform.isAppleSilicon
        let isTranslated = Platform.isTranslated

        let installed = try await RuntimeInstaller.install(
            sourceURL: sourceURL,
            runtimesRoot: root,
            isAppleSilicon: isAppleSilicon,
            isTranslated: isTranslated
        )

        runtimes = [installed]
        runtime = installed
        try saveRuntimes()
        return installed
    }

    private func findWinePath() -> String? {
        let fm = FileManager.default
        let candidates = [
            "/opt/homebrew/bin/wine",
            "/usr/local/bin/wine"
        ]
        for path in candidates where fm.fileExists(atPath: path) {
            return path
        }
        if let which = try? ProcessRunner.run("/usr/bin/which", arguments: ["wine"]),
           which.exitCode == 0 {
            let path = which.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if let normalized = normalizePath(path, fileManager: fm) {
                return normalized
            }
        }
        return nil
    }

    private func loadRuntimes() throws {
        if FileManager.default.fileExists(atPath: indexURL.path) {
            let data = try Data(contentsOf: indexURL)
            runtimes = try decoder.decode([Runtime].self, from: data)
            return
        }
        runtimes = []
    }

    private func saveRuntimes() throws {
        let data = try encoder.encode(runtimes)
        try data.write(to: indexURL, options: [.atomic])
    }

    func findBrewPath() -> String? {
        let fm = FileManager.default
        let env = ProcessInfo.processInfo.environment
        if let brewFile = env["HOMEBREW_BREW_FILE"],
           let normalized = normalizePath(brewFile, fileManager: fm) {
            return normalized
        }
        if let prefix = env["HOMEBREW_PREFIX"] {
            let normalized = prefix.hasSuffix("/bin") ? "\(prefix)/brew" : "\(prefix)/bin/brew"
            if let normalized = normalizePath(normalized, fileManager: fm) {
                return normalized
            }
        }
        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew"
        ]
        for path in candidates where fm.fileExists(atPath: path) {
            return path
        }
        if let which = try? ProcessRunner.run("/usr/bin/which", arguments: ["brew"]),
           which.exitCode == 0 {
            let path = which.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if let normalized = normalizePath(path, fileManager: fm) {
                return normalized
            }
        }
        if let shell = try? ProcessRunner.run("/bin/zsh", arguments: ["-lc", "command -v brew"]),
           shell.exitCode == 0 {
            let path = shell.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if let normalized = normalizePath(path, fileManager: fm) {
                return normalized
            }
        }
        if Platform.isAppleSilicon {
            return "/opt/homebrew/bin/brew"
        }
        return nil
    }

    func commandForExecutable(_ path: String, arguments: [String] = []) -> (path: String, arguments: [String]) {
        if let arch = preferredArch(for: path) {
            return ("/usr/bin/arch", ["-\(arch)", path] + arguments)
        }
        return (path, arguments)
    }

    private func preferredArch(for path: String) -> String? {
        guard Platform.isAppleSilicon else { return nil }
        if path.hasPrefix("/opt/homebrew") {
            return Platform.isTranslated ? "arm64" : nil
        }
        if path.hasPrefix("/usr/local") {
            return "x86_64"
        }
        return nil
    }

    private func normalizePath(_ path: String, fileManager: FileManager) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }
        guard fileManager.fileExists(atPath: trimmed) else { return nil }
        return trimmed
    }
}
