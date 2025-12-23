import Foundation

struct Runtime: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var winePath: String
    var version: String
    var rootPath: String
    var sourceURL: String?
    var installedAt: Date
}
