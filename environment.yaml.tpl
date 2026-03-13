global:
  wildcardDomain: ${INGRESS_DOMAIN}
  wildcardCertName: ${INGRESS_CERTIFICATE}
  toolsImage: ${TOOLS_IMAGE}

keycloak:
  ingressCA: |-
$(echo "${INGRESS_CA}" | sed 's/^/    /')

gateways:
  maasDefaultGateway:
    useRoute: ${GATEWAY_USE_ROUTE}
