import SwiftUI
import ServiceManagement

public struct SettingsView: View {
    @ObservedObject var model: HeSwitchModel
    @State private var newWord = ""

    public init(model: HeSwitchModel) {
        self.model = model
    }

    public var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            shortcutsTab
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            dictionaryTab
                .tabItem {
                    Label("Custom Words", systemImage: "text.book.closed")
                }

            exclusionsTab
                .tabItem {
                    Label("Exclusions", systemImage: "xmark.app")
                }
        }
        .padding(20)
        .frame(width: 520, height: 400)
    }

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Automatic layout repair after Space / Return", isOn: $model.automaticRepair)
                Toggle("Play sound on layout switch", isOn: $model.playSound)
                Toggle("Launch at Login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
            }

            Section(header: Text("Permissions")) {
                HStack {
                    Text("Accessibility Access:")
                    Spacer()
                    Text(model.hasAccessibilityAccess ? "Granted ✓" : "Missing ✗")
                        .foregroundColor(model.hasAccessibilityAccess ? .green : .red)
                }
                HStack {
                    Text("Input Monitoring Access:")
                    Spacer()
                    Text(model.hasInputMonitoringAccess ? "Granted ✓" : "Missing ✗")
                        .foregroundColor(model.hasInputMonitoringAccess ? .green : .red)
                }

                if !model.hasRequiredAccess {
                    Button("Grant System Permissions…") {
                        model.requestPermissions()
                    }
                }
            }
        }
    }

    private var shortcutsTab: some View {
        Form {
            Section(header: Text("Manual Conversion Shortcuts")) {
                Picker("Repair Previous Word:", selection: Binding(
                    get: {
                        if case .doubleTap(let mod) = model.previousWordShortcut { return mod }
                        return .shift
                    },
                    set: { model.setPreviousWordShortcut(.doubleTap($0)) }
                )) {
                    ForEach(DoubleTapModifier.allCases, id: \.self) { mod in
                        Text("Double-tap \(mod.rawValue)").tag(mod)
                    }
                }

                Text("Converts the word directly before the cursor or current selection and switches layout between English and Hebrew.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var dictionaryTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Words in this list are never replaced automatically and are always treated as valid.")
                .font(.footnote)
                .foregroundColor(.secondary)

            HStack {
                TextField("Add word (English or Hebrew)", text: $newWord)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    if model.addCustomWord(newWord) {
                        newWord = ""
                    }
                }
                .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            List {
                ForEach(model.customWords, id: \.self) { word in
                    HStack {
                        Text(word)
                        Spacer()
                        Button(action: { model.removeCustomWord(word) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    private var exclusionsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Automatic repair is disabled in these applications:")
                .font(.footnote)
                .foregroundColor(.secondary)

            List {
                ForEach(model.excludedApplications) { app in
                    HStack {
                        Text(app.name)
                        Spacer()
                        Text(app.bundleID)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button(action: { model.removeExcludedApplication(app.bundleID) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            Button("Add Application…") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.application]
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                if panel.runModal() == .OK, let url = panel.url {
                    if let bundle = Bundle(url: url),
                       let bundleID = bundle.bundleIdentifier {
                        let name = bundle.infoDictionary?["CFBundleName"] as? String ?? url.deletingPathExtension().lastPathComponent
                        _ = model.addExcludedApplication(bundleID: bundleID, name: name)
                    }
                }
            }
        }
    }
}
