#!/bin/bash
# ============================================================================
# MaaS Code Assistant — Installation
# ============================================================================

deploy_quickstart() {
  local target_ns="${TARGET_NAMESPACE}"

  # ---- Detect cluster environment ----
  log_status "running" "deploying" "Detecting cluster environment..."

  local ingress_domain
  ingress_domain=$(oc get ingresscontroller -n openshift-ingress-operator default -ojsonpath='{.status.domain}' 2>/dev/null || echo "")
  if [[ -z "$ingress_domain" ]]; then
    log_error "Unable to detect ingress domain from cluster. Is the IngressController configured?"
  fi

  local ingress_cert
  ingress_cert=$(oc get ingresscontroller -n openshift-ingress-operator default -ojsonpath='{.spec.defaultCertificate.name}' 2>/dev/null || echo "")
  if [[ -z "$ingress_cert" ]]; then
    ingress_cert="router-certs-default"
  fi

  local ingress_ca=""
  if [[ "$ingress_cert" == "router-certs-default" ]]; then
    ingress_ca=$(oc get secret -n openshift-ingress-operator router-ca -ogo-template='{{ index .data "tls.crt" | base64decode }}' 2>/dev/null || echo "")
  fi

  # Detect tools image availability
  local tools_image
  local registry_available
  registry_available=$(oc get configs.imageregistry.operator.openshift.io cluster -ogo-template='{{ range .status.conditions }}{{ if eq .type "Available" }}{{ .status }}{{ end }}{{ end }}' 2>/dev/null || echo "False")
  if [[ "$registry_available" == "True" ]]; then
    tools_image="image-registry.openshift-image-registry.svc:5000/openshift/tools:latest"
  else
    tools_image=$(oc adm release info --image-for=tools 2>/dev/null || echo "quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:e850f92068d8365e68bab663ae7b76be22c0af33f6a7803c5c95f5ee3f3748f4")
  fi

  # Detect gateway mode
  local gateway_use_route="false"
  if ! oc get svc -n openshift-ingress router-default >/dev/null 2>&1; then
    gateway_use_route="true"
  elif [[ "$(oc get svc -n openshift-ingress router-default -ojsonpath='{.spec.type}' 2>/dev/null)" != "LoadBalancer" ]]; then
    gateway_use_route="true"
  fi

  # Detect existing monitoring config
  local monitoring_enabled="true"
  if oc get configmap -n openshift-monitoring cluster-monitoring-config >/dev/null 2>&1; then
    log_status "running" "deploying" "Existing cluster monitoring config detected — skipping monitoring config"
    monitoring_enabled="false"
  fi

  # Generate Keycloak client secret
  local keycloak_client_secret
  keycloak_client_secret=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c32)

  # ---- Detect GPU taint keys ----
  log_status "running" "deploying" "Detecting GPU node taints..."
  local gpu_taint_keys
  gpu_taint_keys=$(oc get nodes -o json 2>/dev/null | \
    jq -r '[.items[] | select(.status.allocatable["nvidia.com/gpu"] // "0" | tonumber > 0) | .spec.taints[]? | select(.effect == "NoSchedule") | .key] | unique | .[]' 2>/dev/null || echo "")

  local gpu_tolerations_yaml=""
  local gpu_hp_tolerations_yaml=""
  if [[ -n "$gpu_taint_keys" ]]; then
    while IFS= read -r taint_key; do
      log_status "running" "deploying" "Detected GPU taint: ${taint_key}"
      gpu_tolerations_yaml="${gpu_tolerations_yaml}
  - key: ${taint_key}
    effect: NoSchedule
    operator: Exists"
      gpu_hp_tolerations_yaml="${gpu_hp_tolerations_yaml}
        - key: ${taint_key}
          effect: NoSchedule
          operator: Exists"
    done <<< "$gpu_taint_keys"
  else
    log_status "running" "deploying" "No GPU-specific taints detected, using chart defaults"
  fi

  # ---- Generate environment.yaml ----
  log_status "running" "deploying" "Generating environment values..."

  cat > /tmp/environment.yaml <<ENVYAML
processed: true

global:
  wildcardDomain: ${ingress_domain}
  wildcardCertName: ${ingress_cert}
  toolsImage: ${tools_image}

gateways:
  maasDefaultGateway:
    create: true
    useRoute: ${gateway_use_route}

keycloak:
  enabled: true
  removeKubeAdmin: ${REMOVE_KUBE_ADMIN:-false}
  clientSecret: ${keycloak_client_secret}
  ingressCA: |
$(echo "$ingress_ca" | sed 's/^/    /')

devspaces:
  enabled: true

clusterMonitoring:
  enabled: ${monitoring_enabled}

kuadrant:
  restart: true

gpuTolerations: ${gpu_tolerations_yaml:-"[]"}

install-operators:
  enabled: true
  operators:
    devspaces:
      enabled: true
    openshift-cert-manager-operator:
      enabled: true
    leader-worker-set:
      enabled: true
    rhods-operator:
      enabled: true
    rhcl-operator:
      enabled: true
    cloudnative-pg:
      enabled: true
    rhbk-operator:
      enabled: true
    cluster-observability-operator:
      enabled: true
    opentelemetry-product:
      enabled: true
ENVYAML

  if [[ -n "$gpu_tolerations_yaml" ]]; then
    cat >> /tmp/environment.yaml <<GPUTOLS
hardwareProfiles:
  gpu:
    node:
      tolerations:${gpu_hp_tolerations_yaml}
GPUTOLS
  fi

  # ---- Disable already-installed operators ----
  # Only disable operators whose subscriptions are NOT managed by our Helm release.
  # Subscriptions from a previous dependency-operators install have Helm ownership
  # labels and must stay enabled so the chart can update them on upgrade.
  log_status "running" "deploying" "Checking for existing operators..."
  local existing_operators
  existing_operators=$(oc get subscriptions -A -o json 2>/dev/null | \
    jq -r '.items[] | select(.metadata.annotations["meta.helm.sh/release-name"] != "dependency-operators") | .spec.name' 2>/dev/null || echo "")

  for operator in $existing_operators; do
    if grep -q "^[[:space:]]*${operator}:" /tmp/environment.yaml 2>/dev/null; then
      log_status "running" "deploying" "Disabling pre-existing operator: ${operator}"
      sed -i "/^[[:space:]]*${operator}:/{n; s/enabled: true/enabled: false/;}" /tmp/environment.yaml 2>/dev/null || true
    fi
  done

  # ---- Clean up orphaned CSVs from failed previous installs ----
  # When a subscription is deleted and recreated, OLM may reject the new
  # install plan because the old CSV "exists and is not referenced by a
  # subscription." Only clean up CSVs for subscriptions our chart manages.
  local failed_subs
  failed_subs=$(oc get subscriptions -A -o json 2>/dev/null | \
    jq -r '.items[] | select(.metadata.annotations["meta.helm.sh/release-name"] == "dependency-operators") | select(.status.conditions[]? | select(.type == "ResolutionFailed" and .status == "True")) | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null || echo "")
  if [[ -n "$failed_subs" ]]; then
    while IFS= read -r sub_ref; do
      local sub_ns="${sub_ref%%/*}"
      local sub_name="${sub_ref##*/}"
      local orphaned_csv
      orphaned_csv=$(oc get subscription "$sub_name" -n "$sub_ns" -o json 2>/dev/null | \
        jq -r '.status.conditions[] | select(.type == "ResolutionFailed") | .message' 2>/dev/null | \
        grep -oP 'clusterserviceversion \K[^ ]+(?= exists and is not referenced)' || echo "")
      if [[ -n "$orphaned_csv" ]]; then
        log_status "running" "deploying" "Cleaning up orphaned CSV ${orphaned_csv} in ${sub_ns}"
        oc delete csv "$orphaned_csv" -n "$sub_ns" 2>/dev/null || true
      fi
    done <<< "$failed_subs"
    sleep 5
  fi

  # ---- Wait for any terminating namespaces to clear ----
  local terminating
  terminating=$(oc get namespaces --field-selector=status.phase=Terminating -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
  if [[ -n "$terminating" ]]; then
    log_status "running" "deploying" "Waiting for terminating namespaces: ${terminating}..."

    # CheCluster finalizers can deadlock namespace termination — clear them
    if echo "$terminating" | grep -q "openshift-devspaces"; then
      log_status "running" "deploying" "Clearing CheCluster finalizers to unstick openshift-devspaces..."
      oc patch checluster devspaces -n openshift-devspaces --type=merge -p '{"metadata":{"finalizers":[]}}' 2>/dev/null || true
    fi

    local wait_count=0
    while [[ $wait_count -lt 60 ]]; do
      terminating=$(oc get namespaces --field-selector=status.phase=Terminating -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
      [[ -z "$terminating" ]] && break
      sleep 5
      wait_count=$((wait_count + 1))
    done
    if [[ -n "$terminating" ]]; then
      log_status "running" "deploying" "Warning: Namespaces still terminating after 5 minutes: ${terminating}"
    fi
  fi

  # ---- Adopt pre-existing resources into the Helm release ----
  # The chart creates Namespaces, Subscriptions, and OperatorGroups. If any
  # already exist (from a prior install, OLM, or another quickstart), Helm
  # fails with "invalid ownership metadata". Labeling them with Helm
  # ownership metadata lets Helm treat them as managed resources.
  log_status "running" "deploying" "Checking for pre-existing resources to adopt..."

  local adopt_release="dependency-operators"
  local adopt_namespaces=(
    kuadrant-system
    maas-db
    redhat-ods-applications
    cert-manager-operator
    openshift-lws-operator
    redhat-ods-operator
    cloudnative-pg
    keycloak
    openshift-cluster-observability-operator
    opentelemetry-operator
  )

  for ns in "${adopt_namespaces[@]}"; do
    if ! oc get namespace "$ns" >/dev/null 2>&1; then
      log_status "running" "deploying" "Pre-creating namespace $ns for Helm release"
      oc create namespace "$ns" 2>/dev/null || true
    else
      log_status "running" "deploying" "Adopting existing namespace $ns into Helm release"
    fi
    oc label namespace "$ns" "app.kubernetes.io/managed-by=Helm" --overwrite 2>/dev/null || true
    oc annotate namespace "$ns" \
      "meta.helm.sh/release-name=${adopt_release}" \
      "meta.helm.sh/release-namespace=default" --overwrite 2>/dev/null || true
  done

  # ---- Resolve current CSV versions for manually-approved operators ----
  # The chart pins startingCSV to specific versions, but the catalog evolves.
  # Query the packagemanifest for the current CSV in each channel to avoid
  # install plans that can never be created.
  log_status "running" "deploying" "Resolving current operator versions from catalog..."
  local csv_overrides=""

  local manual_operators="rhods-operator:stable-3.4 rhcl-operator:stable cluster-observability-operator:stable"
  for entry in $manual_operators; do
    local op_name="${entry%%:*}"
    local op_channel="${entry##*:}"
    local current_csv
    current_csv=$(oc get packagemanifest "$op_name" -o jsonpath="{.status.channels[?(@.name==\"${op_channel}\")].currentCSV}" 2>/dev/null || echo "")
    if [[ -n "$current_csv" ]]; then
      log_status "running" "deploying" "Resolved ${op_name} → ${current_csv}"
      csv_overrides="${csv_overrides} --set install-operators.operators.${op_name}.startingCSV=${current_csv}"
    fi
  done

  # ---- Install dependency operators ----
  log_status "running" "deploying" "Installing dependency operators (this may take several minutes)..."
  helm upgrade --install --timeout 15m0s \
    dependency-operators /installer/charts/dependency-operators \
    -f /tmp/environment.yaml ${csv_overrides}

  log_status "running" "deploying" "Waiting for DataScienceCluster to be ready..."
  oc wait --for=condition=Ready datasciencecluster default-dsc --timeout 15m0s 2>/dev/null || {
    log_status "running" "deploying" "DataScienceCluster not yet ready, continuing..."
  }

  # ---- Install main chart ----
  log_status "running" "deploying" "Installing MaaS Code Assistant chart..."
  helm upgrade --install -n default --timeout 20m0s \
    maas-code-assistant /installer/charts/maas-code-assistant \
    -f /installer/charts/maas-code-assistant/all-dependencies.yaml \
    -f /tmp/environment.yaml \
    --set keycloak.realm.admin.password="${ADMIN_PASSWORD}" \
    --set keycloak.realm.user.password="${USER_PASSWORD}" \
    --set keycloak.oauthPatch.namespace=default

  log_status "running" "deploying" "Helm installation complete"
}

check_deployment_status() {
  log_status "running" "checking-status" "Checking model deployment status..."

  local max_wait=120
  local wait_count=0

  while [[ $wait_count -lt $max_wait ]]; do
    local model_ready
    model_ready=$(oc get llminferenceservice -n llm -o json 2>/dev/null | \
      jq '[.items[] | select(.status.conditions[]? | select(.type == "Ready" and .status == "True"))] | length' 2>/dev/null || echo "0")

    local model_total
    model_total=$(oc get llminferenceservice -n llm -o json 2>/dev/null | \
      jq '.items | length' 2>/dev/null || echo "0")

    if [[ "$model_total" -gt 0 ]] && [[ "$model_ready" -eq "$model_total" ]]; then
      log_status "running" "checking-status" "All ${model_total} model(s) are ready"
      break
    fi

    log_status "running" "checking-status" "Models ready: ${model_ready}/${model_total} (waiting...)"
    sleep 10
    wait_count=$((wait_count + 1))
  done

  if [[ $wait_count -eq $max_wait ]]; then
    log_status "running" "checking-status" "Warning: Model readiness timed out after 20 minutes. Models may still be loading."
  fi

  # Check Keycloak readiness
  log_status "running" "checking-status" "Checking Keycloak status..."
  oc wait --for=condition=Ready keycloak/keycloak -n keycloak --timeout 5m0s 2>/dev/null || {
    log_status "running" "checking-status" "Warning: Keycloak not fully ready yet"
  }
}

get_endpoints() {
  local ingress_domain
  ingress_domain=$(oc get ingresscontroller -n openshift-ingress-operator default -ojsonpath='{.status.domain}' 2>/dev/null || echo "unknown")

  local console_url
  console_url=$(oc get route console -n openshift-console -ojsonpath='{.spec.host}' 2>/dev/null || echo "console.${ingress_domain}")

  cat <<EOF
[
  {"name":"keycloak-console","displayName":"Keycloak SSO Console","url":"https://keycloak.${ingress_domain}/admin"},
  {"name":"maas-gateway","displayName":"MaaS API Gateway","url":"https://maas.${ingress_domain}"},
  {"name":"openshift-console","displayName":"OpenShift Console","url":"https://${console_url}"}
]
EOF
}
