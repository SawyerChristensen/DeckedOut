#!/usr/bin/env bash
# Convenience wrapper for upload_metadata.py.
#
# Runs the uploader with the project-local virtualenv so you never have to
# activate it or remember its path. Creates the venv and installs requirements
# on first use (or after you delete .venv), then forwards all arguments through.
#
# Examples:
#   ./run.sh --dry-run                     # preview what would be uploaded
#   ./run.sh --create-version 3.6.0        # make the editable version, then upload
#   ./run.sh --skip-achievements           # only push App Store version metadata
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -x .venv/bin/python ]; then
    echo "Setting up virtualenv (first run)..."
    python3 -m venv .venv
    .venv/bin/pip install --quiet --upgrade pip
    .venv/bin/pip install --quiet -r requirements.txt
fi

exec .venv/bin/python upload_metadata.py "$@"
