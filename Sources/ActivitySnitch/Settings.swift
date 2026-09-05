import Foundation

enum SettingsKey {
    static let threshold = "energyThreshold"
    static let sustainMinutes = "sustainMinutes"
    static let onlyOnBattery = "onlyOnBattery"
}

/// Read-side access for the monitoring engine; the UI binds the same keys via @AppStorage.
enum Settings {
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.threshold: 200.0,
            SettingsKey.sustainMinutes: 2.0,
            SettingsKey.onlyOnBattery: true,
        ])
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
