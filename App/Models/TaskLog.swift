import Foundation

enum TaskStatus: String, Codable {
    case running
    case success
    case failed
    case cancelled
}

struct TaskLog: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var status: TaskStatus
    var startedAt: Date
    var endedAt: Date?
    var lines: [String]
    var exitCode: Int32?
}
