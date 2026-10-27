import AppKit
import Foundation
import ServiceManagement

public enum LaunchAtLogin {
    public static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            if status == .enabled || status == .requiresApproval {
                return true
            }
        }
        return checkSystemEventsLoginItem()
    }

    public static func setEnabled(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                NSLog("[HeSwitch] SMAppService error: \(error). Using AppleScript System Events fallback.")
                setSystemEventsLoginItem(enable)
                return
            }
        } else {
            setSystemEventsLoginItem(enable)
        }

        // Also sync AppleScript login item for ad-hoc signing compatibility
        setSystemEventsLoginItem(enable)
    }

    private static func checkSystemEventsLoginItem() -> Bool {
        let script = """
        tell application "System Events"
            return (exists (login item "HeSwitch"))
        end tell
        """
        guard let appleScript = NSAppleScript(source: script) else { return false }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        return result.booleanValue
    }

    private static func setSystemEventsLoginItem(_ enable: Bool) {
        let appPath = Bundle.main.bundlePath
        let script: String
        if enable {
            script = """
            tell application "System Events"
                if not (exists (login item "HeSwitch")) then
                    make login item at end with properties {path:"\(appPath)", hidden:false, name:"HeSwitch"}
                end if
            end tell
            """
        } else {
            script = """
            tell application "System Events"
                if exists (login item "HeSwitch") then
                    delete login item "HeSwitch"
                end if
            end tell
            """
        }
        guard let appleScript = NSAppleScript(source: script) else { return }
        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)
    }
}
