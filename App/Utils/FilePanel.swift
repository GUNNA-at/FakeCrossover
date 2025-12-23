import AppKit
import Foundation

enum FilePanel {
    static func pickFile(allowedExtensions: [String]) -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedFileTypes = allowedExtensions
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func pickArchive() -> URL? {
        pickFile(allowedExtensions: ["zip"])
    }

    static func saveArchive(defaultName: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["zip"]
        panel.nameFieldStringValue = defaultName
        return panel.runModal() == .OK ? panel.url : nil
    }
}
