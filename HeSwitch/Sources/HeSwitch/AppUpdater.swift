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

    public static let currentVersion = "v1.0.16"
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
                // 1. Primary check: query raw install.sh from main branch for latest target version
                let scriptURL = URL(string: "https://raw.githubusercontent.com/\(Self.repo)/main/install.sh")!
                var scriptRequest = URLRequest(url: scriptURL)
                scriptRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                scriptRequest.timeoutInterval = 8

                if let (scriptData, scriptResp) = try? await URLSession.shared.data(for: scriptRequest),
                   let httpResp = scriptResp as? HTTPURLResponse, httpResp.statusCode == 200,
                   let scriptText = String(data: scriptData, encoding: .utf8) {
                    if let range = scriptText.range(of: "TARGET_VERSION=\"([^\"]+)\"", options: .regularExpression) {
                        let fullMatch = String(scriptText[range])
                        let remoteVer = fullMatch.replacingOccurrences(of: "TARGET_VERSION=\"", with: "").replacingOccurrences(of: "\"", with: "")
                        if isVersion(remoteVer, newerThan: Self.currentVersion) {
                            self.state = .updateAvailable(
                                version: remoteVer,
                                downloadURL: scriptURL,
                                releaseNotes: "Automated update via official installer script."
                            )
                            return
                        }
                    }
                }

                // 2. Secondary check: GitHub Releases API
                guard let apiURL = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest") else {
                    if !silent { state = .error("Invalid update URL") } else { state = .idle }
                    return
                }

                var request = URLRequest(url: apiURL)
                request.setValue("HeSwitch/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
                request.timeoutInterval = 10

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    if !silent { self.state = .upToDate(version: Self.currentVersion) } else { state = .idle }
                    return
                }

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    self.state = .upToDate(version: Self.currentVersion)
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

                if isVersion(tagName, newerThan: Self.currentVersion) {
                    self.state = .updateAvailable(version: tagName, downloadURL: downloadURL ?? scriptURL, releaseNotes: releaseNotes)
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
                state = .installing

                // Default canonical update mechanism: executes automated installer script
                let updateScript = """
                sleep 0.8
                curl -fsSL https://raw.githubusercontent.com/\(Self.repo)/main/install.sh | bash
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
