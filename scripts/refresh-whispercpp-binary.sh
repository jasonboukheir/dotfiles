#!/usr/bin/env bash
# Pull the freshly-built whisper-server out of the project tree, strip
# it, and stage the result into pkgs/whispercpp-intel-arc-server/bin/
# so `nixos-rebuild switch` picks it up via the vendored package.
#
# After running this:
#   git -C ~/.config/nix add pkgs/whispercpp-intel-arc-server/bin/
#   git -C ~/.config/nix commit -m "whispercpp-intel-arc: refresh binary"
#   sudo nixos-rebuild switch --flake ~/.config/nix#brutus
#
# git-lfs handles the binary blobs (see .gitattributes).
set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$CONFIG_DIR/pkgs/whispercpp-intel-arc-server/bin"
SRC="${WHISPERCPP_BUILD_DIR:-$HOME/Projects/intellm/whispercpp-intel-arc/build-aicss/whisper/build/bin}"

if [ ! -x "$SRC/whisper-server" ]; then
    echo "ERROR: $SRC/whisper-server is missing or not executable." >&2
    echo "       Build the binary first via:" >&2
    echo "         (cd ~/Projects/intellm/whispercpp-intel-arc && scripts/build-aicss.sh)" >&2
    exit 1
fi

if ! command -v strip >/dev/null 2>&1; then
    echo "ERROR: strip(1) not on PATH — install binutils first." >&2
    exit 1
fi

mkdir -p "$DEST"

# Wipe any stale files (placeholder, prior build) so renamed/dropped
# libs don't linger.
find "$DEST" -mindepth 1 -maxdepth 1 -delete

install -m 0755 "$SRC/whisper-server" "$DEST/whisper-server"
strip --strip-unneeded "$DEST/whisper-server"

shopt -s nullglob
for src in "$SRC"/lib*.so.*.*; do
    base="$(basename "$src")"
    install -m 0755 "$src" "$DEST/$base"
    strip --strip-unneeded "$DEST/$base" || true
done

# Recreate the symlink chain that the runtime linker walks. DT_SONAME
# is the source of truth so this handles both 3-part libfoo.so.X.Y.Z
# and 2-part libdnnl.so.3.9 shapes.
cd "$DEST"
shopt -s nullglob
for full in lib*.so.*.*; do
    soname=$(readelf -d "$full" 2>/dev/null \
        | awk -F'[][]' '/SONAME/ {print $2}')
    if [ -z "$soname" ]; then
        echo "WARN: $full has no DT_SONAME; skipping symlink creation" >&2
        continue
    fi
    short="${full%%.so*}.so"
    [ "$soname" != "$full" ] && ln -sf "$full" "$soname"
    [ "$short" != "$soname" ] && ln -sf "$soname" "$short"
done
shopt -u nullglob

echo "staged into $DEST:"
du -sh "$DEST"
ls -la "$DEST"

cat <<EOF

Next steps:
  git -C "$CONFIG_DIR" add .gitattributes pkgs/whispercpp-intel-arc-server/bin/
  git -C "$CONFIG_DIR" commit -m "whispercpp-intel-arc: refresh binary"
  sudo nixos-rebuild switch --flake "$CONFIG_DIR#brutus"
EOF
