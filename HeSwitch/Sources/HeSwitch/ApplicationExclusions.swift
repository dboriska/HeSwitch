import AppKit

public struct ExcludedApp: Codable, Identifiable, Equatable {
    public var id: String { bundleID }
    public let bundleID: String
    public let name: String

    public init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
    }
}

public enum ApplicationExclusions {
    private static let key = "excludedApplicationsData"

    public static var applications: [ExcludedApp] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([ExcludedApp].self, from: data) else {
            return []
        }
        return list
    }

    public static func contains(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return applications.contains { $0.bundleID == bundleID }
    }

    public static func add(bundleID: String, name: String) -> Bool {
        guard !contains(bundleID: bundleID) else { return false }
        var current = applications
        current.append(ExcludedApp(bundleID: bundleID, name: name))
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: key)
        }
        return true
    }

    public static func remove(bundleID: String) {
        var current = applications
        current.removeAll { $0.bundleID == bundleID }
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
