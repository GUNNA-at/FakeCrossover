import Foundation

enum WindowsVersion: String, Codable, CaseIterable, Identifiable {
    case win10 = "win10"
    case win11 = "win11"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .win10: return "Windows 10"
        case .win11: return "Windows 11"
        }
    }
}

enum BottleArch: String, Codable, CaseIterable, Identifiable {
    case win64 = "win64"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .win64: return "64-bit"
        }
    }
}

struct Bottle: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var winVersion: WindowsVersion
    var arch: BottleArch
    var runtimeID: String
    var createdAt: Date
    var updatedAt: Date
    var environment: [String: String]
    var dllOverrides: [String: String]
    var shortcuts: [Shortcut]

    var prefixPath: URL {
        AppPaths.bottleFolder(id: id)
    }
}
