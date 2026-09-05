import Foundation
import IOKit.ps

enum PowerSourceMonitor {
    /// Cheap enough to query on demand; used by the notification decision.
    static func isOnBattery() -> Bool {
        guard let type = IOPSGetProvidingPowerSourceType(nil)?.takeRetainedValue() as String?
        else { return false }
        return type == kIOPMBatteryPowerKey
    }

    /// Keeps MonitorState.isOnBattery current for the menu UI.
    static func startObserving() {
        push()
        let callback: IOPowerSourceCallbackType = { _ in PowerSourceMonitor.push() }
        if let source = IOPSNotificationCreateRunLoopSource(callback, nil)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    private static func push() {
        let onBattery = isOnBattery()
        Task { @MainActor in MonitorState.shared.isOnBattery = onBattery }
    }
}
