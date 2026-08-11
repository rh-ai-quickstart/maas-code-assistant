#!/bin/bash
# ============================================================================
# MaaS Code Assistant — Prerequisites Check
# ============================================================================

check_prerequisites() {
  local missing=()

  # ---- OpenShift version ----
  log_status "running" "validating" "Checking OpenShift version..."
  local ocp_version
  ocp_version=$(oc get clusterversion version -o jsonpath='{.status.desired.version}' 2>/dev/null || echo "")
  if [[ -z "$ocp_version" ]]; then
    missing+=("{\"name\":\"OpenShift Version\",\"reason\":\"Unable to determine OpenShift version. Are you logged in with cluster-admin?\"}")
  else
    local ocp_major ocp_minor
    ocp_major=$(echo "$ocp_version" | cut -d. -f1)
    ocp_minor=$(echo "$ocp_version" | cut -d. -f2)
    if [[ "$ocp_major" -lt 4 ]] || { [[ "$ocp_major" -eq 4 ]] && [[ "$ocp_minor" -lt 20 ]]; }; then
      missing+=("{\"name\":\"OpenShift Version\",\"reason\":\"Requires OpenShift 4.20+, found ${ocp_version}\"}")
    else
      log_status "running" "validating" "OpenShift version ${ocp_version} OK"
    fi
  fi

  # ---- Cluster-admin access ----
  log_status "running" "validating" "Checking cluster-admin access..."
  if ! oc auth can-i create namespaces --all-namespaces 2>/dev/null | grep -q "yes"; then
    missing+=("{\"name\":\"Cluster Admin\",\"reason\":\"Current user does not have cluster-admin privileges\"}")
  fi

  # ---- Default StorageClass ----
  log_status "running" "validating" "Checking for default StorageClass..."
  local default_sc
  default_sc=$(oc get storageclass -o json 2>/dev/null | \
    jq -r '.items[] | select(.metadata.annotations["storageclass.kubernetes.io/is-default-class"] == "true") | .metadata.name' 2>/dev/null || echo "")
  if [[ -z "$default_sc" ]]; then
    missing+=("{\"name\":\"Default StorageClass\",\"reason\":\"No default StorageClass found. A default StorageClass with ReadWriteOnce access is required.\"}")
  else
    log_status "running" "validating" "Default StorageClass '${default_sc}' found"
  fi

  # ---- NVIDIA GPU Operator ----
  log_status "running" "validating" "Checking NVIDIA GPU Operator..."
  local gpu_csv
  gpu_csv=$(oc get csv -A 2>/dev/null | grep -i "gpu-operator" | grep -i "succeeded" || echo "")
  if [[ -z "$gpu_csv" ]]; then
    missing+=("{\"name\":\"NVIDIA GPU Operator\",\"reason\":\"NVIDIA GPU Operator is not installed or not in Succeeded phase. Install it and configure a ClusterPolicy before deploying this quickstart.\"}")
  else
    log_status "running" "validating" "NVIDIA GPU Operator found and Succeeded"
  fi

  # ---- GPU nodes with sufficient VRAM ----
  log_status "running" "validating" "Checking for GPU nodes..."
  local gpu_node_count
  gpu_node_count=$(oc get nodes -o json 2>/dev/null | \
    jq '[.items[] | select(.status.capacity["nvidia.com/gpu"] != null and (.status.capacity["nvidia.com/gpu"] | tonumber) > 0)] | length' 2>/dev/null || echo "0")
  if [[ "$gpu_node_count" -eq 0 ]]; then
    missing+=("{\"name\":\"GPU Nodes\",\"reason\":\"No nodes with nvidia.com/gpu capacity found. At least one node with an NVIDIA GPU (48GB+ VRAM) is required.\"}")
  else
    log_status "running" "validating" "Found ${gpu_node_count} GPU node(s)"
  fi

  # ---- No conflicting operators (check for existing RHOAI) ----
  log_status "running" "validating" "Checking for conflicting installations..."
  local existing_rhoai
  existing_rhoai=$(oc get subscription -A 2>/dev/null | grep "rhods-operator" || echo "")
  if [[ -n "$existing_rhoai" ]]; then
    log_status "running" "validating" "Note: Existing Red Hat OpenShift AI installation detected. The installer will manage this."
  fi

  # ---- Evaluate results ----
  if [[ ${#missing[@]} -gt 0 ]]; then
    local missing_json
    missing_json=$(printf '%s,' "${missing[@]}")
    missing_json="[${missing_json%,}]"
    log_prerequisites_failed "$missing_json"
    return 2
  fi

  return 0
}
