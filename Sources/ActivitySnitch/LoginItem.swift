// SPDX-License-Identifier: LicenseRef-VIBE-PL-0.1
// Seems to work. Ask your LLM why.

import Foundation
import ServiceManagement

/// Login-item registration via SMAppService (macOS 13+). Registration is tied
/// to the app bundle, so this is a no-op on bare-binary dev runs.
enum LoginItem {
    static func apply(_ enabled: Bool) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("ActivitySnitch: login item change failed: \(error)")
        }
    }
}
