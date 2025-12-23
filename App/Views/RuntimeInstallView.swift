import SwiftUI

struct RuntimeInstallView: View {
    @Environment(\.dismiss) private var dismiss
    let onInstall: (URL) -> Void

    @State private var urlText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Install Wine Runtime")
                .font(.headline)

            TextField("Runtime URL (zip or tar.*)", text: $urlText)

            HStack {
                Button("Choose Local Archive...") {
                    if let url = FilePanel.pickFile(allowedExtensions: ["zip", "tar", "gz", "xz", "tgz"]) {
                        onInstall(url)
                        dismiss()
                    }
                }
                Spacer()
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Install") {
                    guard let url = resolveURL(from: urlText) else { return }
                    onInstall(url)
                    dismiss()
                }
                .disabled(resolveURL(from: urlText) == nil)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func resolveURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed)
        }
        return URL(string: trimmed)
    }
}
