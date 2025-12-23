import Foundation

enum AppPaths {
    static let appName = "FakeCrossover"

    static var appSupportRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(appName, isDirectory: true)
    }

    static var bottlesRoot: URL {
        appSupportRoot.appendingPathComponent("Bottles", isDirectory: true)
    }

    static var runtimesRoot: URL {
        appSupportRoot.appendingPathComponent("Runtimes", isDirectory: true)
    }

    static var logsRoot: URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return library.appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(appName, isDirectory: true)
    }

    static func bottleFolder(id: String) -> URL {
        bottlesRoot.appendingPathComponent(id, isDirectory: true)
    }

    static func bottleMetadataURL(id: String) -> URL {
        bottleFolder(id: id).appendingPathComponent("metadata.json")
    }

    static func logsURL(taskID: String) -> URL {
        logsRoot.appendingPathComponent("\(taskID).log")
    }

    static func ensureDirectories() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: appSupportRoot, withIntermediateDirectories: true, attributes: nil)
        try fm.createDirectory(at: bottlesRoot, withIntermediateDirectories: true, attributes: nil)
        try fm.createDirectory(at: runtimesRoot, withIntermediateDirectories: true, attributes: nil)
        try fm.createDirectory(at: logsRoot, withIntermediateDirectories: true, attributes: nil)
    }
}
