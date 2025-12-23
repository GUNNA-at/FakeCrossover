import Foundation

enum RuntimeInstaller {
    static func install(
        sourceURL: URL,
        runtimesRoot: URL,
        isAppleSilicon: Bool,
        isTranslated: Bool
    ) async throws -> Runtime {
        return try await Task.detached { () throws -> Runtime in
            let fm = FileManager.default
            let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let extractDir = tempDir.appendingPathComponent("extract", isDirectory: true)
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            try fm.createDirectory(at: extractDir, withIntermediateDirectories: true, attributes: nil)
            defer { try? fm.removeItem(at: tempDir) }

            let archiveURL: URL
            if sourceURL.isFileURL {
                archiveURL = sourceURL
            } else {
                let (downloadedURL, _) = try await URLSession.shared.download(from: sourceURL)
                let destination = tempDir.appendingPathComponent(sourceURL.lastPathComponent)
                if fm.fileExists(atPath: destination.path) {
                    try fm.removeItem(at: destination)
                }
                try fm.moveItem(at: downloadedURL, to: destination)
                archiveURL = destination
            }

            try extractArchive(at: archiveURL, to: extractDir)

            let root = try findRuntimeRoot(in: extractDir)
            let wineURL = try findWineBinary(in: root)

            let runtimeID = UUID().uuidString
            let runtimeDir = runtimesRoot.appendingPathComponent(runtimeID, isDirectory: true)

            let relativeWinePath = wineURL.path.replacingOccurrences(of: root.path + "/", with: "")
            if fm.fileExists(atPath: runtimeDir.path) {
                try fm.removeItem(at: runtimeDir)
            }
            try fm.moveItem(at: root, to: runtimeDir)
            let finalWinePath = runtimeDir.appendingPathComponent(relativeWinePath).path

            try? clearQuarantine(at: runtimeDir)

            let command = commandForExecutable(
                finalWinePath,
                arguments: ["--version"],
                isAppleSilicon: isAppleSilicon,
                isTranslated: isTranslated
            )
            let versionResult = try ProcessRunner.run(command.path, arguments: command.arguments)
            let version = versionResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

            return Runtime(
                id: runtimeID,
                name: "Downloaded Wine",
                winePath: finalWinePath,
                version: version.isEmpty ? "unknown" : version,
                rootPath: runtimeDir.path,
                sourceURL: sourceURL.absoluteString,
                installedAt: Date()
            )
        }.value
    }

    private static func extractArchive(at archiveURL: URL, to destinationURL: URL) throws {
        let ext = archiveURL.pathExtension.lowercased()
        if ext == "zip" {
            let result = try ProcessRunner.run(
                "/usr/bin/ditto",
                arguments: ["-x", "-k", archiveURL.path, destinationURL.path]
            )
            if result.exitCode != 0 {
                throw NSError(domain: "RuntimeInstaller", code: 20, userInfo: [NSLocalizedDescriptionKey: result.stderr])
            }
            return
        }
        let archivePath = archiveURL.path
        let isTar = archivePath.hasSuffix(".tar") || archivePath.hasSuffix(".tar.gz") || archivePath.hasSuffix(".tgz") || archivePath.hasSuffix(".tar.xz")
        if isTar {
            let flag: String
            if archivePath.hasSuffix(".tar.gz") || archivePath.hasSuffix(".tgz") {
                flag = "z"
            } else if archivePath.hasSuffix(".tar.xz") {
                flag = "J"
            } else {
                flag = ""
            }
            let args = flag.isEmpty
                ? ["-xf", archivePath, "-C", destinationURL.path]
                : ["-x\(flag)f", archivePath, "-C", destinationURL.path]
            let result = try ProcessRunner.run("/usr/bin/tar", arguments: args)
            if result.exitCode != 0 {
                throw NSError(domain: "RuntimeInstaller", code: 21, userInfo: [NSLocalizedDescriptionKey: result.stderr])
            }
            return
        }
        throw NSError(domain: "RuntimeInstaller", code: 22, userInfo: [NSLocalizedDescriptionKey: "Unsupported runtime archive type"])
    }

    private static func findRuntimeRoot(in directory: URL) throws -> URL {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        if contents.count == 1, let only = contents.first, only.hasDirectoryPath {
            return only
        }
        return directory
    }

    private static func findWineBinary(in directory: URL) throws -> URL {
        let fm = FileManager.default
        if let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                let name = fileURL.lastPathComponent.lowercased()
                if name == "wine" || name == "wine64" {
                    if fileURL.deletingLastPathComponent().lastPathComponent == "bin" {
                        return fileURL
                    }
                }
            }
        }
        throw NSError(domain: "RuntimeInstaller", code: 23, userInfo: [NSLocalizedDescriptionKey: "Wine binary not found in runtime"])
    }

    private static func commandForExecutable(
        _ path: String,
        arguments: [String],
        isAppleSilicon: Bool,
        isTranslated: Bool
    ) -> (path: String, arguments: [String]) {
        if let arch = preferredArch(for: path, isAppleSilicon: isAppleSilicon, isTranslated: isTranslated) {
            return ("/usr/bin/arch", ["-\(arch)", path] + arguments)
        }
        return (path, arguments)
    }

    private static func preferredArch(for path: String, isAppleSilicon: Bool, isTranslated: Bool) -> String? {
        guard isAppleSilicon else { return nil }
        if path.hasPrefix("/opt/homebrew") {
            return isTranslated ? "arm64" : nil
        }
        if path.hasPrefix("/usr/local") {
            return "x86_64"
        }
        return nil
    }

    private static func clearQuarantine(at directory: URL) throws {
        _ = try ProcessRunner.run(
            "/usr/bin/xattr",
            arguments: ["-dr", "com.apple.quarantine", directory.path]
        )
    }
}
