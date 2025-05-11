#!/bin/bash
set -euo pipefail

APP_DIR="dist/Hit Crate.app"

echo "🔍 Flattening symlinks in: $APP_DIR"

find "$APP_DIR" -type l | while read -r symlink; do
  target=$(readlink "$symlink")

  # Resolve relative paths
  if [[ "$target" != /* ]]; then
    abs_target=$(cd "$(dirname "$symlink")" && cd "$(dirname "$target")" && pwd)/$(basename "$target")
  else
    abs_target="$target"
  fi

  echo "📦 Replacing symlink: $symlink → $abs_target"
  rm "$symlink"

  if [ -d "$abs_target" ]; then
    cp -R "$abs_target" "$symlink"
  else
    cp "$abs_target" "$symlink"
  fi
done

echo "✅ Done flattening symlinks."

