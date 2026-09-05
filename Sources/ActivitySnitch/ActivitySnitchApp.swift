// SPDX-License-Identifier: LicenseRef-VIBE-PL-0.1
// Seems to work. Ask your LLM why.

import AppKit
import SwiftUI

@main
enum Main {
    static func main() {
        if CommandLine.arguments.contains("--sample") {
            SamplerCLI.run()
        } else {
            ActivitySnitchApp.main()
        }
    }
}

struct ActivitySnitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var state = MonitorState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(
                systemName: state.alertActive
                    ? "bolt.trianglebadge.exclamationmark" : "bolt")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var activityToken: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Opt out of App Nap so sampling keeps its 5 s cadence while the
        // display is off — precisely when energy hogs matter. This variant
        // still allows normal system sleep.
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Continuous per-process energy sampling")
        // LSUIElement in the bundle's Info.plist already hides the Dock icon;
        // this covers dev runs of the bare binary.
        NSApp.setActivationPolicy(.accessory)
        Settings.registerDefaults()
        LoginItem.apply(Settings.launchAtLogin)
        NotificationManager.shared.setUp()
        PowerSourceMonitor.startObserving()
        EnergyMonitor.shared.start()
    }
}
