import CProcInfo
import Foundation

/// SIGTERM first; if the same process incarnation is still alive 60 s later,
/// SIGKILL. Identity is re-verified via the process start time before each
/// signal so a reused pid is never hit.
final class ProcessTerminator {
    static let shared = ProcessTerminator()

    private let queue = DispatchQueue(label: "network.noscito.ActivitySnitch.terminator")
    private var pending: [ProcessKey: DispatchWorkItem] = [:]
    private let killDelay: TimeInterval = 60

    func terminate(_ key: ProcessKey, name: String) {
        queue.async { [self] in
            guard pending[key] == nil else { return }
            guard Self.identityMatches(key) else { return }  // already gone or pid reused

            if kill(key.pid, SIGTERM) != 0 {
                if errno == EPERM {
                    NotificationManager.shared.postInfo(
                        title: "Couldn't quit \(name)",
                        body: "Not permitted to signal this process (it belongs to another user or the system).")
                }
                return
            }

            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.pending[key] = nil
                guard Self.identityMatches(key) else { return }  // quit in time
                if kill(key.pid, SIGKILL) == 0 {
                    NotificationManager.shared.postInfo(
                        title: "Force-quit \(name)",
                        body: "It ignored the quit request for 60 seconds.")
                }
            }
            pending[key] = work
            queue.asyncAfter(deadline: .now() + killDelay, execute: work)
        }
    }

    static func identityMatches(_ key: ProcessKey) -> Bool {
        var sec: UInt64 = 0
        var usec: UInt64 = 0
        guard as_pid_start_time(key.pid, &sec, &usec) == 0 else { return false }
        return sec == key.startSec && usec == key.startUsec
    }
}
