#!/usr/bin/env bash
# Convenience wrapper for upload_iaps.py.
#
# Runs the IAP reconciler with the project-local virtualenv so you never have to
# activate it or remember its path. Reuses the same .venv as run.sh, creating it
# and installing requirements on first use, then forwards all arguments through.
#
# Examples:
#   ./run_iaps.sh --dry-run                  # preview what would be created
#   ./run_iaps.sh                            # create / complete every theme IAP
#   ./run_iaps.sh --only AmericanFlag        # limit to product IDs matching a substring
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -x .venv/bin/python ]; then
    echo "Setting up virtualenv (first run)..."
    python3 -m venv .venv
    .venv/bin/pip install --quiet --upgrade pip
    .venv/bin/pip install --quiet -r requirements.txt
fi

exec .venv/bin/python upload_iaps.py "$@"
