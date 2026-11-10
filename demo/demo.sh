#!/usr/bin/env bash
# One-command local demo. Does not deploy to a public network and does not read a key.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="${HOME}/.foundry/bin:${PATH}"
exec python3 demo/run_demo.py
