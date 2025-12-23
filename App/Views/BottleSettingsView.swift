import SwiftUI

struct BottleSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let bottle: Bottle
    let onSave: (Bottle) -> Void

    @State private var name: String
    @State private var winVersion: WindowsVersion
    @State private var environmentText: String
    @State private var dllOverridesText: String

    init(bottle: Bottle, onSave: @escaping (Bottle) -> Void) {
        self.bottle = bottle
        self.onSave = onSave
        _name = State(initialValue: bottle.name)
        _winVersion = State(initialValue: bottle.winVersion)
        _environmentText = State(initialValue: Self.dictToLines(bottle.environment))
        _dllOverridesText = State(initialValue: Self.dictToLines(bottle.dllOverrides))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bottle Settings")
                .font(.headline)

            TextField("Name", text: $name)

            Picker("Windows Version", selection: $winVersion) {
                ForEach(WindowsVersion.allCases) { version in
                    Text(version.displayName).tag(version)
                }
            }

            Text("Environment variables (KEY=VALUE per line)")
                .font(.subheadline)
            TextEditor(text: $environmentText)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .frame(height: 120)

            Text("DLL overrides (dll=mode per line)")
                .font(.subheadline)
            TextEditor(text: $dllOverridesText)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .frame(height: 120)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    var updated = bottle
                    updated.name = name
                    updated.winVersion = winVersion
                    updated.environment = Self.linesToDict(environmentText)
                    updated.dllOverrides = Self.linesToDict(dllOverridesText)
                    onSave(updated)
                    dismiss()
                }
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    private static func dictToLines(_ dict: [String: String]) -> String {
        dict.keys.sorted().map { "\($0)=\(dict[$0] ?? "")" }.joined(separator: "\n")
    }

    private static func linesToDict(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        let lines = text.split(whereSeparator: \.isNewline)
        for line in lines {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                result[key] = value
            }
        }
        return result
    }
}
