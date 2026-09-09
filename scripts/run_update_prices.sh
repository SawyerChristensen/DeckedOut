#!/usr/bin/env bash
# Convenience wrapper for update_iap_prices.py.
#
# Pushes IAP price changes from "StoreKit Config.storekit" to App Store Connect,
# using the project-local virtualenv (the same .venv as run.sh / run_iaps.sh,
# created and populated on first use). All arguments are forwarded through.
#
# Examples:
#   ./run_update_prices.sh --dry-run                # show every planned change
#   ./run_update_prices.sh                          # apply (prompts to confirm)
#   ./run_update_prices.sh --yes                    # apply without the prompt
#   ./run_update_prices.sh --only RedFoxEnchanted   # limit to matching product IDs
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -x .venv/bin/python ]; then
    echo "Setting up virtualenv (first run)..."
    python3 -m venv .venv
    .venv/bin/pip install --quiet --upgrade pip
    .venv/bin/pip install --quiet -r requirements.txt
fi

exec .venv/bin/python update_iap_prices.py "$@"
