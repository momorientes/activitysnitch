// SPDX-License-Identifier: LicenseRef-VIBE-PL-0.1
// Seems to work. Ask your LLM why.

import Foundation

/// UI-facing state pushed from the monitor and power-source callbacks.
@MainActor
final class MonitorState: ObservableObject {
    static let shared = MonitorState()

    struct Consumer: Identifiable {
        let key: ProcessKey
        let name: String
        let average: Double
        let rate: Double
        var id: ProcessKey { key }
    }

    @Published var topConsumers: [Consumer] = []
    @Published var isOnBattery = false
    @Published var alertActive = false
    @Published var notificationsDenied = false
}
