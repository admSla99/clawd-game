#!/usr/bin/env bash
# Installs the pinned Godot editor and its web export templates for Linux x86_64.
# Idempotent: re-running skips what is already in place.
set -euo pipefail

VERSION=4.7.2
TAG="$VERSION-stable"
BASE="https://github.com/godotengine/godot/releases/download/$TAG"
EDITOR_ZIP="Godot_v${TAG}_linux.x86_64.zip"
TEMPLATES_TPZ="Godot_v${TAG}_export_templates.tpz"

OPT_DIR="$HOME/.local/opt/godot/$TAG"
BIN_DIR="$HOME/.local/bin"
TEMPLATES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$VERSION.stable"

# Downloads are kept here until installed, so an interrupted run resumes where it stopped.
dl="${XDG_CACHE_HOME:-$HOME/.cache}/godot-install/$TAG"
mkdir -p "$dl"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# HTTP/1.1: GitHub's CDN has dropped long HTTP/2 downloads mid-way ("PROTOCOL_ERROR").
# -C - resumes a partial file; the loop retries until the file is complete.
fetch() {
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    curl -fL --http1.1 -C - -o "$dl/$1" "$BASE/$1" && return 0
    echo "download of $1 interrupted, resuming (attempt $attempt)" >&2
    sleep 3
  done
  return 1
}
verify() { (cd "$dl" && grep " $1\$" SHA512-SUMS.txt | sha512sum -c -); }

curl -fsL --http1.1 -o "$dl/SHA512-SUMS.txt" "$BASE/SHA512-SUMS.txt"

if [ ! -x "$OPT_DIR/godot" ]; then
  fetch "$EDITOR_ZIP" && verify "$EDITOR_ZIP"
  mkdir -p "$OPT_DIR"
  unzip -q "$dl/$EDITOR_ZIP" -d "$tmp/editor"
  mv "$tmp/editor/Godot_v${TAG}_linux.x86_64" "$OPT_DIR/godot"
  chmod +x "$OPT_DIR/godot"
  rm -f "$dl/$EDITOR_ZIP"
fi
mkdir -p "$BIN_DIR"
ln -sf "$OPT_DIR/godot" "$BIN_DIR/godot"

# Only the web templates are kept; the full .tpz also holds every other platform.
if [ ! -f "$TEMPLATES_DIR/web_nothreads_release.zip" ]; then
  fetch "$TEMPLATES_TPZ" && verify "$TEMPLATES_TPZ"
  unzip -q "$dl/$TEMPLATES_TPZ" 'templates/web*' 'templates/version.txt' -d "$tmp/tpl"
  mkdir -p "$TEMPLATES_DIR"
  mv "$tmp/tpl/templates/"* "$TEMPLATES_DIR/"
  rm -f "$dl/$TEMPLATES_TPZ"
fi

"$BIN_DIR/godot" --version
ls "$TEMPLATES_DIR"
