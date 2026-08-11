#!/bin/bash
# ============================================================================
# MaaS Code Assistant — Status Check
# ============================================================================

verify_deployment() {
  local overall_status="READY"
  local components=()

  # ---- Helm releases ----
  log_status "running" "verifying" "Checking Helm releases..."

  local dep_release
  dep_release=$(helm list -A -o json 2>/dev/null | jq -r '.[] | select(.name == "dependency-operators") | .status' 2>/dev/null || echo "")
  if [[ "$dep_release" == "deployed" ]]; then
    components+=("{\"name\":\"dependency-operators\",\"status\":\"ready\",\"detail\":\"Helm release deployed\"}")
  elif [[ -z "$dep_release" ]]; then
    components+=("{\"name\":\"dependency-operators\",\"status\":\"missing\",\"detail\":\"Helm release not found\"}")
    overall_status="NOT_INSTALLED"
  else
    components+=("{\"name\":\"dependency-operators\",\"status\":\"degraded\",\"detail\":\"Helm release status: ${dep_release}\"}")
    overall_status="DEGRADED"
  fi

  local main_release
  main_release=$(helm list -A -o json 2>/dev/null | jq -r '.[] | select(.name == "maas-code-assistant") | .status' 2>/dev/null || echo "")
  if [[ "$main_release" == "deployed" ]]; then
    components+=("{\"name\":\"maas-code-assistant\",\"status\":\"ready\",\"detail\":\"Helm release deployed\"}")
  elif [[ -z "$main_release" ]]; then
    components+=("{\"name\":\"maas-code-assistant\",\"status\":\"missing\",\"detail\":\"Helm release not found\"}")
    if [[ "$overall_status" != "DEGRADED" ]]; then
      overall_status="NOT_INSTALLED"
    fi
  else
    components+=("{\"name\":\"maas-code-assistant\",\"status\":\"degraded\",\"detail\":\"Helm release status: ${main_release}\"}")
    overall_status="DEGRADED"
  fi

  # If nothing is installed, report clean state and return early
  if [[ "$overall_status" == "NOT_INSTALLED" ]]; then
    local comp_json
    comp_json=$(printf '%s,' "${components[@]}")
    comp_json="[${comp_json%,}]"
    echo "{\"status\":\"NOT_INSTALLED\",\"message\":\"Quickstart is not installed\",\"components\":${comp_json}}"
    return 0
  fi

  # ---- Model inference services ----
  log_status "running" "verifying" "Checking model deployments..."

  local model_total model_ready
  model_total=$(oc get llminferenceservice -n llm -o json 2>/dev/null | jq '.items | length' 2>/dev/null || echo "0")
  model_ready=$(oc get llminferenceservice -n llm -o json 2>/dev/null | \
    jq '[.items[] | select(.status.conditions[]? | select(.type == "Ready" and .status == "True"))] | length' 2>/dev/null || echo "0")

  if [[ "$model_total" -eq 0 ]]; then
    components+=("{\"name\":\"models\",\"status\":\"missing\",\"detail\":\"No LLMInferenceService resources found in llm namespace\"}")
    overall_status="DEGRADED"
  elif [[ "$model_ready" -eq "$model_total" ]]; then
    components+=("{\"name\":\"models\",\"status\":\"ready\",\"detail\":\"${model_ready}/${model_total} models ready\"}")
  else
    components+=("{\"name\":\"models\",\"status\":\"degraded\",\"detail\":\"${model_ready}/${model_total} models ready\"}")
    overall_status="DEGRADED"
  fi

  # ---- Keycloak ----
  log_status "running" "verifying" "Checking Keycloak..."

  local kc_ready
  kc_ready=$(oc get keycloak keycloak -n keycloak -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
  if [[ "$kc_ready" == "True" ]]; then
    components+=("{\"name\":\"keycloak\",\"status\":\"ready\",\"detail\":\"Keycloak instance ready\"}")
  elif [[ -z "$kc_ready" ]]; then
    components+=("{\"name\":\"keycloak\",\"status\":\"missing\",\"detail\":\"Keycloak CR not found in keycloak namespace\"}")
    overall_status="DEGRADED"
  else
    components+=("{\"name\":\"keycloak\",\"status\":\"degraded\",\"detail\":\"Keycloak not ready\"}")
    overall_status="DEGRADED"
  fi

  # ---- DataScienceCluster ----
  log_status "running" "verifying" "Checking OpenShift AI..."

  local dsc_ready
  dsc_ready=$(oc get datasciencecluster default-dsc -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
  if [[ "$dsc_ready" == "True" ]]; then
    components+=("{\"name\":\"openshift-ai\",\"status\":\"ready\",\"detail\":\"DataScienceCluster ready\"}")
  elif [[ -z "$dsc_ready" ]]; then
    components+=("{\"name\":\"openshift-ai\",\"status\":\"missing\",\"detail\":\"DataScienceCluster not found\"}")
    overall_status="DEGRADED"
  else
    components+=("{\"name\":\"openshift-ai\",\"status\":\"degraded\",\"detail\":\"DataScienceCluster not ready\"}")
    overall_status="DEGRADED"
  fi

  # ---- Kuadrant ----
  log_status "running" "verifying" "Checking Kuadrant..."

  local kuadrant_ready
  kuadrant_ready=$(oc get kuadrant -n kuadrant-system -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
  if [[ "$kuadrant_ready" == "True" ]]; then
    components+=("{\"name\":\"kuadrant\",\"status\":\"ready\",\"detail\":\"Kuadrant ready\"}")
  elif [[ -z "$kuadrant_ready" ]]; then
    components+=("{\"name\":\"kuadrant\",\"status\":\"missing\",\"detail\":\"Kuadrant CR not found\"}")
    overall_status="DEGRADED"
  else
    components+=("{\"name\":\"kuadrant\",\"status\":\"degraded\",\"detail\":\"Kuadrant not ready\"}")
    overall_status="DEGRADED"
  fi

  # ---- Route accessibility ----
  log_status "running" "verifying" "Checking routes..."

  local keycloak_host
  keycloak_host=$(oc get route keycloak -n keycloak -ojsonpath='{.spec.host}' 2>/dev/null || echo "")
  if [[ -n "$keycloak_host" ]]; then
    local kc_http_code
    kc_http_code=$(curl -sk -o /dev/null -w '%{http_code}' "https://${keycloak_host}/health/ready" 2>/dev/null || echo "000")
    if [[ "$kc_http_code" -ge 200 ]] && [[ "$kc_http_code" -lt 400 ]]; then
      components+=("{\"name\":\"keycloak-route\",\"status\":\"ready\",\"detail\":\"Route reachable (HTTP ${kc_http_code})\"}")
    else
      components+=("{\"name\":\"keycloak-route\",\"status\":\"degraded\",\"detail\":\"Route returned HTTP ${kc_http_code}\"}")
      overall_status="DEGRADED"
    fi
  else
    components+=("{\"name\":\"keycloak-route\",\"status\":\"missing\",\"detail\":\"Keycloak route not found\"}")
    overall_status="DEGRADED"
  fi

  # ---- Build result ----
  local comp_json
  comp_json=$(printf '%s,' "${components[@]}")
  comp_json="[${comp_json%,}]"

  echo "{\"status\":\"${overall_status}\",\"components\":${comp_json}}"
}
