#!/bin/bash
# Live demo of ActivitySnitch. Spawns "EnergyHogDemo" (~200 energy impact),
# temporarily lowers the alert settings (threshold 150, sustained 30 s, notify
# on any power source), and reports what happens to the hog. Settings are
# restored on exit.
#
#   Scripts/demo.sh              hog quits on SIGTERM (normal case)
#   Scripts/demo.sh --stubborn   hog ignores SIGTERM -> SIGKILL after 60 s
set -euo pipefail
cd "$(dirname "$0")/.."

STUBBORN="${1:-}"
BUNDLE="network.noscito.ActivitySnitch"
HOG_BIN=".build/EnergyHogDemo"
HOG_LOG=".build/energy-hog.log"
TIMEOUT=300

if ! cc --version >/dev/null 2>&1; then
    export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi

[ -d .build/ActivitySnitch.app ] || Scripts/build-app.sh
mkdir -p .build
cc -O0 -o "$HOG_BIN" Scripts/energy-hog.c

saved() { defaults read "$BUNDLE" "$1" 2>/dev/null || echo "__unset__"; }
OLD_THRESHOLD=$(saved energyThreshold)
OLD_MINUTES=$(saved sustainMinutes)
OLD_BATTERY=$(saved onlyOnBattery)

HOG_PID=""
HOG_START=""
hog_alive() {
    [ -n "$HOG_PID" ] || return 1
    # Compare the launch timestamp so a reused pid isn't mistaken for the hog.
    [ "$(ps -p "$HOG_PID" -o lstart= 2>/dev/null)" = "$HOG_START" ]
}
restore() {
    set +e  # never let one failed cleanup command abort the rest
    hog_alive && kill -9 "$HOG_PID" 2>/dev/null
    restore_one() {
        if [ -z "$2" ] || [ "$2" = "__unset__" ]; then
            defaults delete "$BUNDLE" "$1" 2>/dev/null
        else
            defaults write "$BUNDLE" "$1" "$3" "$2" 2>/dev/null
        fi
    }
    restore_one energyThreshold "$OLD_THRESHOLD" -float
    restore_one sustainMinutes "$OLD_MINUTES" -float
    restore_one onlyOnBattery "$OLD_BATTERY" -bool
    echo "Settings restored."
}
trap restore EXIT

defaults write "$BUNDLE" energyThreshold -float 250
defaults write "$BUNDLE" sustainMinutes -float 0.5
defaults write "$BUNDLE" onlyOnBattery -bool false

open .build/ActivitySnitch.app

: > "$HOG_LOG"
"$HOG_BIN" $STUBBORN 2>> "$HOG_LOG" &
HOG_PID=$!
HOG_START=$(ps -p "$HOG_PID" -o lstart= 2>/dev/null)

echo "EnergyHogDemo (pid $HOG_PID) is burning three cores (~300 energy impact)."
echo "Demo settings: threshold 250, sustained 30 s, any power source."
echo
echo ">>> Expect a notification in ~35-45 s. Click 'Quit App' on it. <<<"
[ -n "$STUBBORN" ] && echo ">>> Stubborn mode: the hog ignores SIGTERM; SIGKILL lands 60 s after your click. <<<"
echo

START=$(date +%s)
TERM_SEEN=""
while hog_alive; do
    if [ -z "$TERM_SEEN" ] && grep -q SIGTERM "$HOG_LOG" 2>/dev/null; then
        TERM_SEEN=1
        echo "[$(($(date +%s) - START))s] Hog received SIGTERM."
    fi
    if [ $(($(date +%s) - START)) -ge $TIMEOUT ]; then
        echo "[$TIMEOUT s] Timeout — no interaction. Stopping the demo."
        exit 1
    fi
    sleep 1
done

ELAPSED=$(($(date +%s) - START))
wait "$HOG_PID" 2>/dev/null && EXIT_CODE=$? || EXIT_CODE=$?
HOG_PID=""

echo
if [ -n "$TERM_SEEN" ] && [ "$EXIT_CODE" -eq 0 ]; then
    echo "[${ELAPSED}s] Hog exited cleanly after SIGTERM. Demo complete."
elif [ "$EXIT_CODE" -eq 137 ] || [ "$EXIT_CODE" -gt 128 ]; then
    echo "[${ELAPSED}s] Hog was killed by signal $((EXIT_CODE - 128)) (9 = SIGKILL escalation). Demo complete."
else
    echo "[${ELAPSED}s] Hog exited with code $EXIT_CODE."
fi
