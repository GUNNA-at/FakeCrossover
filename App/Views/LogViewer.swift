import AppKit
import SwiftUI

struct LogViewer: View {
    @Binding var selectedTaskID: String?
    let taskLogs: [TaskLog]
    let runningTaskIDs: Set<String>
    let onStop: (String) -> Void

    private var selectedLog: TaskLog? {
        if let id = selectedTaskID {
            return taskLogs.first(where: { $0.id == id })
        }
        return taskLogs.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Task", selection: $selectedTaskID) {
                    ForEach(taskLogs) { log in
                        Text("\(log.title) - \(log.status.rawValue)").tag(Optional(log.id))
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                if let log = selectedLog, runningTaskIDs.contains(log.id) {
                    Button("Stop") { onStop(log.id) }
                }
                Button("Copy") { copySelectedLog() }
            }

            if let log = selectedLog {
                ScrollView {
                    Text(log.lines.joined(separator: "\n"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)
            } else {
                Text("No task logs yet.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func copySelectedLog() {
        guard let log = selectedLog else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(log.lines.joined(separator: "\n"), forType: .string)
    }
}
