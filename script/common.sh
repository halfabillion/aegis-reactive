#!/usr/bin/env bash
# Shared helpers for the testnet scripts. They read a key file and never echo it.
set -euo pipefail
set +x

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.foundry/bin:${PATH}"

BASE_RPC="${BASE_SEPOLIA_RPC:-https://sepolia.base.org}"
LASNA_RPC="${LASNA_RPC:-https://lasna-rpc.rnk.dev/}"
KEY_FILE="${AEGIS_KEY_FILE:-.secrets/key}"
ENV_OUT="${AEGIS_ENV_OUT:-.secrets/deployed.env}"
BASE_CHAIN=84532
LASNA_CHAIN=5318007
CALLBACK_PROXY=0x476F44b11F5C942c58f4c8E3d0300E5710743585
FEED=1
ENTRY=100000000000
SIZE=1000000

load_key() {
  if [[ ! -f "$KEY_FILE" ]]; then
    echo "Missing key file ($KEY_FILE). Refusing to continue. The key is not printed."
    exit 1
  fi
  AEGIS_PK="$(tr -d '[:space:]' < "$KEY_FILE")"
  if [[ ! "$AEGIS_PK" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
    echo "Key file is not a 32-byte hex key. Refusing to continue. The file is not printed."
    exit 1
  fi
  AEGIS_ADDR="$(cast wallet address --private-key "$AEGIS_PK")"
}

require_balance() {
  local rpc="$1"
  local label="$2"
  local bal
  bal="$(cast balance "$AEGIS_ADDR" --rpc-url "$rpc")"
  echo "$label balance wei: $bal"
  if [[ "$bal" == "0" ]]; then
    echo "$label balance is 0. Stopping before any transaction."
    exit 1
  fi
}

tx_hash_from() {
  local file="$1"
  awk '/Transaction hash:/{print $3; exit}' "$file"
}

address_from() {
  local file="$1"
  awk '/Deployed to:/{print $3; exit}' "$file"
}
