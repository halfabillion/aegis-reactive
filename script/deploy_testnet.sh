#!/usr/bin/env bash
# Deploy AegisOrigin and AegisVault on Base Sepolia, and AegisReactive on Lasna.
# Exits before broadcasting when either balance is 0.
# Never prints the key.
set -euo pipefail
set +x
source "$(dirname "$0")/common.sh"

load_key
echo "Deployer: $AEGIS_ADDR"
require_balance "$BASE_RPC" "Base Sepolia"
require_balance "$LASNA_RPC" "Lasna"

LASNA_VALUE="${AEGIS_LASNA_VALUE:-1ether}"
VAULT_FUND="${AEGIS_VAULT_FUND:-0.0005ether}"
mkdir -p "$(dirname "$ENV_OUT")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Deploying AegisOrigin on Base Sepolia ($BASE_CHAIN)."
forge create src/origin/AegisOrigin.sol:AegisOrigin \
  --rpc-url "$BASE_RPC" \
  --private-key "$AEGIS_PK" \
  --broadcast \
  --root "$ROOT" | tee "$WORK/origin.txt"
ORIGIN="$(address_from "$WORK/origin.txt")"
ORIGIN_TX="$(tx_hash_from "$WORK/origin.txt")"

echo "Deploying AegisReactive on Lasna ($LASNA_CHAIN) with value $LASNA_VALUE."
forge create src/reactive/AegisReactive.sol:AegisReactive \
  --rpc-url "$LASNA_RPC" \
  --private-key "$AEGIS_PK" \
  --broadcast \
  --value "$LASNA_VALUE" \
  --root "$ROOT" \
  --constructor-args "$BASE_CHAIN" "$BASE_CHAIN" "$ORIGIN" | tee "$WORK/reactive.txt"
REACTIVE="$(address_from "$WORK/reactive.txt")"
REACTIVE_TX="$(tx_hash_from "$WORK/reactive.txt")"

echo "Deploying AegisVault on Base Sepolia."
forge create src/destination/AegisVault.sol:AegisVault \
  --rpc-url "$BASE_RPC" \
  --private-key "$AEGIS_PK" \
  --broadcast \
  --root "$ROOT" \
  --constructor-args "$CALLBACK_PROXY" "$REACTIVE" | tee "$WORK/vault.txt"
VAULT="$(address_from "$WORK/vault.txt")"
VAULT_TX="$(tx_hash_from "$WORK/vault.txt")"

echo "Setting the vault on the reactive contract."
cast send "$REACTIVE" "setVault(address)" "$VAULT" \
  --rpc-url "$LASNA_RPC" \
  --private-key "$AEGIS_PK" \
  --json | tee "$WORK/setvault.json" >/dev/null
SET_VAULT_TX="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["transactionHash"])' < "$WORK/setvault.json")"

echo "Funding the vault with $VAULT_FUND of Base Sepolia ETH for callback gas."
cast send "$VAULT" --value "$VAULT_FUND" \
  --rpc-url "$BASE_RPC" \
  --private-key "$AEGIS_PK" \
  --json | tee "$WORK/fund.json" >/dev/null
FUND_TX="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["transactionHash"])' < "$WORK/fund.json")"

cat > "$ENV_OUT" << EOF
DEPLOYER=$AEGIS_ADDR
ORIGIN=$ORIGIN
ORIGIN_DEPLOY_TX=$ORIGIN_TX
REACTIVE=$REACTIVE
REACTIVE_DEPLOY_TX=$REACTIVE_TX
VAULT=$VAULT
VAULT_DEPLOY_TX=$VAULT_TX
SET_VAULT_TX=$SET_VAULT_TX
VAULT_FUND_TX=$FUND_TX
EOF
chmod 600 "$ENV_OUT"

echo "Wrote addresses and deploy hashes to $ENV_OUT"
echo "Copy them into DEPLOYMENTS.md. They are not committed from this script."
echo "ORIGIN=$ORIGIN"
echo "REACTIVE=$REACTIVE"
echo "VAULT=$VAULT"
echo "ORIGIN_DEPLOY_TX=$ORIGIN_TX"
echo "REACTIVE_DEPLOY_TX=$REACTIVE_TX"
echo "VAULT_DEPLOY_TX=$VAULT_TX"
echo "SET_VAULT_TX=$SET_VAULT_TX"
echo "VAULT_FUND_TX=$FUND_TX"
