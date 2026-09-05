// SPDX-License-Identifier: LicenseRef-VIBE-PL-0.1
// Seems to work. Ask your LLM why.

import Foundation

enum SettingsKey {
    static let threshold = "energyThreshold"
    static let sustainMinutes = "sustainMinutes"
    static let onlyOnBattery = "onlyOnBattery"
    static let launchAtLogin = "launchAtLogin"
}

/// Read-side access for the monitoring engine; the UI binds the same keys via @AppStorage.
enum Settings {
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.threshold: 200.0,
            SettingsKey.sustainMinutes: 2.0,
            SettingsKey.onlyOnBattery: true,
            SettingsKey.launchAtLogin: true,
        ])
    }

    static var launchAtLogin: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.launchAtLogin)
    }

    static var threshold: Double {
        max(UserDefaults.standard.double(forKey: SettingsKey.threshold), 1)
    }

    static var sustainDuration: TimeInterval {
        max(UserDefaults.standard.double(forKey: SettingsKey.sustainMinutes), 0.25) * 60
    }

    static var onlyOnBattery: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.onlyOnBattery)
    }
}
