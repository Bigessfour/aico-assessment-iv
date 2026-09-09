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

# #region agent log
_dbg() {
  python3 -c "
import json,time,os
p='/Users/stephenmckitrick/Assessment 4/.cursor/debug-d8a8cd.log'
d={
  'sessionId':'d8a8cd',
  'timestamp':int(time.time()*1000),
  'location':'scripts/verify.sh',
  'message':'''$1''',
  'hypothesisId':'''$2''',
  'runId':os.environ.get('DEBUG_RUN_ID','pre-fix'),
  'data':{
    'AWS_PROFILE':os.environ.get('AWS_PROFILE'),
    'has_access_key':bool(os.environ.get('AWS_ACCESS_KEY_ID')),
    'has_secret_key':bool(os.environ.get('AWS_SECRET_ACCESS_KEY')),
    'AWS_CONFIG_FILE':os.environ.get('AWS_CONFIG_FILE'),
    'AWS_SHARED_CREDENTIALS_FILE':os.environ.get('AWS_SHARED_CREDENTIALS_FILE'),
    'extra':'''${3:-}''',
  },
}
open(p,'a').write(json.dumps(d)+'\n')
" 2>/dev/null || true
}
_dbg "verify.sh entry before profile default" "A" "raw_profile=${AWS_PROFILE-<<unset>>}"
# #endregion

# GitHub Actions injects AWS_ACCESS_KEY_ID via configure-aws-credentials and has no
# ~/.aws/config profile named codeplatoon. Forcing AWS_PROFILE=codeplatoon there
# breaks `aws eks get-token` / kubectl. Only default a local profile when no keys.
if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
  export AWS_PROFILE="${AWS_PROFILE:-codeplatoon}"
fi

# #region agent log
_profile_exists="no"
if [[ -n "${AWS_CONFIG_FILE:-}" ]]; then
  _cfg="$AWS_CONFIG_FILE"
else
  _cfg="${HOME}/.aws/config"
fi
if [[ -n "${AWS_PROFILE:-}" && -f "$_cfg" ]] && grep -q "\\[profile ${AWS_PROFILE}\\]\\|\\[${AWS_PROFILE}\\]" "$_cfg" 2>/dev/null; then
  _profile_exists="yes"
fi
_dbg "after AWS_PROFILE policy" "A" "profile_exists_in_config=${_profile_exists};config=${_cfg};profile_now=${AWS_PROFILE-<<unset>>}"
_aws_out="$(aws sts get-caller-identity 2>&1 | head -c 200 | tr '\n' ' ' || true)"
_dbg "aws sts get-caller-identity" "B" "${_aws_out}"
_k_out="$(kubectl get ns fraud -o name 2>&1 | head -c 200 | tr '\n' ' ' || true)"
_dbg "kubectl get ns fraud" "A" "${_k_out}"
# #endregion

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
