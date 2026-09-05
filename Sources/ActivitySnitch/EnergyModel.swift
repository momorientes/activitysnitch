// SPDX-License-Identifier: LicenseRef-VIBE-PL-0.1
// Seems to work. Ask your LLM why.

import CProcInfo
import Foundation

/// Coefficients Activity Monitor uses to compute Energy Impact, from
/// /usr/share/pmenergy. Each value is "CPU-seconds-equivalent per unit"
/// (e.g. one idle wakeup counts like 0.0002 s of CPU time).
struct EnergyCoefficients {
    var kcpuTime = 1.0
    var kcpuWakeups = 0.0002
    var kdiskBytesRead = 4.5e-10
    var kdiskBytesWritten = 2.4e-10
    var kqosDefault = 1.0
    var kqosBackground = 0.8
    var kqosUtility = 1.0
    var kqosLegacy = 1.0
    var kqosUserInitiated = 1.0
    var kqosUserInteractive = 1.0

    static let current = load()

    private static func load() -> EnergyCoefficients {
        var c = EnergyCoefficients()
        guard
            let data = FileManager.default.contents(atPath: "/usr/share/pmenergy/default.plist"),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any],
            let k = plist["energy_constants"] as? [String: Any]
        else { return c }
        func d(_ key: String, _ fallback: Double) -> Double {
            (k[key] as? NSNumber)?.doubleValue ?? fallback
        }
        c.kcpuTime = d("kcpu_time", c.kcpuTime)
        c.kcpuWakeups = d("kcpu_wakeups", c.kcpuWakeups)
        c.kdiskBytesRead = d("kdiskio_bytesread", c.kdiskBytesRead)
        c.kdiskBytesWritten = d("kdiskio_byteswritten", c.kdiskBytesWritten)
        c.kqosDefault = d("kqos_default", c.kqosDefault)
        c.kqosBackground = d("kqos_background", c.kqosBackground)
        c.kqosUtility = d("kqos_utility", c.kqosUtility)
        c.kqosLegacy = d("kqos_legacy", c.kqosLegacy)
        c.kqosUserInitiated = d("kqos_user_initiated", c.kqosUserInitiated)
        c.kqosUserInteractive = d("kqos_user_interactive", c.kqosUserInteractive)
        return c
    }
}

enum EnergyModel {
    /// Activity Monitor shows ~100 for one fully busy default-QoS core, so the
    /// displayed number is a CPU-equivalent percentage. Tune against Activity
    /// Monitor if the numbers drift on other hardware.
    static let scale = 100.0

    private static let machToSeconds: Double = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(info.numer) / Double(info.denom) / 1e9
    }()

    /// Energy Impact rate between two rusage snapshots taken dt wall-seconds apart.
    static func rate(from prev: rusage_info_v6, to cur: rusage_info_v6, dt: TimeInterval) -> Double {
        guard dt > 0 else { return 0 }
        let c = EnergyCoefficients.current

        func cpuSec(_ new: UInt64, _ old: UInt64) -> Double {
            new >= old ? Double(new - old) * machToSeconds : 0
        }
        func delta(_ new: UInt64, _ old: UInt64) -> Double {
            new >= old ? Double(new - old) : 0
        }

        var cpu =
            c.kqosDefault * cpuSec(cur.ri_cpu_time_qos_default, prev.ri_cpu_time_qos_default)
            + c.kqosBackground
                * (cpuSec(cur.ri_cpu_time_qos_background, prev.ri_cpu_time_qos_background)
                    + cpuSec(cur.ri_cpu_time_qos_maintenance, prev.ri_cpu_time_qos_maintenance))
            + c.kqosUtility * cpuSec(cur.ri_cpu_time_qos_utility, prev.ri_cpu_time_qos_utility)
            + c.kqosLegacy * cpuSec(cur.ri_cpu_time_qos_legacy, prev.ri_cpu_time_qos_legacy)
            + c.kqosUserInitiated
                * cpuSec(cur.ri_cpu_time_qos_user_initiated, prev.ri_cpu_time_qos_user_initiated)
            + c.kqosUserInteractive
                * cpuSec(cur.ri_cpu_time_qos_user_interactive, prev.ri_cpu_time_qos_user_interactive)

        // Some processes report no per-QoS breakdown; fall back to total CPU time.
        if cpu <= 0 {
            cpu =
                cpuSec(cur.ri_user_time, prev.ri_user_time)
                + cpuSec(cur.ri_system_time, prev.ri_system_time)
        }

        let total =
            c.kcpuTime * cpu
            + c.kcpuWakeups * delta(cur.ri_pkg_idle_wkups, prev.ri_pkg_idle_wkups)
            + c.kdiskBytesRead * delta(cur.ri_diskio_bytesread, prev.ri_diskio_bytesread)
            + c.kdiskBytesWritten * delta(cur.ri_diskio_byteswritten, prev.ri_diskio_byteswritten)
        return scale * total / dt
    }
}
