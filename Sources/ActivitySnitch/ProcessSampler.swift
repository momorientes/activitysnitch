// SPDX-License-Identifier: LicenseRef-VIBE-PL-0.1
// Seems to work. Ask your LLM why.

import CProcInfo
import Foundation

/// Identity of one process incarnation. Including the start time guards every
/// consumer (windows, notifications, kill escalation) against pid reuse.
struct ProcessKey: Hashable {
    let pid: pid_t
    let startSec: UInt64
    let startUsec: UInt64
}

enum ProcessSampler {
    static func snapshotAll() -> [ProcessKey: rusage_info_v6] {
        var pids = [Int32](repeating: 0, count: 16384)
        let count = pids.withUnsafeMutableBufferPointer { buf in
            as_list_all_pids(buf.baseAddress, Int32(buf.count))
        }
        guard count > 0 else { return [:] }

        var result: [ProcessKey: rusage_info_v6] = [:]
        result.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            let pid = pids[i]
            guard pid > 0 else { continue }
            var sec: UInt64 = 0
            var usec: UInt64 = 0
            guard as_pid_start_time(pid, &sec, &usec) == 0 else { continue }
            var usage = rusage_info_v6()
            guard as_pid_rusage_v6(pid, &usage) == 0 else { continue }
            result[ProcessKey(pid: pid, startSec: sec, startUsec: usec)] = usage
        }
        return result
    }

    /// Prefer the enclosing .app bundle name ("Safari" for Safari's helpers),
    /// falling back to the executable or kernel-reported name.
    static func displayName(pid: pid_t) -> String {
        var buf = [CChar](repeating: 0, count: 4096)
        if as_pid_path(pid, &buf, UInt32(buf.count)) == 0 {
            let path = String(cString: buf)
            if let range = path.range(of: ".app/") {
                let bundle = (String(path[..<range.lowerBound]) as NSString).lastPathComponent
                return bundle
            }
            return (path as NSString).lastPathComponent
        }
        return rawName(pid: pid) ?? "pid \(pid)"
    }

    static func rawName(pid: pid_t) -> String? {
        var buf = [CChar](repeating: 0, count: 256)
        guard as_pid_name(pid, &buf, UInt32(buf.count)) == 0 else { return nil }
        return String(cString: buf)
    }
}
