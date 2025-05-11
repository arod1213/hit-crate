#!/bin/bash
set -euo pipefail

echo "🔍 Locating your current Python path..."
PYTHON_BIN="$(which python3)"
PYTHON_FRAMEWORK_ROOT="$(dirname "$(dirname "$PYTHON_BIN")")/Frameworks/Python.framework"

echo "🧹 Flattening symlinks in Python.framework..."

flatten_symlink() {
  local link_path="$1"
  if [ -L "$link_path" ]; then
    local target="$(readlink "$link_path")"
    local abs_target

    # Handle relative symlink targets
    if [[ "$target" != /* ]]; then
      abs_target="$(cd "$(dirname "$link_path")" && cd "$(dirname "$target")" && pwd)/$(basename "$target")"
    else
      abs_target="$target"
    fi

    echo "⚠️  Replacing symlink: $link_path -> $abs_target"

    rm "$link_path"

    if [ -d "$abs_target" ]; then
      cp -R "$abs_target" "$link_path"
    else
      cp "$abs_target" "$link_path"
    fi
  fi
}

# --- Specific symlinks to flatten ---
SYMLINKS_TO_FLATTEN=(
  "$PYTHON_FRAMEWORK_ROOT/Python.framework/Python"
  "$PYTHON_FRAMEWORK_ROOT/Python.framework/Resources"
  "$PYTHON_FRAMEWORK_ROOT/Python.framework/Versions/Current"
)

for path in "${SYMLINKS_TO_FLATTEN[@]}"; do
  flatten_symlink "$path"
done

# Also flatten site.pyo if needed (you can check where site.pyo lives)
SITE_PYO_SRC="$PYTHON_FRAMEWORK_ROOT/Python.framework/Versions/3.13/lib/python3.13/site.pyo"
SITE_PYO_LINK="$PYTHON_FRAMEWORK_ROOT/Python.framework/Versions/3.13/lib/python3.13/site.pyo"

if [ -L "$SITE_PYO_LINK" ]; then
  echo "⚠️  Flattening site.pyo symlink..."
  rm "$SITE_PYO_LINK"
  cp "$SITE_PYO_SRC" "$SITE_PYO_LINK"
fi

# libogg.dylib (check inside your actual site-packages or wherever it's found)
OGG_PATH="$PYTHON_FRAMEWORK_ROOT/Python.framework/Versions/3.13/lib/libogg.0.dylib"
if [ -L "$OGG_PATH" ]; then
  real_ogg="$(readlink "$OGG_PATH")"
  echo "⚠️  Replacing libogg.0.dylib -> $real_ogg"
  rm "$OGG_PATH"
  cp "$PYTHON_FRAMEWORK_ROOT/Python.framework/Versions/3.13/lib/$real_ogg" "$OGG_PATH"
fi

echo "✅ Symlinks flattened. You can now run py2app safely."
