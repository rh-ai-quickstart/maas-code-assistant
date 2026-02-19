apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - https://github.com/opendatahub-io/models-as-a-service//deployment/overlays/openshift?ref=39e62e98f382621e401211ae21cb9de0601b8266

patches:
  - target:
      kind: Gateway
      name: maas-default-gateway
    patch: |-
      - op: replace
        path: /spec/listeners/0/hostname
        value: maas.$INGRESS_DOMAIN
      - op: replace
        path: /spec/listeners/1/hostname
        value: maas.$INGRESS_DOMAIN
      - op: replace
        path: /spec/listeners/1/tls/certificateRefs/0/name
        value: $INGRESS_CERTIFICATE
  - target:
      kind: Deployment
      name: maas-api
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/image
        value: quay.io/opendatahub/maas-api:latest-0681979
