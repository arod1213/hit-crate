#!/bin/bash
set -euo pipefail

sudo -rm rf dist
sudo -rm rf build

echo "Build and Dist folders cleared"

flatten_symlink.sh
flatten_app.sh

echo "Symlinks removed"

python3 setup.py py2app
bash makefile.sh