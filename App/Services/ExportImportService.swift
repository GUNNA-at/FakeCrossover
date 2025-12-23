import Foundation

@MainActor
final class ExportImportService {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func exportBottle(_ bottle: Bottle, to destinationURL: URL) throws {
        let result = try ProcessRunner.run(
            "/usr/bin/ditto",
            arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", bottle.prefixPath.path, destinationURL.path]
        )
        if result.exitCode != 0 {
            throw NSError(domain: "ExportImportService", code: 1, userInfo: [NSLocalizedDescriptionKey: result.stderr])
        }
    }

    func importBottle(from archiveURL: URL, newName: String? = nil, store: BottleStore) throws -> Bottle {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let result = try ProcessRunner.run(
            "/usr/bin/ditto",
            arguments: ["-x", "-k", archiveURL.path, tempDir.path]
        )
        if result.exitCode != 0 {
            throw NSError(domain: "ExportImportService", code: 2, userInfo: [NSLocalizedDescriptionKey: result.stderr])
        }

        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        guard let folder = contents.first(where: { $0.hasDirectoryPath }) else {
            throw NSError(domain: "ExportImportService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Archive did not contain a bottle folder"])
        }
        let metadataURL = folder.appendingPathComponent("metadata.json")
        let data = try Data(contentsOf: metadataURL)
        var bottle = try decoder.decode(Bottle.self, from: data)

        let newID = UUID().uuidString
        bottle.id = newID
        bottle.name = newName ?? bottle.name
        bottle.createdAt = Date()
        bottle.updatedAt = Date()

        let destination = AppPaths.bottleFolder(id: newID)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: folder, to: destination)

        try store.addBottle(bottle)
        return bottle
    }
}
