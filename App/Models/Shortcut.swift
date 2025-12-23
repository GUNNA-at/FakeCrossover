import Foundation

struct Shortcut: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var exePath: String
    var arguments: String
    var iconPath: String?
}
