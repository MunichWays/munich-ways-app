#!/bin/sh
# Best-effort copy of MapLibre.framework.dSYM for local crash symbolication.
# Never fails the app build if the dSYM is absent (CocoaPods / Xcode layout varies).
#
# Xcode sets: SRCROOT, PODS_ROOT, DWARF_DSYM_FOLDER_PATH (when archiving), etc.

set -u

if [ -z "${PODS_ROOT:-}" ]; then
  echo "note: copy_maplibre_dsym: PODS_ROOT unset, skipping."
  exit 0
fi

SRC_DSYM="$PODS_ROOT/MapLibre/MapLibre.framework.dSYM"
if [ ! -d "$SRC_DSYM" ]; then
  echo "note: copy_maplibre_dsym: no MapLibre.framework.dSYM under Pods (ok for many builds)."
  exit 0
fi

CACHE_ROOT="${SRCROOT}/.maplibre_dsym"
mkdir -p "$CACHE_ROOT"

if [ -n "${DWARF_DSYM_FOLDER_PATH:-}" ] && [ -d "$DWARF_DSYM_FOLDER_PATH" ]; then
  rsync -a "$SRC_DSYM" "$DWARF_DSYM_FOLDER_PATH/" || true
  echo "copy_maplibre_dsym: synced MapLibre dSYM to archive dSYM folder."
fi

rsync -a "$SRC_DSYM" "$CACHE_ROOT/" || true
echo "copy_maplibre_dsym: cached MapLibre dSYM under $CACHE_ROOT (gitignored)."

exit 0
