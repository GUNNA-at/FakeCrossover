import SwiftUI

struct BottleCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var controller: AppController

    @State private var name = ""
    @State private var winVersion: WindowsVersion = .win10
    @State private var arch: BottleArch = .win64
    @State private var wineDebug = "-all"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create Bottle")
                .font(.headline)

            TextField("Name", text: $name)
            Picker("Windows Version", selection: $winVersion) {
                ForEach(WindowsVersion.allCases) { version in
                    Text(version.displayName).tag(version)
                }
            }
            Picker("Architecture", selection: $arch) {
                ForEach(BottleArch.allCases) { arch in
                    Text(arch.displayName).tag(arch)
                }
            }

            TextField("WINEDEBUG", text: $wineDebug)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    let env = wineDebug.isEmpty ? [:] : ["WINEDEBUG": wineDebug]
                    Task {
                        await controller.createBottle(name: name, winVersion: winVersion, arch: arch, environment: env)
                        dismiss()
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
