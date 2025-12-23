import Combine
import Foundation

@MainActor
final class BottleStore: ObservableObject {
    @Published private(set) var bottles: [Bottle] = []

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
        AppPaths.bottlesRoot.appendingPathComponent("bottles.json")
    }

    init() {
        do {
            try AppPaths.ensureDirectories()
            try load()
        } catch {
            bottles = []
        }
    }

    func load() throws {
        if FileManager.default.fileExists(atPath: indexURL.path) {
            let data = try Data(contentsOf: indexURL)
            bottles = try decoder.decode([Bottle].self, from: data)
            return
        }

        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: AppPaths.bottlesRoot, includingPropertiesForKeys: nil)
        var loaded: [Bottle] = []
        for folder in contents where folder.hasDirectoryPath {
            let metaURL = folder.appendingPathComponent("metadata.json")
            guard fm.fileExists(atPath: metaURL.path) else { continue }
            let data = try Data(contentsOf: metaURL)
            let bottle = try decoder.decode(Bottle.self, from: data)
            loaded.append(bottle)
        }
        bottles = loaded.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        try save()
    }

    func save() throws {
        try AppPaths.ensureDirectories()
        let data = try encoder.encode(bottles)
        try data.write(to: indexURL, options: [.atomic])
        for bottle in bottles {
            try writeMetadata(bottle)
        }
    }

    func createBottle(
        name: String,
        winVersion: WindowsVersion,
        arch: BottleArch,
        runtimeID: String,
        environment: [String: String] = [:]
    ) throws -> Bottle {
        let id = UUID().uuidString
        let now = Date()
        let bottle = Bottle(
            id: id,
            name: name,
            winVersion: winVersion,
            arch: arch,
            runtimeID: runtimeID,
            createdAt: now,
            updatedAt: now,
            environment: environment,
            dllOverrides: [:],
            shortcuts: []
        )
        try FileManager.default.createDirectory(at: bottle.prefixPath, withIntermediateDirectories: true, attributes: nil)
        bottles.append(bottle)
        try save()
        return bottle
    }

    func updateBottle(_ bottle: Bottle) throws {
        guard let index = bottles.firstIndex(where: { $0.id == bottle.id }) else { return }
        var updated = bottle
        updated.updatedAt = Date()
        bottles[index] = updated
        try save()
    }

    func deleteBottle(id: String) throws {
        guard let index = bottles.firstIndex(where: { $0.id == id }) else { return }
        let bottle = bottles.remove(at: index)
        try save()
        try FileManager.default.removeItem(at: bottle.prefixPath)
    }

    func cloneBottle(id: String, newName: String) throws -> Bottle {
        guard let source = bottles.first(where: { $0.id == id }) else {
            throw NSError(domain: "BottleStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Bottle not found"])
        }
        let newID = UUID().uuidString
        let newFolder = AppPaths.bottleFolder(id: newID)
        try FileManager.default.copyItem(at: source.prefixPath, to: newFolder)
        var clone = source
        clone.id = newID
        clone.name = newName
        clone.createdAt = Date()
        clone.updatedAt = Date()
        bottles.append(clone)
        try save()
        return clone
    }

    func addBottle(_ bottle: Bottle) throws {
        bottles.append(bottle)
        try save()
    }

    private func writeMetadata(_ bottle: Bottle) throws {
        let data = try encoder.encode(bottle)
        let url = AppPaths.bottleMetadataURL(id: bottle.id)
        try data.write(to: url, options: [.atomic])
    }
}
