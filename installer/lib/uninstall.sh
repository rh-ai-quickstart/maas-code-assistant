#!/bin/bash
# ============================================================================
# MaaS Code Assistant — Uninstallation
# ============================================================================

cleanup_quickstart() {
  local mode=$1

  # ---- Uninstall main Helm release ----
  # Only uninstall the quickstart chart. The dependency-operators release
  # manages shared operator subscriptions and namespaces — removing it
  # would delete operators and databases that other applications may use.
  log_status "running" "uninstalling" "Removing MaaS Code Assistant Helm release..."
  helm uninstall maas-code-assistant -n default --wait 2>/dev/null || {
    log_status "running" "uninstalling" "Main Helm release not found or already removed"
  }

  if [[ "$mode" == "delete-all" ]]; then
    # ---- Remove resources that helm uninstall may not fully clean up ----
    # Most CRs are removed by helm uninstall above. These handle resources
    # that may linger due to finalizers or cross-namespace ownership.
    log_status "running" "uninstalling" "Removing residual quickstart resources..."
    oc delete llminferenceservice --all -n llm 2>/dev/null || true
    oc delete maassubscription --all -n models-as-a-service 2>/dev/null || true
    oc delete maasauthpolicy --all -n models-as-a-service 2>/dev/null || true
    oc delete maasmodelref --all 2>/dev/null || true
    oc delete gateway maas-default-gateway -n openshift-ingress 2>/dev/null || true
    oc delete gatewayclass openshift-default 2>/dev/null || true
    oc delete hardwareprofile --all -n redhat-ods-applications 2>/dev/null || true

    # ---- Remove quickstart workload namespaces ----
    # Only remove namespaces the main chart created for its own workloads.
    # Operator and database namespaces (keycloak, maas-db, etc.) are managed
    # by the dependency-operators release and must not be deleted here.
    log_status "running" "uninstalling" "Removing quickstart namespaces..."

    local namespaces_to_delete=(
      "llm"
      "models-as-a-service"
    )

    for ns in "${namespaces_to_delete[@]}"; do
      if oc get namespace "$ns" 2>/dev/null | grep -q "$ns"; then
        local ns_phase
        ns_phase=$(oc get namespace "$ns" -ojsonpath='{.status.phase}' 2>/dev/null || echo "")
        if [[ "$ns_phase" == "Terminating" ]]; then
          log_status "running" "uninstalling" "Namespace $ns is already terminating"
        else
          oc delete namespace "$ns" --wait=false 2>/dev/null || true
        fi
      fi
    done

    # Remove user workspace namespaces
    for wksp_ns in $(oc get namespaces -o name 2>/dev/null | { grep "namespace/wksp-" || true; } | sed 's|namespace/||'); do
      oc delete namespace "$wksp_ns" --wait=false 2>/dev/null || true
    done

    # ---- Clean up cluster-scoped resources ----
    log_status "running" "uninstalling" "Cleaning up cluster-scoped resources..."
    oc delete clusterrolebinding keycloak-cluster-admins 2>/dev/null || true

    # Remove monitoring config if we created it
    oc delete configmap cluster-monitoring-config -n openshift-monitoring 2>/dev/null || true
    oc delete configmap user-workload-monitoring-config -n openshift-user-workload-monitoring 2>/dev/null || true

    # Remove OAuth integration and stale identity mappings
    log_status "running" "uninstalling" "Removing OAuth configuration..."
    oc get oauth cluster -o json 2>/dev/null | \
      jq 'del(.spec.identityProviders[] | select(.name == "rhbk"))' 2>/dev/null | \
      oc apply -f - 2>/dev/null || true
    oc delete secret openid-client-secret -n openshift-config 2>/dev/null || true
    oc delete configmap router-ca -n openshift-config 2>/dev/null || true

    # Remove rhbk identity mappings so a reinstall with new Keycloak UUIDs
    # won't hit "cannot be claimed by identity" errors
    local rhbk_identities
    rhbk_identities=$(oc get identities -o name 2>/dev/null | { grep "rhbk:" || true; })
    if [[ -n "$rhbk_identities" ]]; then
      log_status "running" "uninstalling" "Removing stale Keycloak identity mappings..."
      for identity in $rhbk_identities; do
        local mapped_user
        mapped_user=$(oc get "$identity" -o jsonpath='{.user.name}' 2>/dev/null || echo "")
        oc delete "$identity" 2>/dev/null || true
        if [[ -n "$mapped_user" ]]; then
          oc delete user "$mapped_user" 2>/dev/null || true
        fi
      done
    fi

    # Remove telemetry resources
    oc delete telemetry latency-per-subscription -n openshift-ingress 2>/dev/null || true
    oc delete telemetrypolicy maas-telemetry -n openshift-ingress 2>/dev/null || true

    # Unstick openshift-devspaces if it's stuck terminating on CheCluster finalizers
    local devspaces_phase
    devspaces_phase=$(oc get namespace openshift-devspaces -ojsonpath='{.status.phase}' 2>/dev/null || echo "")
    if [[ "$devspaces_phase" == "Terminating" ]]; then
      log_status "running" "uninstalling" "Clearing CheCluster finalizers to unstick openshift-devspaces..."
      oc patch checluster devspaces -n openshift-devspaces --type=merge -p '{"metadata":{"finalizers":[]}}' 2>/dev/null || true
      local ds_wait=0
      while [[ $ds_wait -lt 12 ]]; do
        oc get namespace openshift-devspaces >/dev/null 2>&1 || break
        sleep 5
        ds_wait=$((ds_wait + 1))
      done
    fi

    log_status "running" "uninstalling" "Operator subscriptions were preserved. To remove operators, follow their documented uninstall procedures."
  fi

  log_status "running" "uninstalling" "Uninstallation complete"
}
