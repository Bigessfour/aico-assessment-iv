#!/usr/bin/env bash
# =============================================================================
# verify.sh — quick grader/ops check of our four namespaces
#
# Checks Deployments Ready, prints ENDPOINT_NAME isolation, and hits
# /health + /ready via short-lived curl pods (no local port-forward required).
# Does not mutate Deployments or ConfigMaps.
#
# Optional: TEAMS=fraud,recommendations (comma-separated allowlist subset)
# =============================================================================
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-codeplatoon}"
DEFAULT_TEAMS=(fraud recommendations forecasting)
ALLOWED="fraud recommendations forecasting"

endpoint_for() {
  case "$1" in
    fraud) echo aico-iv-fraud ;;
    recommendations) echo aico-iv-recs ;;
    forecasting) echo aico-iv-forecast ;;
    *) echo unknown ;;
  esac
}

parse_teams() {
  local raw="${TEAMS:-}"
  TEAMS_ARR=()
  if [[ -z "$raw" ]]; then
    TEAMS_ARR=("${DEFAULT_TEAMS[@]}")
    return
  fi
  local team
  IFS=',' read -ra RAW <<< "$raw"
  for team in "${RAW[@]}"; do
    team="$(echo "$team" | xargs)"
    case " $ALLOWED " in
      *" $team "*) TEAMS_ARR+=("$team") ;;
      *)
        echo "Refusing unknown team '$team' (allowlist: $ALLOWED)" >&2
        exit 1
        ;;
    esac
  done
}

curl_once() {
  local ns="$1" name="$2" url="$3"
  kubectl -n "$ns" delete pod "$name" --ignore-not-found --wait=true >/dev/null 2>&1 || true
  kubectl -n "$ns" run "$name" \
    --restart=Never \
    --image=curlimages/curl:8.5.0 \
    --labels="aico-iv=verify" \
    --command -- sh -c "curl -sf '${url}/health' && echo && curl -sf '${url}/ready' && echo"
  if ! kubectl -n "$ns" wait --for=jsonpath='{.status.phase}'=Succeeded "pod/$name" --timeout=90s; then
    echo "FAIL curl pod $ns/$name"
    kubectl -n "$ns" describe "pod/$name" | tail -40 || true
    kubectl -n "$ns" logs "$name" || true
    kubectl -n "$ns" delete pod "$name" --ignore-not-found --wait=false >/dev/null 2>&1 || true
    return 1
  fi
  kubectl -n "$ns" logs "$name"
  kubectl -n "$ns" delete pod "$name" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  return 0
}

parse_teams
fail=0

echo "== namespaces =="
kubectl get ns fraud recommendations forecasting platform

echo
echo "== deployments =="
for ns in "${TEAMS_ARR[@]}" platform; do
  kubectl -n "$ns" get deploy
done

echo
echo "== pods =="
for ns in "${TEAMS_ARR[@]}" platform; do
  kubectl -n "$ns" get pods
done

echo
echo "== ENDPOINT_NAME isolation (ConfigMap) =="
for team in "${TEAMS_ARR[@]}"; do
  got="$(kubectl -n "$team" get configmap "${team}-config" -o jsonpath='{.data.ENDPOINT_NAME}')"
  want="$(endpoint_for "$team")"
  if [[ "$got" == "$want" ]]; then
    echo "OK  $team → $got"
  else
    echo "FAIL $team → got='$got' want='$want'"
    fail=1
  fi
done

echo
echo "== in-cluster /health + /ready =="
for team in "${TEAMS_ARR[@]}"; do
  echo "--- $team ---"
  if ! curl_once "$team" "verify-${team}-$$" "http://${team}-api.${team}.svc.cluster.local"; then
    fail=1
  fi
done
echo "--- gateway ---"
if ! curl_once platform "verify-gateway-$$" "http://gateway-api.platform.svc.cluster.local"; then
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  echo
  echo "VERIFY FAILED"
  exit 1
fi
echo
echo "VERIFY OK"
