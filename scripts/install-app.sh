#!/usr/bin/env bash
# Install a built Voice Operator into /Applications, then restart cooperatively.
#
#   scripts/install-app.sh [app-bundle] [--build [debug|release]] [--force]
#
# Installs `build/Voice Operator.app` unless another bundle is given. --build
# runs make-app.sh first (debug unless a config is named), without its own
# restart: this script restarts once, into the installed copy.
#
# Debug builds already copy themselves here when launched (ApplicationsRelocator);
# this is for release builds, which don't, and for installing without launching
# from build/ first. The copy goes through a sibling staging bundle, so a failed
# copy never leaves a half-written app.
#
# The running app is never killed: the restart goes through restart-app.sh, which
# waits for any dictation or speech to finish (see CLAUDE.md). --force is passed
# through to it and means the same thing there.
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID=com.chriswa.voiceoperator
DEST="/Applications/Voice Operator.app"
APP=
BUILD=
FORCE=

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [ $# -gt 0 ]; do
    case "$1" in
        --build)
            BUILD=debug
            if [ $# -gt 1 ] && [[ "$2" == debug || "$2" == release ]]; then BUILD="$2"; shift; fi
            ;;
        --force) FORCE=--force ;;
        -h|--help) usage ;;
        -*) echo "unknown option: $1" >&2; usage 2 ;;
        *) [ -z "$APP" ] || usage 2; APP="$1" ;;
    esac
    shift
done

if [ -n "$BUILD" ]; then
    [ -z "$APP" ] || { echo "--build installs build/Voice Operator.app; don't also name a bundle" >&2; exit 2; }
    VO_SKIP_RESTART=1 ./scripts/make-app.sh "$BUILD"
fi
APP="${APP:-build/Voice Operator.app}"

[ -d "$APP" ] || { echo "no such bundle: $APP (build it with ./scripts/make-app.sh)" >&2; exit 1; }
plist_get() { /usr/libexec/PlistBuddy -c "Print :$1" "$2/Contents/Info.plist" 2>/dev/null; }

id="$(plist_get CFBundleIdentifier "$APP")" || id=""
[ "$id" = "$BUNDLE_ID" ] || { echo "ERROR: $APP is not Voice Operator (bundle id '${id:-none}')" >&2; exit 1; }
VERSION="$(plist_get CFBundleShortVersionString "$APP")"
codesign --verify --deep --strict "$APP" \
    || { echo "ERROR: $APP fails its code-signature check; rebuild it" >&2; exit 1; }

SRC="$(cd "$APP" && pwd -P)"
if [ -e "$DEST" ]; then
    existing="$(plist_get CFBundleIdentifier "$DEST")" || existing=""
    if [ "$existing" != "$BUNDLE_ID" ]; then
        echo "ERROR: $DEST is another app (${existing:-unknown}); not replacing it" >&2
        exit 1
    fi
    [ "$SRC" != "$(cd "$DEST" && pwd -P)" ] || { echo "$APP is already the installed copy"; exit 0; }
fi

# Creating anything in /Applications takes admin rights. Without them, a copy
# installed earlier is still the user's own, so update it in place (not atomic;
# reinstalling repairs an interrupted copy), as ApplicationsRelocator does.
PARENT="$(dirname "$DEST")"
if [ -w "$PARENT" ]; then
    STAGING="$PARENT/.$(basename "$DEST").$$"
    OLD="$PARENT/.$(basename "$DEST").old.$$"
    trap 'rm -rf "$STAGING" "$OLD"' EXIT
    ditto "$APP" "$STAGING"
    # A running instance keeps the files it has open; the restart below swaps it over.
    [ -e "$DEST" ] && mv "$DEST" "$OLD"
    mv "$STAGING" "$DEST"
elif [ -w "$DEST" ]; then
    echo "no write access to $PARENT — updating the existing copy in place"
    rsync -a --delete "$APP/" "$DEST/"
else
    echo "ERROR: can't write to $PARENT (needs an admin account for the first install)" >&2
    exit 1
fi
echo "installed: $DEST  (v$VERSION)"

# A debug build that relocated itself remembers its build/ path and relaunches
# from there on restart, which would copy that build back over this install.
defaults delete "$BUNDLE_ID" ApplicationsRelocator.sourceBundlePath 2>/dev/null || true

# shellcheck disable=SC2086  # FORCE is empty or one flag
./scripts/restart-app.sh "$DEST" "$VERSION" $FORCE
