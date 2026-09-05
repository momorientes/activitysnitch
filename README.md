# ActivitySnitch

A macOS menubar app that watches per-process **Energy Impact** (the Activity
Monitor metric) and notifies you when a process sustains a high average —
by default an energy impact of **200 for 2 minutes**. The notification has a
**Quit App** action that sends the process SIGTERM, escalating to SIGKILL if
it hasn't exited after 60 seconds. Optionally it only alerts while on battery.

## How it measures Energy Impact

Every 5 seconds it reads each process's counters via the public
`proc_pid_rusage(…, RUSAGE_INFO_V6, …)` API (CPU time per QoS class, package
idle wakeups, disk I/O) and combines the deltas using Apple's own coefficients
from `/usr/share/pmenergy/default.plist` — the same inputs Activity Monitor
uses. The result is a CPU-equivalent percentage: ~100 for one fully busy
default-QoS core, discounted for background QoS, plus small charges per
wakeup and per byte of disk I/O. No root required; processes owned by other
users that the kernel refuses to report on are skipped.

## Install (Homebrew)

```sh
brew install --cask momorientes/tap/activitysnitch
```

Upgrades ship through the same tap: `brew upgrade --cask activitysnitch`.

Note: the app is ad-hoc signed, not notarized. The cask strips the quarantine
attribute in a postflight step so the brew install launches cleanly; anyone
downloading the release zip directly will hit Gatekeeper's
unidentified-developer warning instead (right-click → Open, or use brew).

## Build & run from source

```sh
Scripts/build-app.sh
open .build/ActivitySnitch.app
```

Releases are cut with `Scripts/release.sh <version>`, which builds, zips,
publishes a GitHub release, and bumps the cask in
[momorientes/homebrew-tap](https://github.com/momorientes/homebrew-tap).

Requires Xcode or the Command Line Tools (the script falls back to
`/Library/Developer/CommandLineTools` if the Xcode license hasn't been
accepted). Launch via `open` — notifications need the app bundle context.
Grant notification permission on first launch. The bundle id and output path
are kept stable so the permission survives rebuilds.

Settings (threshold, sustain duration, battery-only) live in the menubar
panel and apply immediately.

### Calibration / debugging

```sh
.build/debug/ActivitySnitch --sample [interval]
```

prints the top Energy Impact rates to stdout so you can compare side by side
with Activity Monitor's Energy tab. If the numbers drift on other hardware,
adjust `EnergyModel.scale`.

## Behavior details

- Trigger: time-weighted average over the trailing window ≥ threshold, with
  the window fully populated (process observed for at least the full
  duration). One alert per episode: re-arms only after the average falls
  below 80% of the threshold and a 10-minute cooldown passes.
- Pid-reuse safety: every process is identified by (pid, start time); both
  the notification's Quit action and the delayed SIGKILL re-verify identity
  before signaling.
- Battery-only mode gates notifications, not sampling — the menubar list
  stays live either way, and a hog that persists until you unplug still
  triggers an alert.
- Sleep/wake: sampling gaps larger than 4 intervals reset the averaging
  windows instead of producing bogus rates.

## Future ideas

- Group helper processes under their parent app the way Activity Monitor
  does (needs the private `responsibility_get_pid_responsible_for_pid` API).
- Per-machine coefficients (`/usr/share/pmenergy/Mac-<board-id>.plist`) on
  Intel Macs; this build uses `default.plist`.
