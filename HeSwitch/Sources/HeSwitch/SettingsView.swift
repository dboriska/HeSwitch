import SwiftUI
import ServiceManagement

public struct SettingsView: View {
    @ObservedObject var model: HeSwitchModel
    @State private var newCustomWord = ""
    @State private var newExcludedWord = ""
    @State private var selectedExclusionLang: ExclusionLanguage = .english
    @State private var exclusionFilter: ExclusionLanguage? = nil
    @State private var exclusionSubTab = 0 // 0: Excluded Words, 1: Excluded Apps

    public init(model: HeSwitchModel) {
        self.model = model
    }

    public var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            behaviorTab
                .tabItem {
                    Label("Behavior", systemImage: "slider.horizontal.3")
                }

            shortcutsTab
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            exclusionsTab
                .tabItem {
                    Label("Exclusions", systemImage: "xmark.app")
                }

            dictionaryTab
                .tabItem {
                    Label("Custom Words", systemImage: "text.book.closed")
                }

            updatesTab
                .tabItem {
                    Label("Updates", systemImage: "arrow.triangle.2.circlepath.circle")
                }
        }
        .padding(20)
        .frame(width: 580, height: 490)
    }

    // MARK: - 1. General Tab
    private var generalTab: some View {
        Form {
            Section {
                Toggle("Automatic layout repair after Space / Return", isOn: $model.automaticRepair)
                Toggle("Play sound on layout switch", isOn: $model.playSound)
                Toggle("Launch at Startup (Login Items)", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
            }

            Section(header: Text("Permissions & Self-Healing")) {
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("⚠️ Permissions Needed")
                            .font(.headline)
                            .foregroundColor(.orange)
                        Text("If HeSwitch does not appear in System Settings, click 'Reveal in Finder' and drag HeSwitch.app into the Accessibility list, or click the '+' button in System Settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Button("Grant Permissions…") {
                                model.requestPermissions()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Reveal in Finder") {
                                model.revealInFinder()
                            }

                            Button("Open Settings") {
                                model.openAccessibilitySettings()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Button(action: {
                    model.resetPermissionsAndQuarantine()
                }) {
                    Label("Reset & Fix Permissions (Automated)", systemImage: "arrow.counterclockwise.circle")
                }
                .buttonStyle(.bordered)

                Text("Removes macOS quarantine flag, resets stale TCC cache, and reveals HeSwitch in Finder side-by-side with System Settings so you can easily enable it.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 2. Behavior Tab
    private var behaviorTab: some View {
        Form {
            Section(header: Text("Smart Backspace Undo")) {
                Picker("Backspace Mode:", selection: $model.smartBackspaceMode) {
                    ForEach(SmartBackspaceMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                Text("• 1-Tap Undo: Tapping Backspace immediately after an auto-repair reverts the word to the original layout (zero session blacklist).\n• Two-Stage: 1st Backspace deletes trailing space (lets you type punctuation); 2nd Backspace reverts word.\n• Disabled: Backspace acts purely as standard character deletion.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Typing Transcoding Rules")) {
                Toggle("Transcode capitalized English words typed in Hebrew layout", isOn: $model.convertCapitalizedEnglish)
                Text("Converts words typed starting with Shift (e.g. Wישא ➔ What, Hקךךם ➔ Hello, Pךקשדק ➔ Please) preserving capitalization.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Enable In-Place Selection Transcoder (⌘⇧X)", isOn: $model.enableSelectionTranscoder)
                Text("Select any text anywhere and press Cmd+Shift+X to invert layout in-place.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 3. Shortcuts Tab
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

            Section(header: Text("Selection Transcoder")) {
                HStack {
                    Text("Invert Selected Text:")
                    Spacer()
                    Text("⌘ + Shift + X")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(5)
                }

                Text("Works in all applications: browsers, Slack, Telegram, Notes, Word, and terminals. Automatically switches keyboard layout.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 4. Exclusions Tab
    private var exclusionsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Exclusion Type", selection: $exclusionSubTab) {
                Text("Excluded Words (Blacklist)").tag(0)
                Text("Excluded Applications").tag(1)
            }
            .pickerStyle(.segmented)

            if exclusionSubTab == 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("These words will NEVER be converted automatically when typed in the specified language:")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        TextField("Word to ignore (e.g. ls, git, דג)", text: $newExcludedWord)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: newExcludedWord) { newValue in
                                if newValue.unicodeScalars.contains(where: { (0x0590...0x05FF).contains($0.value) }) {
                                    selectedExclusionLang = .hebrew
                                } else if newValue.unicodeScalars.contains(where: { $0.isASCII && $0.isLetter }) {
                                    selectedExclusionLang = .english
                                }
                            }

                        Picker("", selection: $selectedExclusionLang) {
                            Text("English").tag(ExclusionLanguage.english)
                            Text("Hebrew").tag(ExclusionLanguage.hebrew)
                            Text("Both").tag(ExclusionLanguage.any)
                        }
                        .frame(width: 95)

                        Button("Add") {
                            if model.addExcludedWord(newExcludedWord, language: selectedExclusionLang) {
                                newExcludedWord = ""
                            }
                        }
                        .disabled(newExcludedWord.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button("Reset Defaults") {
                            model.resetExcludedWords()
                        }
                    }

                    HStack(spacing: 6) {
                        Text("Filter:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("All (\(model.excludedWordItems.count))") {
                            exclusionFilter = nil
                        }
                        .buttonStyle(.bordered)
                        .tint(exclusionFilter == nil ? .accentColor : .secondary)
                        .controlSize(.small)

                        Button("English (\(model.excludedWordItems.filter { $0.language == .english || $0.language == .any }.count))") {
                            exclusionFilter = .english
                        }
                        .buttonStyle(.bordered)
                        .tint(exclusionFilter == .english ? .blue : .secondary)
                        .controlSize(.small)

                        Button("Hebrew (\(model.excludedWordItems.filter { $0.language == .hebrew || $0.language == .any }.count))") {
                            exclusionFilter = .hebrew
                        }
                        .buttonStyle(.bordered)
                        .tint(exclusionFilter == .hebrew ? .orange : .secondary)
                        .controlSize(.small)
                    }

                    let filteredItems = model.excludedWordItems.filter { item in
                        guard let filter = exclusionFilter else { return true }
                        return item.language == filter || item.language == .any
                    }

                    List {
                        ForEach(filteredItems) { item in
                            HStack {
                                Text(item.word)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Text(item.language.badge)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(badgeColor(for: item.language))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                                Button(action: { model.removeExcludedWord(item.word, language: item.language) }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            } else {
                Text("Automatic repair is disabled in these applications:")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                HStack {
                    Menu("+ Add Running Application…") {
                        ForEach(model.runningApplications, id: \.bundleID) { app in
                            Button(app.name) {
                                _ = model.addExcludedApplication(bundleID: app.bundleID, name: app.name)
                            }
                        }
                    }
                    Spacer()
                }

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
            }
        }
    }

    // MARK: - 5. Custom Words Tab
    private var dictionaryTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Words in this list are treated as verified high-priority vocabulary:")
                .font(.footnote)
                .foregroundColor(.secondary)

            HStack {
                TextField("Add word (English or Hebrew)", text: $newCustomWord)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    if model.addCustomWord(newCustomWord) {
                        newCustomWord = ""
                    }
                }
                .disabled(newCustomWord.trimmingCharacters(in: .whitespaces).isEmpty)
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

    // MARK: - 6. Updates Tab
    private var updatesTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .resizable()
                    .frame(width: 44, height: 44)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("HeSwitch")
                        .font(.title2.bold())
                    Text("Current Version: \(AppUpdater.currentVersion)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            switch model.updater.state {
            case .idle:
                Text("Click the button below to check for software updates.")
                    .foregroundColor(.secondary)

            case .checking:
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Checking GitHub for the latest release…")
                }

            case .upToDate(let version):
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("HeSwitch \(version) is up to date!")
                        .fontWeight(.medium)
                }

            case .updateAvailable(let version, let url, let notes):
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("New Version Available: \(version)")
                            .font(.headline)
                    }

                    if !notes.isEmpty {
                        ScrollView {
                            Text(notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 120)
                        .padding(8)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(6)
                    }

                    Button(action: {
                        model.updater.installUpdate(downloadURL: url, version: version)
                    }) {
                        Label("Download & Install Update Now", systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }

            case .downloading(let progress):
                VStack(alignment: .leading, spacing: 8) {
                    Text("Downloading update asset…")
                    ProgressView(value: progress)
                }

            case .installing:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Installing update and restarting HeSwitch…")
                }

            case .error(let message):
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(message)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            Divider()

            HStack {
                Toggle("Automatically check for updates on startup", isOn: Binding(
                    get: { model.updater.autoCheckOnLaunch },
                    set: { model.updater.autoCheckOnLaunch = $0 }
                ))

                Spacer()

                Button("Check for Updates Now") {
                    model.updater.checkForUpdates(silent: false)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func badgeColor(for lang: ExclusionLanguage) -> Color {
        switch lang {
        case .english: return .blue
        case .hebrew: return .orange
        case .any: return .gray
        }
    }
}
