import CProcInfo
import Foundation

/// Samples all processes every `interval` seconds, keeps a trailing
/// time-weighted average of each process's Energy Impact rate, and notifies
/// when the average stays at/above the threshold for the configured duration.
final class EnergyMonitor {
    static let shared = EnergyMonitor()

    let interval: TimeInterval = 5

    private let queue = DispatchQueue(label: "network.noscito.ActivitySnitch.monitor", qos: .utility)
    private var timer: DispatchSourceTimer?

    private struct WindowEntry {
        let t: TimeInterval
        let dt: TimeInterval
        let rate: Double
    }

    private struct ProcState {
        var window: [WindowEntry] = []
        var weightedSum: Double = 0
        var dtSum: TimeInterval = 0
        var firstSeen: TimeInterval
        var armed = true
        var notifiedAt: TimeInterval?
    }

    private var prevSnapshots: [ProcessKey: rusage_info_v6] = [:]
    private var prevTime: TimeInterval = 0
    private var states: [ProcessKey: ProcState] = [:]

    /// Re-arm hysteresis: notify again only after the average drops below
    /// 80% of the threshold AND this much time has passed.
    private let rearmCooldown: TimeInterval = 600

    func start() {
        // .strict resists timer coalescing so the cadence holds while the
        // display sleeps (the NSActivity in AppDelegate handles App Nap).
        let t = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        t.schedule(deadline: .now() + 1, repeating: interval, leeway: .milliseconds(500))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private static func now() -> TimeInterval {
        TimeInterval(DispatchTime.now().uptimeNanoseconds) / 1e9
    }

    private func tick() {
        let now = Self.now()
        let snaps = ProcessSampler.snapshotAll()
        defer {
            prevSnapshots = snaps
            prevTime = now
        }

        guard prevTime > 0 else { return }
        let dt = now - prevTime
        guard dt > 0 else { return }

        // dt comes from the uptime clock, which pauses during system sleep
        // just like the rusage counters do — so post-sleep deltas are already
        // consistent and a stretched dt only means timer throttling. The rate
        // math stays valid over a long dt; only give up when a single gap
        // exceeds the whole averaging window.
        if dt > Settings.sustainDuration {
            for key in states.keys {
                states[key]?.window.removeAll()
                states[key]?.weightedSum = 0
                states[key]?.dtSum = 0
                states[key]?.firstSeen = now
            }
            return
        }

        let threshold = Settings.threshold
        let duration = Settings.sustainDuration
        let ownPid = ProcessInfo.processInfo.processIdentifier

        var consumers: [(key: ProcessKey, avg: Double, rate: Double)] = []
        var alertActive = false

        for (key, usage) in snaps {
            guard let prev = prevSnapshots[key] else {
                if states[key] == nil { states[key] = ProcState(firstSeen: now) }
                continue
            }
            let rate = EnergyModel.rate(from: prev, to: usage, dt: dt)
            var st = states[key] ?? ProcState(firstSeen: now)

            st.window.append(WindowEntry(t: now, dt: dt, rate: rate))
            st.weightedSum += rate * dt
            st.dtSum += dt
            while let first = st.window.first, first.t < now - duration {
                st.weightedSum -= first.rate * first.dt
                st.dtSum -= first.dt
                st.window.removeFirst()
            }

            let avg = st.dtSum > 0 ? st.weightedSum / st.dtSum : 0
            let windowFull = now - st.firstSeen >= duration && st.dtSum >= duration * 0.8

            if avg >= threshold, windowFull { alertActive = true }

            if st.armed, windowFull, avg >= threshold, key.pid != ownPid {
                // Battery gating happens here (not in sampling) and does NOT
                // disarm: if we're on AC, stay armed so unplugging while the
                // hog is still busy produces the alert.
                if !Settings.onlyOnBattery || PowerSourceMonitor.isOnBattery() {
                    st.armed = false
                    st.notifiedAt = now
                    let name = ProcessSampler.displayName(pid: key.pid)
                    NotificationManager.shared.postHighEnergy(
                        key: key, name: name, average: avg, duration: duration)
                }
            } else if !st.armed {
                let cooled = st.notifiedAt.map { now - $0 >= rearmCooldown } ?? true
                if cooled, avg < threshold * 0.8 { st.armed = true }
            }

            states[key] = st
            consumers.append((key, avg, rate))
        }

        states = states.filter { snaps[$0.key] != nil }

        let top = consumers.sorted { $0.avg > $1.avg }.prefix(5).map {
            MonitorState.Consumer(
                key: $0.key,
                name: ProcessSampler.displayName(pid: $0.key.pid),
                average: $0.avg,
                rate: $0.rate)
        }
        let active = alertActive
        Task { @MainActor in
            MonitorState.shared.topConsumers = Array(top)
            MonitorState.shared.alertActive = active
        }
    }
}
