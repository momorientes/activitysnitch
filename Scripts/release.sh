#!/bin/bash
# Cuts a release: builds the app, zips it, publishes a GitHub release, and
# updates the Homebrew cask in the tap.
#
#   Scripts/release.sh 1.0.1
#
# Expects the tap clone at ~/dev/homebrew-tap (override with TAP_DIR).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: Scripts/release.sh <version>}"
TAP_DIR="${TAP_DIR:-$HOME/dev/homebrew-tap}"
CASK="$TAP_DIR/Casks/activitysnitch.rb"
ZIP="dist/ActivitySnitch-$VERSION.zip"

if [ -n "$(git status --porcelain)" ]; then
    echo "error: working tree is dirty — commit or stash first" >&2
    exit 1
fi
[ -f "$CASK" ] || { echo "error: cask not found at $CASK" >&2; exit 1; }

Scripts/build-app.sh "$VERSION"

mkdir -p dist
rm -f "$ZIP"
ditto -c -k --keepParent .build/ActivitySnitch.app "$ZIP"
SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)
echo "Built $ZIP ($SHA)"

git tag "v$VERSION"
git push origin HEAD "v$VERSION"
gh release create "v$VERSION" "$ZIP" --title "v$VERSION" --notes "ActivitySnitch $VERSION"

sed -i '' \
    -e "s/^  version \".*\"/  version \"$VERSION\"/" \
    -e "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" \
    "$CASK"
git -C "$TAP_DIR" add Casks/activitysnitch.rb
git -C "$TAP_DIR" commit -m "activitysnitch $VERSION"
git -C "$TAP_DIR" push

echo
echo "Released v$VERSION."
echo "Install:  brew install --cask momorientes/tap/activitysnitch"
echo "Upgrade:  brew upgrade --cask activitysnitch"
