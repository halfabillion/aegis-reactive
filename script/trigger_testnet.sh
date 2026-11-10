#!/usr/bin/env bash
# Replay the local demo's origin events on Base Sepolia.
# Lasna delivers react() and the Base Sepolia callback on its own.
# This script sleeps between steps. It does not poll explorers.
# Never prints the key.
set -euo pipefail
set +x
source "$(dirname "$0")/common.sh"

load_key
if [[ ! -f "$ENV_OUT" ]]; then
  echo "Missing $ENV_OUT. Run script/deploy_testnet.sh first."
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_OUT"
require_balance "$BASE_RPC" "Base Sepolia"
require_balance "$LASNA_RPC" "Lasna"

STEP_WAIT="${AEGIS_STEP_WAIT:-60}"

send() {
  local out hash
  out="$(cast send "$1" "$2" "${@:3}" \
    --rpc-url "$BASE_RPC" \
    --private-key "$AEGIS_PK" \
    --json)"
  hash="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["transactionHash"])' <<<"$out")"
  echo "tx $hash"
}

pause() {
  echo "Waiting ${STEP_WAIT}s so the previous callback can land. Not polling."
  sleep "$STEP_WAIT"
}

timestamp() {
  cast block latest --field timestamp --rpc-url "$BASE_RPC"
}

policy_json() {
  local epoch="$1"
  shift
  python3 - "$epoch" "$@" << 'PY'
import sys
from scorer.aegis_scorer import score
epoch = int(sys.argv[1])
prices = [int(x) for x in sys.argv[2:]]
policy = score(prices, 100000000000, epoch)
print(policy.epoch)
print(policy.stop_bps)
print(policy.action)
print(policy.confidence_bps)
print(policy.features_hash)
print(policy.action_name)
PY
}

post_policy() {
  local epoch="$1"
  shift
  mapfile -t fields < <(policy_json "$epoch" "$@")
  if [[ "${#fields[@]}" -ne 6 ]]; then
    echo "Scorer returned ${#fields[@]} lines, expected 6."
    exit 1
  fi
  echo "epoch ${fields[0]} action ${fields[5]} stop ${fields[1]} bps confidence ${fields[3]} bps"
  send "$ORIGIN" "postPolicy(uint256,uint64,uint16,uint8,uint16,bytes32)" \
    "$FEED" "${fields[0]}" "${fields[1]}" "${fields[2]}" "${fields[3]}" "${fields[4]}"
}

push_price() {
  local price="$1"
  local ts
  ts="$(timestamp)"
  send "$ORIGIN" "pushPrice(uint256,uint256,uint64)" "$FEED" "$price" "$ts"
}

echo "Opening feed $FEED at entry $ENTRY on the vault and the origin."
send "$VAULT" "openPosition(uint256,uint256,uint256)" "$FEED" "$ENTRY" "$SIZE"
send "$ORIGIN" "openPosition(uint256,uint256,uint256)" "$FEED" "$ENTRY" "$SIZE"
pause

calm=(100000000000 100100000000 99900000000 100200000000 99950000000 100050000000 100000000000)
post_policy 1 "${calm[@]}"
pause
push_price 100000000000
pause

wick=(100000000000 100000000000 100000000000 94000000000 100000000000)
post_policy 2 "${wick[@]}"
pause

grind_last=100000000000
grind=()
for _ in 1 2 3 4; do
  grind+=("$grind_last")
  grind_last=$((grind_last * 99 / 100))
done
post_policy 3 "${grind[@]}"
pause
push_price "${grind[-1]}"
pause

crash_last=100000000000
crash=()
for _ in 1 2 3 4 5 6 7 8; do
  crash+=("$crash_last")
  crash_last=$((crash_last * 97 / 100))
done
post_policy 4 "${crash[@]}"
pause
push_price "${crash[-1]}"

echo "Origin transactions are on Base Sepolia."
echo "Look up the matching react() transactions on https://lasna.reactscan.net and the callbacks on https://sepolia.basescan.org"
echo "Paste those hashes into DEPLOYMENTS.md. This script does not watch for them."
