#!/bin/sh
# Ensure archive contains MapLibre.framework.dSYM.
# Some MapLibre pod layouts do not ship a standalone dSYM at
# Pods/MapLibre/MapLibre.framework.dSYM. In that case we generate one from the
# built embedded framework as a best effort. This script never fails the build.

set -u

if [ -z "${DWARF_DSYM_FOLDER_PATH:-}" ] || [ ! -d "${DWARF_DSYM_FOLDER_PATH:-}" ]; then
  echo "note: copy_maplibre_dsym: DWARF_DSYM_FOLDER_PATH unavailable, skipping."
  exit 0
fi

MAPLIBRE_DSYM_NAME="MapLibre.framework.dSYM"
DEST_DSYM="$DWARF_DSYM_FOLDER_PATH/$MAPLIBRE_DSYM_NAME"

copy_if_exists() {
  src="$1"
  if [ -d "$src" ]; then
    rm -rf "$DEST_DSYM" || true
    rsync -a "$src" "$DWARF_DSYM_FOLDER_PATH/" || true
    echo "copy_maplibre_dsym: copied dSYM from $src"
    return 0
  fi
  return 1
}

# Try known vendor dSYM locations first.
if [ -n "${PODS_ROOT:-}" ]; then
  copy_if_exists "$PODS_ROOT/MapLibre/$MAPLIBRE_DSYM_NAME" && exit 0
  copy_if_exists "$PODS_ROOT/MapLibre/MapLibre.xcframework/ios-arm64/dSYMs/$MAPLIBRE_DSYM_NAME" && exit 0
fi

# Fall back to generating a dSYM from the embedded framework binary.
EMBEDDED_BIN="${TARGET_BUILD_DIR:-}/${FRAMEWORKS_FOLDER_PATH:-}/MapLibre.framework/MapLibre"
PODS_BIN="${PODS_ROOT:-}/MapLibre/MapLibre.xcframework/ios-arm64/MapLibre.framework/MapLibre"

SOURCE_BIN=""
if [ -f "$EMBEDDED_BIN" ]; then
  SOURCE_BIN="$EMBEDDED_BIN"
elif [ -f "$PODS_BIN" ]; then
  SOURCE_BIN="$PODS_BIN"
fi

if [ -z "$SOURCE_BIN" ]; then
  echo "note: copy_maplibre_dsym: could not find MapLibre binary, skipping."
  exit 0
fi

rm -rf "$DEST_DSYM" || true
if xcrun dsymutil "$SOURCE_BIN" -o "$DEST_DSYM"; then
  echo "copy_maplibre_dsym: generated dSYM via dsymutil from $SOURCE_BIN"
  if command -v xcrun >/dev/null 2>&1; then
    xcrun dwarfdump --uuid "$SOURCE_BIN" 2>/dev/null || true
    xcrun dwarfdump --uuid "$DEST_DSYM/Contents/Resources/DWARF/MapLibre" 2>/dev/null || true
  fi
else
  echo "warning: copy_maplibre_dsym: dsymutil failed for MapLibre (continuing)."
fi

exit 0
