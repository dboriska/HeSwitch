import Foundation

@MainActor
public final class CLILogger {
    public static var isVerbose: Bool = false

    public static func log(_ message: String) {
        if isVerbose {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            let time = formatter.string(from: Date())
            print("[\(time)] \(message)")
            fflush(stdout)
        }
    }

    public static func debug(_ message: String) {
        if isVerbose {
            print("  ↳ [DEBUG] \(message)")
            fflush(stdout)
        }
    }

    public static func event(_ message: String) {
        if isVerbose {
            print("⚡️ [EVENT] \(message)")
            fflush(stdout)
        }
    }

    public static func success(_ message: String) {
        if isVerbose {
            print("✅ [SUCCESS] \(message)")
            fflush(stdout)
        }
    }

    public static func warn(_ message: String) {
        print("⚠️ [WARNING] \(message)")
        fflush(stdout)
    }

    public static func error(_ message: String) {
        print("❌ [ERROR] \(message)")
        fflush(stderr)
    }
}
