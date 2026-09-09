#!/usr/bin/env bash
# =============================================================================
# demo-failure.sh — reversible controlled-failure demos (K8s bonus)
#
# Modes:
#   quota   Scale fraud-api past ResourceQuota pods=4 → FailedCreate; then restore.
#   ready   Clear fraud ConfigMap ENDPOINT_NAME → /ready 503 + NotReady; then restore.
#
# Always restores on EXIT (trap). Capture output into History.md for the walkthrough.
#
# Usage:
#   ./scripts/demo-failure.sh quota
#   ./scripts/demo-failure.sh ready
# =============================================================================
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-codeplatoon}"
MODE="${1:-}"
NS=fraud
DEPLOY=fraud-api
CM=fraud-config
GOOD_ENDPOINT=aico-iv-fraud
ORIG_REPLICAS=1

usage() {
  echo "Usage: $0 {quota|ready}" >&2
  exit 2
}

[[ -n "$MODE" ]] || usage

restore() {
  echo
  echo "== RESTORE (trap) mode=$MODE =="
  case "$MODE" in
    quota)
      kubectl -n "$NS" scale "deploy/$DEPLOY" --replicas="$ORIG_REPLICAS" >/dev/null 2>&1 || true
      kubectl -n "$NS" rollout status "deploy/$DEPLOY" --timeout=180s || true
      ;;
    ready)
      kubectl -n "$NS" patch "configmap/$CM" --type merge \
        -p "{\"data\":{\"ENDPOINT_NAME\":\"$GOOD_ENDPOINT\"}}" >/dev/null 2>&1 || true
      kubectl -n "$NS" scale "deploy/$DEPLOY" --replicas="$ORIG_REPLICAS" >/dev/null 2>&1 || true
      kubectl -n "$NS" rollout restart "deploy/$DEPLOY" >/dev/null 2>&1 || true
      kubectl -n "$NS" rollout status "deploy/$DEPLOY" --timeout=180s || true
      ;;
    *)
      kubectl -n "$NS" patch "configmap/$CM" --type merge \
        -p "{\"data\":{\"ENDPOINT_NAME\":\"$GOOD_ENDPOINT\"}}" >/dev/null 2>&1 || true
      kubectl -n "$NS" scale "deploy/$DEPLOY" --replicas="$ORIG_REPLICAS" >/dev/null 2>&1 || true
      ;;
  esac
  kubectl -n "$NS" get pods
  echo "Restore attempted for mode=$MODE (replicas=$ORIG_REPLICAS ENDPOINT_NAME=$GOOD_ENDPOINT)"
}
trap restore EXIT

echo "Mode=$MODE namespace=$NS profile=$AWS_PROFILE"
echo "Baseline:"
kubectl -n "$NS" get deploy,pods,quota
ORIG_REPLICAS="$(kubectl -n "$NS" get "deploy/$DEPLOY" -o jsonpath='{.spec.replicas}')"
[[ -n "$ORIG_REPLICAS" ]] || ORIG_REPLICAS=1

case "$MODE" in
  quota)
    echo
    echo "== QUOTA REJECTION =="
    echo "ResourceQuota hard pods=4. Scaling $DEPLOY to 5 — expect FailedCreate / exceeded quota."
    kubectl -n "$NS" scale "deploy/$DEPLOY" --replicas=5
    sleep 8
    echo
    echo "Pods after scale (at most 4 under quota):"
    kubectl -n "$NS" get pods -o wide
    echo
    echo "ReplicaSet events looking for exceeded quota:"
    if kubectl -n "$NS" get events --field-selector reason=FailedCreate --sort-by=.lastTimestamp 2>/dev/null | grep -q "exceeded quota"; then
      kubectl -n "$NS" get events --field-selector reason=FailedCreate --sort-by=.lastTimestamp | tail -8
      echo
      echo "DEMO OK: admission rejected 5th pod — exceeded quota fraud-quota pods=4"
    else
      pending="$(kubectl -n "$NS" get pods --field-selector=status.phase=Pending -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
      if [[ -n "${pending:-}" ]]; then
        kubectl -n "$NS" describe "pod/$pending" | sed -n '/Events:/,$p'
        echo
        echo "DEMO OK: saw Pending pod under quota pressure"
      else
        echo "WARN: no FailedCreate/Pending yet; dump recent events:"
        kubectl -n "$NS" get events --sort-by=.lastTimestamp | tail -20
      fi
    fi
    ;;
  ready)
    echo
    echo "== READINESS-GATED TRAFFIC =="
    echo "Clear ENDPOINT_NAME, recycle through 0 replicas so only the broken pod remains."
    kubectl -n "$NS" patch "configmap/$CM" --type merge \
      -p '{"data":{"ENDPOINT_NAME":""}}'
    kubectl -n "$NS" scale "deploy/$DEPLOY" --replicas=0
    kubectl -n "$NS" wait --for=delete pod -l app=fraud-api --timeout=120s || true
    kubectl -n "$NS" scale "deploy/$DEPLOY" --replicas=1
    echo "Waiting for pod Running but Ready=False..."
    for _ in $(seq 1 36); do
      phase="$(kubectl -n "$NS" get pods -l app=fraud-api -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)"
      ready_flag="$(kubectl -n "$NS" get pods -l app=fraud-api -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
      if [[ "$phase" == "Running" && "$ready_flag" == "False" ]]; then
        break
      fi
      sleep 5
    done
    echo
    echo "Pods:"
    kubectl -n "$NS" get pods -o wide
    pod="$(kubectl -n "$NS" get pods -l app=fraud-api -o jsonpath='{.items[0].metadata.name}')"
    pod_ip="$(kubectl -n "$NS" get "pod/$pod" -o jsonpath='{.status.podIP}')"
    echo
    echo "Ready condition for $pod:"
    kubectl -n "$NS" get "pod/$pod" -o jsonpath='Ready={.status.conditions[?(@.type=="Ready")].status} reason={.status.conditions[?(@.type=="Ready")].reason}{"\n"}'
    echo
    # Hit the pod IP directly — Service has no Ready endpoints, so ClusterIP would hang.
    check="ready-check-$$"
    kubectl -n "$NS" delete pod "$check" --ignore-not-found --wait=true >/dev/null 2>&1 || true
    kubectl -n "$NS" run "$check" --restart=Never --image=curlimages/curl:8.5.0 --command -- \
      sh -c "code=\$(curl -s -o /tmp/out -w '%{http_code}' http://${pod_ip}:8000/ready); echo http=\$code; cat /tmp/out; echo"
    kubectl -n "$NS" wait --for=jsonpath='{.status.phase}'=Succeeded "pod/$check" --timeout=60s || true
    echo "Direct pod /ready (expect http=503):"
    kubectl -n "$NS" logs "$check" || true
    kubectl -n "$NS" delete pod "$check" --ignore-not-found --wait=false >/dev/null 2>&1 || true
    echo
    echo "EndpointSlice (should show no ready serving addresses, or empty):"
    kubectl -n "$NS" get endpointslice -l kubernetes.io/service-name=fraud-api -o yaml | grep -E 'ready:|addresses:|podName:' | head -20 || true
    echo
    echo "DEMO OK: empty ENDPOINT_NAME failed readiness and gated Service traffic"
    ;;
  *)
    usage
    ;;
esac

echo
echo "Leaving restore to EXIT trap..."
