#!/bin/bash
# ============================================================================
# MaaS Code Assistant — Deploy Script (Navigator Proxy)
# ============================================================================

set -euo pipefail

REGISTRY="quay.io/rh-ai-quickstart"
IMAGE_NAME="maas-code-assistant-installer"
VERSION="1.0.0"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${VERSION}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }

# ============================================================================
# DO NOT MODIFY: Job deployment function
# ============================================================================

deploy_job() {
  local ACTION=$1
  local TARGET_NAMESPACE=$2
  local EXTRA_ENV=$3

  local INSTALLER_NAMESPACE="default"

  info "Creating installer RBAC..."

  cat <<RBAC | oc apply -f -
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: maas-code-assistant-installer
  namespace: ${INSTALLER_NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: maas-code-assistant-installer
  namespace: ${INSTALLER_NAMESPACE}
rules:
  - apiGroups: [""]
    resources: ["pods", "configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: maas-code-assistant-installer
  namespace: ${INSTALLER_NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: maas-code-assistant-installer
subjects:
  - kind: ServiceAccount
    name: maas-code-assistant-installer
    namespace: ${INSTALLER_NAMESPACE}
RBAC

  cat <<RBAC | oc apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: maas-code-assistant-installer-${TARGET_NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: maas-code-assistant-installer
    namespace: ${INSTALLER_NAMESPACE}
RBAC

  local JOB_NAME="maas-code-assistant-installer-$(echo $ACTION | tr '[:upper:]' '[:lower:]' | tr '_' '-')-$(date +%s)"

  info "Creating installer Job: $JOB_NAME"
  info "Action: $ACTION"
  info "Target namespace: $TARGET_NAMESPACE"
  info "Installer namespace: $INSTALLER_NAMESPACE"
  info "Image: ${FULL_IMAGE}"

  cat <<EOF | oc apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
  namespace: ${INSTALLER_NAMESPACE}
  labels:
    app: maas-code-assistant-installer
    action: $(echo $ACTION | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    target-namespace: ${TARGET_NAMESPACE}
spec:
  backoffLimit: 0
  template:
    metadata:
      labels:
        app: maas-code-assistant-installer
        action: $(echo $ACTION | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    spec:
      restartPolicy: Never
      serviceAccountName: maas-code-assistant-installer
      containers:
      - name: installer
        image: ${FULL_IMAGE}
        imagePullPolicy: Always
        terminationMessagePolicy: FallbackToLogsOnError
        env:
        - name: ACTION
          value: "${ACTION}"
        - name: TARGET_NAMESPACE
          value: "${TARGET_NAMESPACE}"
        - name: JOB_NAME
          value: "${JOB_NAME}"
${EXTRA_ENV}
EOF

  echo ""
  info "Job created! Monitoring logs..."
  echo ""

  sleep 3
  oc logs -n "$INSTALLER_NAMESPACE" -f "job/${JOB_NAME}" 2>/dev/null || {
    warn "Job may still be starting. Check logs with:"
    echo "  oc logs -n $INSTALLER_NAMESPACE -f job/${JOB_NAME}"
  }

  # --------------------------------------------------------------------------
  # DO NOT MODIFY: Wait for Job completion (poll both Complete and Failed)
  # --------------------------------------------------------------------------
  echo ""
  info "Waiting for Job to complete..."

  WAIT_COUNT=0
  MAX_WAIT=240
  while [[ $WAIT_COUNT -lt $MAX_WAIT ]]; do
    JOB_COMPLETE=$(oc get job -n "$INSTALLER_NAMESPACE" "${JOB_NAME}" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null)
    JOB_FAILED=$(oc get job -n "$INSTALLER_NAMESPACE" "${JOB_NAME}" -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null)

    if [[ "$JOB_COMPLETE" == "True" ]]; then
      info "Job completed successfully"
      break
    elif [[ "$JOB_FAILED" == "True" ]]; then
      warn "Job failed. Check logs above for details."
      break
    fi

    sleep 5
    WAIT_COUNT=$((WAIT_COUNT + 1))
  done

  if [[ $WAIT_COUNT -eq $MAX_WAIT ]]; then
    warn "Job did not complete within 20 minutes"
    echo "  Check status: oc get job -n $INSTALLER_NAMESPACE ${JOB_NAME}"
  fi

  # --------------------------------------------------------------------------
  # DO NOT MODIFY: Retrieve termination message
  # --------------------------------------------------------------------------
  TERM_MSG=""
  POD_NAME=$(oc get pods -n "$INSTALLER_NAMESPACE" -l "job-name=${JOB_NAME}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [[ -n "$POD_NAME" ]]; then
    TERM_MSG=$(oc get pod -n "$INSTALLER_NAMESPACE" "$POD_NAME" -o jsonpath='{.status.containerStatuses[0].state.terminated.message}' 2>/dev/null)
  fi
  if [[ -z "$TERM_MSG" ]]; then
    TERM_MSG=$(oc get job -n "$INSTALLER_NAMESPACE" "${JOB_NAME}" -o jsonpath='{.metadata.annotations.maas-code-assistant-installer/termination-message}' 2>/dev/null)
  fi
  if [[ -n "$TERM_MSG" ]]; then
    echo ""
    info "Termination message:"
    echo "  $TERM_MSG"
  fi

  echo ""
  info "Job complete! Check status with:"
  echo "  oc get job -n $INSTALLER_NAMESPACE ${JOB_NAME}"
  echo "  oc describe job -n $INSTALLER_NAMESPACE ${JOB_NAME}"

  # --------------------------------------------------------------------------
  # DO NOT MODIFY: Clean up all installer RBAC
  # --------------------------------------------------------------------------
  info "Cleaning up installer RBAC..."

  oc delete serviceaccount maas-code-assistant-installer -n default --ignore-not-found=true 2>/dev/null || true
  oc delete role maas-code-assistant-installer -n default --ignore-not-found=true 2>/dev/null || true
  oc delete rolebinding maas-code-assistant-installer -n default --ignore-not-found=true 2>/dev/null || true
  oc delete secret -l "kubernetes.io/service-account.name=maas-code-assistant-installer" -n default --ignore-not-found=true 2>/dev/null || true

  oc delete clusterrolebinding "maas-code-assistant-installer-${TARGET_NAMESPACE}" --ignore-not-found=true 2>/dev/null || true
}

# ============================================================================
# Main case statement
# ============================================================================

case "${1:-}" in
  check_pre_reqs)
    NAMESPACE="${2:-${NAMESPACE:-}}"
    [[ -z "$NAMESPACE" ]] && error "Namespace required. Usage: ./deploy.sh check_pre_reqs <namespace>"
    deploy_job "CHECK_PRE_REQS" "$NAMESPACE" ""
    ;;

  status)
    NAMESPACE="${2:-${NAMESPACE:-}}"
    [[ -z "$NAMESPACE" ]] && error "Namespace required. Usage: ./deploy.sh status <namespace>"
    deploy_job "STATUS" "$NAMESPACE" ""
    ;;

  install)
    NAMESPACE="${2:-${NAMESPACE:-}}"
    [[ -z "$NAMESPACE" ]] && error "Namespace required. Usage: ./deploy.sh install <namespace>"

    read -rsp "Enter admin password: " ADMIN_PASSWORD
    echo ""
    read -rsp "Enter user password (for user1-user5): " USER_PASSWORD
    echo ""
    read -rn 1 -p "Remove kubeadmin user? [y/N]: " REMOVE_ANSWER
    echo ""

    REMOVE_KUBE_ADMIN="false"
    if [[ "$REMOVE_ANSWER" == "y" ]] || [[ "$REMOVE_ANSWER" == "Y" ]]; then
      REMOVE_KUBE_ADMIN="true"
    fi

    INSTALL_ENV="        - name: INSTALL_MODE
          value: \"demo\"
        - name: ADMIN_PASSWORD
          value: \"${ADMIN_PASSWORD}\"
        - name: USER_PASSWORD
          value: \"${USER_PASSWORD}\"
        - name: REMOVE_KUBE_ADMIN
          value: \"${REMOVE_KUBE_ADMIN}\""
    deploy_job "INSTALL" "$NAMESPACE" "$INSTALL_ENV"
    ;;

  uninstall_delete_all)
    NAMESPACE="${2:-${NAMESPACE:-}}"
    [[ -z "$NAMESPACE" ]] && error "Namespace required. Usage: ./deploy.sh uninstall_delete_all <namespace>"
    deploy_job "UNINSTALL_DELETE_ALL" "$NAMESPACE" ""
    ;;

  "")
    echo "MaaS Code Assistant Installer - Deploy Jobs to Cluster"
    echo ""
    echo "Usage: ./deploy.sh <action> <namespace>"
    echo ""
    echo "Actions:"
    echo "  check_pre_reqs <namespace>          - Validate prerequisites"
    echo "  status <namespace>                   - Check deployment status"
    echo "  install <namespace>                  - Deploy installation"
    echo "  uninstall_delete_all <namespace>     - Uninstall (delete all)"
    echo ""
    echo "Image: ${FULL_IMAGE}"
    ;;

  *)
    error "Unknown action: $1"
    ;;
esac
