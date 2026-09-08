#!/usr/bin/env bash
# Cut a release: bump pubspec, verify the four changelogs, commit, tag, push.
# The v-tag then triggers CI (android.yml → Play "alpha" AND production,
# ios.yml → TestFlight → App Store review), which re-asserts tag == pubspec
# as the backstop.
#
# THE TAG IS THE HUMAN GATE — there is no approval step after this script.
# What you tag goes live on both stores.
#
#   tool/cut_release.sh 1.0.0
#
# The build number is auto-incremented from pubspec. Changelog files for the
# NEW build number must already exist (all four locales) — write them first:
#   fastlane/metadata/android/<locale>/changelogs/<build>.txt
set -euo pipefail

VERSION=${1:?usage: tool/cut_release.sh <x.y.z>}
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "✗ '$VERSION' is not x.y.z"; exit 1; }

cd "$(dirname "$0")/.."

BRANCH=$(git rev-parse --abbrev-ref HEAD)
[ "$BRANCH" = "main" ] || { echo "✗ on '$BRANCH', releases cut from main"; exit 1; }
# Tracked changes only (-uno): untracked scratch can't reach the release
# commit — the script stages nothing but pubspec.yaml.
[ -z "$(git status --porcelain -uno)" ] || { echo "✗ working tree has uncommitted tracked changes"; exit 1; }

git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] \
  || { echo "✗ main is not in sync with origin/main (pull/push first)"; exit 1; }

CURRENT=$(grep -m1 '^version:' pubspec.yaml | awk '{print $2}')
CUR_BUILD=${CURRENT##*+}
NEW_BUILD=$((CUR_BUILD + 1))
NEW="$VERSION+$NEW_BUILD"
[ "$VERSION" != "${CURRENT%%+*}" ] || { echo "✗ $VERSION is already the current version ($CURRENT)"; exit 1; }
# Reject going backwards: sort -V puts the higher version last.
HIGHEST=$(printf '%s\n%s\n' "${CURRENT%%+*}" "$VERSION" | sort -V | tail -1)
[ "$HIGHEST" = "$VERSION" ] || { echo "✗ $VERSION is lower than the current version ($CURRENT)"; exit 1; }
echo "✓ pubspec: $CURRENT → $NEW"

MISSING=0
for LOC in en-US de-DE fr-FR it-IT; do
  F="fastlane/metadata/android/$LOC/changelogs/$NEW_BUILD.txt"
  if [ ! -s "$F" ]; then echo "✗ missing changelog: $F"; MISSING=1; continue; fi
  # Play rejects release notes over 500 characters — at upload time, after
  # the ~10-minute build. Catch it here instead.
  LEN=$(tr -d '\n' < "$F" | wc -m)
  if [ "$LEN" -gt 500 ]; then
    echo "✗ changelog too long: $F ($LEN chars, Play max 500)"; MISSING=1
  fi
done
[ "$MISSING" -eq 0 ] || { echo "  fix the changelogs for build $NEW_BUILD, then re-run"; exit 1; }
echo "✓ changelogs $NEW_BUILD.txt ×4 locales exist, all ≤500 chars"
# The iOS release notes are submitted to the App Store by the tag itself, so
# stale notes ship. Warn if they haven't been touched since the last tag.
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -n "$LAST_TAG" ] && git diff --quiet "$LAST_TAG" HEAD -- fastlane/metadata/ios; then
  echo "⚠ fastlane/metadata/ios/*/release_notes.txt unchanged since $LAST_TAG — the tag"
  echo "  submits them to the App Store as this version's 'What's New'. Ctrl-C to fix."
else
  echo "✓ iOS release notes touched since ${LAST_TAG:-the beginning}"
fi

# Best-effort CI check on the tip commit (gh optional).
if command -v gh >/dev/null 2>&1; then
  CONCLUSIONS=$(gh api "repos/{owner}/{repo}/commits/$(git rev-parse HEAD)/check-runs" \
    --jq '[.check_runs[].conclusion] | unique | join(",")' 2>/dev/null || echo "unknown")
  case "$CONCLUSIONS" in
    success) echo "✓ CI green on HEAD" ;;
    "")      echo "⚠ no CI runs found for HEAD (still running?) — the tag build re-tests anyway" ;;
    *)       echo "⚠ CI on HEAD: $CONCLUSIONS — the tag build gates on tests, a red one won't ship" ;;
  esac
fi

sed -i.bak "s/^version: .*/version: $NEW/" pubspec.yaml && rm pubspec.yaml.bak
git add pubspec.yaml
git commit -q -m "chore(release): $NEW"
git tag "v$VERSION"
git push origin main "v$VERSION"
echo "✓ pushed main + v$VERSION → CI ships to Play production (+ alpha)"
echo "  and submits the iOS build for App Store review — no further approval"
