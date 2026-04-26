#!/usr/bin/env bash
# Pull the freshly-built patched llama-server out of the project tree,
# strip it, and stage the result into pkgs/llamacpp-intel-arc-server/bin/
# so `nixos-rebuild switch` picks it up via the vendored package.
#
# After running this:
#   git -C ~/.config/nix add pkgs/llamacpp-intel-arc-server/bin/
#   git -C ~/.config/nix commit -m "llamacpp-intel-arc: refresh binary"
#   sudo nixos-rebuild switch --flake ~/.config/nix#brutus
#
# git-lfs handles the binary blobs (see .gitattributes).
set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$CONFIG_DIR/pkgs/llamacpp-intel-arc-server/bin"
SRC="${LLAMACPP_BUILD_DIR:-$HOME/Projects/intellm/llamacpp-intel-arc/build-aicss/llama-pr-only/build/bin}"

if [ ! -x "$SRC/llama-server" ]; then
    echo "ERROR: $SRC/llama-server is missing or not executable." >&2
    echo "       Build the binary first via:" >&2
    echo "         (cd ~/Projects/intellm/llamacpp-intel-arc && scripts/build-aicss.sh)" >&2
    exit 1
fi

if ! command -v strip >/dev/null 2>&1; then
    echo "ERROR: strip(1) not on PATH — install binutils first." >&2
    exit 1
fi

mkdir -p "$DEST"

# Wipe any stale files from a previous refresh so renamed/dropped libs
# don't linger.
find "$DEST" -mindepth 1 -maxdepth 1 -delete

# Copy + strip binary and shared libs. We dereference symlinks (-L) and
# only keep the canonical .so.X.Y.Z files; the unversioned and ABI
# symlinks are recreated below.
install -m 0755 "$SRC/llama-server" "$DEST/llama-server"
strip --strip-unneeded "$DEST/llama-server"

shopt -s nullglob
for src in "$SRC"/lib*.so.*.*; do
    base="$(basename "$src")"
    install -m 0755 "$src" "$DEST/$base"
    strip --strip-unneeded "$DEST/$base" || true
done

# Recreate the symlink chain that the runtime linker walks
# (lib<NAME>.so → lib<NAME>.so.<MAJOR> → lib<NAME>.so.<MAJOR>.<MINOR>.<PATCH>).
cd "$DEST"
for full in lib*.so.*.*; do
    soname="${full%.*.*}"
    short="${soname%.*}"
    ln -sf "$full" "$soname"
    ln -sf "$soname" "$short"
done
shopt -u nullglob

echo "staged into $DEST:"
du -sh "$DEST"
ls -la "$DEST"

cat <<EOF

Next steps:
  git -C "$CONFIG_DIR" add .gitattributes pkgs/llamacpp-intel-arc-server/bin/
  git -C "$CONFIG_DIR" commit -m "llamacpp-intel-arc: refresh binary"
  sudo nixos-rebuild switch --flake "$CONFIG_DIR#brutus"
EOF
