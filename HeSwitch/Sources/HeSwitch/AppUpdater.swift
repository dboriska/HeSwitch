import AppKit
import Foundation

public enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate(version: String)
    case updateAvailable(version: String, downloadURL: URL, releaseNotes: String)
    case downloading(progress: Double)
    case installing
    case error(String)
}

@MainActor
public final class AppUpdater: ObservableObject {
    public static let shared = AppUpdater()

    public static let currentVersion = "v1.0.10"
    private static let repo = "dboriska/HeSwitch"

    @Published public private(set) var state: UpdateState = .idle
    @Published public var autoCheckOnLaunch: Bool {
        didSet { UserDefaults.standard.set(autoCheckOnLaunch, forKey: "autoCheckUpdatesOnLaunch") }
    }

    private init() {
        self.autoCheckOnLaunch = UserDefaults.standard.object(forKey: "autoCheckUpdatesOnLaunch") as? Bool ?? true
    }

    public func checkForUpdates(silent: Bool = false) {
        state = .checking
        Task {
            do {
                guard let apiURL = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest") else {
                    if !silent { state = .error("Invalid update URL") } else { state = .idle }
                    return
                }

                var request = URLRequest(url: apiURL)
                request.setValue("HeSwitch/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
                request.timeoutInterval = 10

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    if !silent {
                        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                        state = .error("Could not reach update server (HTTP \(code))")
                    } else {
                        state = .idle
                    }
                    return
                }

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    if !silent { state = .error("Malformed release data") } else { state = .idle }
                    return
                }

                let releaseNotes = (json["body"] as? String) ?? ""
                var downloadURL: URL?

                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String, name.hasSuffix(".zip"),
                           let urlString = asset["browser_download_url"] as? String,
                           let url = URL(string: urlString) {
                            downloadURL = url
                            break
                        }
                    }
                }

                if isVersion(tagName, newerThan: Self.currentVersion), let downloadURL {
                    self.state = .updateAvailable(version: tagName, downloadURL: downloadURL, releaseNotes: releaseNotes)
                } else {
                    self.state = .upToDate(version: Self.currentVersion)
                }
            } catch {
                if !silent {
                    self.state = .error("Check failed: \(error.localizedDescription)")
                } else {
                    self.state = .idle
                }
            }
        }
    }

    public func installUpdate(downloadURL: URL, version: String) {
        state = .downloading(progress: 0.1)
        Task {
            do {
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let zipFile = tempDir.appendingPathComponent("HeSwitch.zip")

                state = .downloading(progress: 0.4)
                let (downloadedURL, _) = try await URLSession.shared.download(from: downloadURL)
                try FileManager.default.moveItem(at: downloadedURL, to: zipFile)

                state = .installing

                // Unzip downloaded archive
                let unzipProc = Process()
                unzipProc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                unzipProc.arguments = ["-q", "-o", zipFile.path, "-d", tempDir.path]
                try unzipProc.run()
                unzipProc.waitUntilExit()

                let extractedApp = tempDir.appendingPathComponent("HeSwitch.app")
                guard FileManager.default.fileExists(atPath: extractedApp.path) else {
                    state = .error("Extracted archive did not contain HeSwitch.app")
                    return
                }

                // Asynchronous update helper: waits for current process to exit,
                // replaces /Applications/HeSwitch.app using ditto (preserving code signature metadata and permissions),
                // strips quarantine flag, and launches the updated version.
                let updateScript = """
                sleep 0.8
                rm -rf /Applications/HeSwitch.app
                /usr/bin/ditto "\(extractedApp.path)" /Applications/HeSwitch.app
                /usr/bin/xattr -cr /Applications/HeSwitch.app
                open /Applications/HeSwitch.app
                """

                let updateProc = Process()
                updateProc.executableURL = URL(fileURLWithPath: "/bin/bash")
                updateProc.arguments = ["-c", updateScript]
                try updateProc.run()

                NSApplication.shared.terminate(nil)
            } catch {
                state = .error("Installation failed: \(error.localizedDescription)")
            }
        }
    }

    private func isVersion(_ remote: String, newerThan current: String) -> Bool {
        let cleanRemote = remote.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let cleanCurrent = current.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let remoteParts = cleanRemote.split(separator: ".").compactMap { Int($0) }
        let currentParts = cleanCurrent.split(separator: ".").compactMap { Int($0) }

        for (r, c) in zip(remoteParts, currentParts) {
            if r > c { return true }
            if r < c { return false }
        }
        return remoteParts.count > currentParts.count
    }
}
