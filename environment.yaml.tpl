global:
  wildcardDomain: ${INGRESS_DOMAIN}
  wildcardCertName: ${INGRESS_CERTIFICATE}
  toolsImage: ${TOOLS_IMAGE}

keycloak:
  removeKubeAdmin: ${REMOVE_KUBE_ADMIN}
  realm:
    openshiftClientSecret: "${KEYCLOAK_CLIENT_SECRET}"
  ingressCA: |-
$(echo "${INGRESS_CA}" | sed 's/^/    /')

gateways:
  maasDefaultGateway:
    useRoute: ${GATEWAY_USE_ROUTE}

clusterMonitoring:
  enabled: ${MONITORING_CONFIG}

install-operators:
  processed: false
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
