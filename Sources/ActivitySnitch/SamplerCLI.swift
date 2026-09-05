// SPDX-License-Identifier: LicenseRef-VIBE-PL-0.1
// Seems to work. Ask your LLM why.

import CProcInfo
import Foundation

/// `ActivitySnitch --sample [interval]` — prints top Energy Impact rates to
/// stdout for calibrating against Activity Monitor. Runs until Ctrl-C.
enum SamplerCLI {
    static func run() -> Never {
        var interval: TimeInterval = 5
        if let idx = CommandLine.arguments.firstIndex(of: "--sample"),
            CommandLine.arguments.count > idx + 1,
            let value = TimeInterval(CommandLine.arguments[idx + 1])
        {
            interval = max(value, 1)
        }
        print("Sampling every \(Int(interval))s — compare against Activity Monitor's Energy tab.")

        var prev = ProcessSampler.snapshotAll()
        var prevTime = Date()
        while true {
            Thread.sleep(forTimeInterval: interval)
            let cur = ProcessSampler.snapshotAll()
            let now = Date()
            let dt = now.timeIntervalSince(prevTime)

            var rows: [(name: String, pid: pid_t, rate: Double)] = []
            for (key, usage) in cur {
                guard let old = prev[key] else { continue }
                let rate = EnergyModel.rate(from: old, to: usage, dt: dt)
                if rate >= 0.5 {
                    rows.append((ProcessSampler.displayName(pid: key.pid), key.pid, rate))
                }
            }
            rows.sort { $0.rate > $1.rate }

            let stamp = ISO8601DateFormatter().string(from: now)
            print("\n[\(stamp)] top \(min(rows.count, 15)) of \(cur.count) processes:")
            print("      EI     PID  NAME")
            for row in rows.prefix(15) {
                let ei = String(format: "%8.1f", row.rate)
                let pid = String(format: "%6d", row.pid)
                print("\(ei)  \(pid)  \(row.name)")
            }

            fflush(stdout)
            prev = cur
            prevTime = now
        }
    }
}
