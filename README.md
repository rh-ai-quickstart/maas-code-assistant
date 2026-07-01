# Accelerate enterprise software development with NVIDIA and MaaS

Optimize private app development using NVIDIA Nemotron models through Models-as-a-Service on your own multi-tenant
infrastructure in Red Hat AI.

## Table of contents

- [Detailed description](#detailed-description)
  - [Architecture diagrams](#architecture-diagrams)
- [Requirements](#requirements)
  - [Minimum hardware requirements](#minimum-hardware-requirements)
  - [Minimum software requirements](#minimum-software-requirements)
  - [Required user permissions](#required-user-permissions)
- [Deploy](#deploy)
  - [Prerequisites](#prerequisites)
  - [Installation Steps](#installation-steps)
  - [Delete](#delete)
- [References](#references)
- [Advanced Deployment](#advanced-deployment)
  - [Prerequisites](#prerequisites-1)
  - [Installation Steps](#installation-steps-1)
- [Tags](#tags)

## Detailed description

Developing software with speed and efficiency is a competitive necessity. Developers are often overwhelmed and slowed
down by repetitive code, complicated debugging and testing, and the constant need to learn new technologies. AI-powered
coding assistance can help, but how do you leverage it securely and cost-effectively?

For organizations restricted by strict data privacy requirements, regulations, or specific performance needs, public AI
hosted services often are not an option. As your usage expands, you also need to consider how to keep things as
cost-efficient as possible. Models as a Service (MaaS) solves this by enabling centralized IT teams to host and manage
private models that remote teams can consume easily and securely. This keeps proprietary data within the organization’s
boundaries while providing developers access to the generative AI technology they need. By providing access to the
models via API tokens, administrators can also implement specific rate limits and quotas. This approach doesn’t just
simplify access and usage, it allows organizations to monitor metrics, forecast capacity and compute needs, and manage
chargebacks with precision.

This quickstart demonstrates how you can easily deploy a private AI code assistant powered by NVIDIA Nemotron models and
delivered through Red Hat AI's integrated Models as a Service (MaaS) offering. Developers access the assistant through
OpenShift DevSpaces, a containerized cloud-native IDE included in OpenShift.

### Architecture diagrams

![Code Assistant w/ MaaS Architecture](docs/images/code-assist-diagram.png)

_This diagram illustrates a models-as-a-service architecture on Red Hat AI including the model deployments in addition
to the code assistant application with OpenShift DevSpaces. For more details click
[here](docs/images/code-assist-diagram.jpg)._

| Layer/Component             | Technology                               | Purpose/Description                                                                                                                                                |
| --------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Orchestration**           | Red Hat AI Enterprise                    | Container orchestration and comprehensive AI platform                                                                                                              |
| **Inference**               | vLLM and llm-d                           | High performance inference engine for Gen AI model deployment and kubernetes-native distributed inference capabilities with llm-d                                  |
| **LLM**                     | nemotron-3-nano-30b-a3b-fp8              | A quantized 30B-parameter hybrid Mamba-Transformer MoE model with a 256k-token context window, designed for efficient reasoning, chat, and agentic AI applications |
| **Models-as-a-Service**     | Red Hat AI Enterprise                    | Integrated LLM governance layer that provides rate-limited model access with usage tracking and chargeback across teams                                            |
| **GPU Acceleration**        | NVIDIA GPU Operator                      | Enables GPUs and manages drivers, DCGM, container toolkit, and MIG capabilities for GPU acceleration                                                               |
| **Development Environment** | OpenShift DevSpaces                      | Provides IDE instances for development teams to develop and deploy all on the same cluster                                                                         |
| **Observability**           | Prometheus Operator                      | Monitors model inference metrics and GPU telemetry                                                                                                                 |
| **Dashboard**               | OpenShift Cluster Observability Operator | Metrics scraped from Prometheus are then surfaced and shown visually in Perses Dashboards, embedded right in the OpenShift AI console                              |

## Requirements

### Minimum hardware requirements

- One NVIDIA GPU node with at least 48GB VRAM for Nemotron model

**Note**: Models in this quickstart were tested with L40S GPU instances on AWS (instance type g6e.2xlarge).

### Minimum software requirements

- Red Hat OpenShift 4.20+
- Helm CLI
- OpenShift Client CLI
- Bash shell available in PATH
- sed available in PATH (works with macOS/POSIX-only as well as common GNU versions)

### Required user permissions

- Regular user permissions for usage of Models-as-a-Service enabled endpoint, access to DevSpaces workspace, and access
  to Grafana dashboard for viewing usage data.
- Cluster Admin access needed for any changes to model deployments or MaaS configurations.

## Deploy

The following instructions will easily deploy the quickstart to your Red Hat AI environment using an auto-pilot
script-based installation. This will configure the necessary prerequisites for your environment and wire everything
together, removing the need for additional configuration.

_Please see the [advanced deployment](#advanced-deployment) section for details on setting up your own prerequisites and
deploying the quickstart with more control._

### Prerequisites

- OpenShift cluster (specific version is specified in the software requirements section)
  - Optional (recommended): trusted certificates managed for the OpenShift Router,
    [as documented](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/security_and_compliance/configuring-certificates#replacing-default-ingress_replacing-default-ingress)
- A default
  [StorageClass](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/storage/understanding-persistent-storage)
  needs to be configured. If your cluster is on a cloud provider, this is probably available out of the box. If you're
  on bare metal or some hypervisor environments, you may need to install additional operators to enable a default
  StorageClass. See the documentation for
  [OpenShift Data Foundation](https://docs.redhat.com/en/documentation/red_hat_openshift_data_foundation) or the
  [LVM Storage Operator](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/storage/persistent-storage-using-local-storage#persistent-storage-using-lvms)
  documentation for installation on bare metal
- OpenShift cluster has GPUs available
- The NVIDIA GPU Operator is installed and configured with a ClusterPolicy (or other API) to configure the driver and
  make the resources available to Kubernetes to schedule
- You do not have other workloads or configurations in the cluster, meaning:
  - An identity provider is not deployed or configured (unless you make some custom changes to the Helm values files to
    adapt to your users)
  - Red Hat OpenShift AI is not installed
  - Red Hat Connectivity Link is not deployed or configured
  - Red Hat OpenShift Dev Spaces is not deployed

### Installation Steps

1. git clone quickstart repository

```
git clone https://github.com/rh-ai-quickstart/maas-code-assistant.git
```

2. cd into the directory

```
cd maas-code-assistant
```

3. Ensure you’re logged into your cluster as a cluster-admin user, such as `kube:admin` or `system:admin`:

```
oc whoami
```

4. Run all-in-one.sh. Enter passwords for the admin and user accounts when prompted, and decide whether you'd like the
   charts to remove the built-in `kube:admin` user to simplify login (these will be saved in the `.env` file after the
   first run of the script, and you won't be prompted again).

```
./all-in-one.sh
```

<!-- prettier-ignore -->
> [!NOTE]
> This installation will leave the `kubeadmin` user in your cluster by default, prompting you to select a source to log
> in from. The `rhbk` option added to this menu is required to use the users and passwords specified above, and to be
> able to use MaaS models.

### Delete

To remove the core quickstart components (models, Dev Spaces workspaces, etc.) run the following:

```
helm uninstall maas-code-assistant
```

To clean up the dependencies, such as
[OpenShift AI](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html/installing_and_uninstalling_openshift_ai_self-managed/uninstalling-openshift-ai-self-managed_uninstalling-openshift-ai-self-managed),
follow their documented uninstallation procedures by removing their Operands first, allowing the operators to reconcile
and complete removal, before uninstalling the operators themselves.

## References

- [vLLM](https://vllm.ai/): The High-Throughput and Memory-Efficient inference and serving engine for LLMs.
- [llm-d](https://llm-d.ai/): a Kubernetes-native high-performance distributed LLM inference framework.
- [Red Hat OpenShift DevSpaces](https://access.redhat.com/products/red-hat-openshift-dev-spaces): a container-based,
  in-browser development environment offered by Red Hat that facilitates cloud-native development directly within the
  OpenShift ecosystem. Included within the OpenShift product offering.
- [NVIDIA Nemotron](https://developer.nvidia.com/nemotron): a family of open models with open weights, training data,
  and recipes, delivering leading efficiency and accuracy for building specialized AI agents.
- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/index.html): uses the
  operator framework within Kubernetes to automate the management of all NVIDIA software components needed to provision
  GPU.

## Advanced Deployment

This advanced deployment option will allow you to control the deployment of all prerequisites separately and tailor it
to your specific environment.

Use this deployment path if you:

- Have a configured cluster with some or all of the prerequisites already deployed.
- Prefer a different configuration path than the defaults set in the quickstart repository installation script.
- Are using the cluster for other workloads and therefore need to customize the installation to avoid conflict with
  existing cluster resources.

### Prerequisites

The following prerequisites are required in your environment to prevent any conflicts with the quickstart:

- Users have been configured with OpenShift OAuth, backed by OIDC or some other auth method such as htpasswd,
  [as documented](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/postinstallation_configuration/post-install-preparing-for-users).
- OpenShift cluster and user-workload monitoring is configured,
  [as documented](https://docs.redhat.com/en/documentation/monitoring_stack_for_red_hat_openshift/4.22/html-single/configuring_user_workload_monitoring/index).
- The OpenShift Cluster Observability Operator has been deployed
  [as documented](https://docs.redhat.com/en/documentation/red_hat_openshift_cluster_observability_operator/1-latest/html/installing_red_hat_openshift_cluster_observability_operator/index).
  - You need to pin this to version 1.4.0 during the installation. 1.5.0 has some incompatibilities that will be
    resolved in a later release.
- Red Hat OpenShift Dev Spaces is deployed,
  [as documented](https://docs.redhat.com/en/documentation/red_hat_openshift_dev_spaces/3.26/html-single/administration_guide/index#installing-devspaces-on-openshift-using-the-web-console).
  - A basic CheCluster resource is configured, as in steps 2 and 3 of the above.
- The cert-manager Operator for Red Hat OpenShift has been deployed
  [as documented](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/security_and_compliance/cert-manager-operator-for-red-hat-openshift).
- The Leader Worker Set Operator has been deployed,
  [as documented](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/ai_workloads/leader-worker-set-operator#lws-install-operator_lws-managing).
- Red Hat OpenShift AI version 3.4 has been deployed from the stable-3.x or stable-3.4 channels,
  [as documented](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html/installing_and_uninstalling_openshift_ai_self-managed/installing-and-deploying-openshift-ai_install#installing-the-openshift-ai-operator_operator-install).
  - The `DSCInitialization` has been modified to enable OpenShift AI metrics,
    [as documented](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html/managing_openshift_ai/managing-observability_managing-rhoai#enabling-the-observability-stack_managing-rhoai).
  - A `DataScienceCluster` has been created that enables at least the Dashboard, KServe, and Llama Stack Operator
    components,
    [as documented](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html/installing_and_uninstalling_openshift_ai_self-managed/installing-and-deploying-openshift-ai_install#installing-and-managing-openshift-ai-components_component-install),
    with the KServe `modelsAsService.managementState` configured to `Managed`,
    [as documented](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html/govern_llm_access_with_models-as-a-service/deploy-and-manage-models-as-a-service_maas#maas-prerequisites_maas-deploy:~:text=Component%20requirements.-,MaaS%20configuration%3A,-You%20have%20set).
  - Note that using **Manual** approval mode with the **startingCSV** set to `rhods-operator.3.4.0` is recommended to
    stay on the version tested with this code base.
- Red Hat Connectivity Link has been deployed from the stable channel, but pinned to version 1.3.4 or earlier with the
  upgrade mode configured to `Manual`,
  [as documented](https://docs.redhat.com/en/documentation/red_hat_connectivity_link/1.3/html/installing_connectivity_link/rhcl-install-on-ocp).
  - It's possible to install this operator into a different namespace than the default, and this may help with
    deconflicting from OpenShift Service Mesh versions managed by the OpenShift Ingress ClusterOperator's Gateway API
    installation.
  - A `Kuadrant` resource has been installed in the `kuadrant-system` namespace with Observability features enabled,
    [as documented](https://docs.redhat.com/en/documentation/red_hat_connectivity_link/1.3/html/observability/rhcl-observability#rhcl-enable-observability-monitor_rhcl-observability).
  - The `Authorino` resource that gets created from this `Kuadrant` instance has been modified with the following to
    enable TLS on the Authorino endpoint:
    ```
    oc annotate service -n kuadrant-system authorino-authorino-authorization service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert --overwrite
    oc patch authorino -n kuadrant-system authorino --type=merge --patch '{"spec": {"listener": {"tls": {"enabled": true, "certSecretRef": {"name": "authorino-server-cert"}}}}}'
    ```
- You have created the `openshift-default` **GatewayClass** object for Gateway API in OpenShift, and are able to create
  Gateway instances using your cluster's load balancer and infrastructure configuration.
  - See
    [the documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/ingress_and_load_balancing/configuring-ingress-cluster-traffic#ingress-gateway-api)
    for more details about Gateway API in OpenShift.
  - An example infrastructure that requires other pre-work or consideration is bare-metal installation. See the
    [section of the documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/ingress_and_load_balancing/configuring-gateway-api#on-premise-gateway-routing-requirements_assigning-network-addresses-gateways)
    on this topic for more details.
- You have created the `maas-default-gateway` **Gateway** object in the `openshift-ingress` namespace using an
  infrastructure configuration that is supported for your environment and it shows that it is programmed, when verified
  [as documented](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html/govern_llm_access_with_models-as-a-service/deploy-and-manage-models-as-a-service_maas#maas-prerequisites_maas-deploy).
  It additionally needs the `opendatahub.io/managed: "false"` label and the `opendadatahub.io/managed: "false"` and
  `security.opendatahub.io/authorino-tls-bootstrap: "true"` annotations set. Without these, policy enforcement will not
  work as expected.
  - An example of some possible `Gateway` configurations is available as a Helm template in this repository, at
    [charts/dependency-operators/files/openshift-ai/gateway.yaml](charts/dependency-operators/files/openshift-ai/gateway.yaml).
    You can use this template as the basis of a custom manifest by removing the templating syntax and configuring it to
    suit your environment.
- You have a PostgreSQL version 14 or later database available for use with MaaS, and have created a secret with the
  connection URI in the `redhat-ods-applications` namespace,
  [as documented](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html/govern_llm_access_with_models-as-a-service/deploy-and-manage-models-as-a-service_maas#configure-postgresql-secret-for-maas_maas-deploy).
  - An example to deploy a PostgreSQL cluster and provision a database on it, using the Certified CloudNativePG operator
    from [EDB](https://www.enterprisedb.com/), is available as a Helm template in this repository at
    [charts/dependency-operators/files/openshift-ai/cluster.yaml](charts/dependency-operators/files/openshift-ai/cluster.yaml).
    You can use this template as the basis of a custom manifest by removing the templating syntax and configuring it
    according to [the documentation](https://cloudnative-pg.io/docs/1.29/bootstrap#bootstrap-an-empty-cluster-initdb).
    - CloudNativePG can be installed from Operator Hub by navigating to Ecosystem and Software Catalog in the left
      navigation bar on your OpenShift Console. It's discoverable easily by searching for `cnpg`.

### Installation Steps

1. Ensure you’re logged into your cluster as a cluster-admin user:

```
oc whoami
oc get nodes
```

3. Copy `charts/maas-code-assistant/values.yaml` to edit it:

```
cp charts/maas-code-assistant/values.yaml environment.yaml
```

4. Edit the file and update the following sections to match your environment:
   1. `global.wildcardDomain` and `global.wildcardCertName`
      1. You can recover the proper values by running the following:

      ```
      oc get ingresscontroller -n openshift-ingress-operator default -ojsonpath='{.status.domain}{"\n"}'
      oc get ingresscontroller -n openshift-ingress-operator default -ojsonpath='{.spec.defaultCertificate.name}{"\n"}'
      ```
      2. If the second command doesn't return anything for the `defaultCertificate.name`, OpenShift uses the default
         name of `router-certs-default`, which is why it is set as the default.

   2. If you are on a bare metal or non-cloud hypervisor environment, your integrated image registry might be disabled.
      If it is, update `global.toolsImage` to refer to a container image that at least contains `oc`.
      1. You can get one such image for your cluster by running the following:

      ```
      oc adm release info --image-for=tools
      ```

5. Update the `subscriptions` sections to map your desired group and rate-limit mapping for your MaaS subscriptions.
   1. For example, if you have a Group in OpenShift named `okta-users` and would like all members of this group to have
      rate limits of 50,000 total tokens per minute, with 1,000,000 tokens per hour (to allow for bursty usage), use the
      following value for `subscriptions`:

   ```
   subscriptions:
    user:
      displayName: MaaS Users
      groups:
        - name: okta-users
      tokenRateLimits:
        nemotron-3-nano-30b-a3b:
          - limit: 50000
            window: 1m
          - limit: 1000000
            window: 1h
   ```

   2. If you would like to create multiple
      [MaaS Subscriptions](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html/govern_llm_access_with_models-as-a-service/deploy-and-manage-models-as-a-service_maas#managing-maas-subscriptions-dashboard_maas-deploy)
      for different groups to have access to self-service API keys at different rate limits, feel free to do so.

6. Ensure any OpenShift Users you want to be have Dev Spaces configured for have been added to the `users` array

7. Complete any tweaks necessary to the `models` array to ensure the workloads will place on your GPU-enabled nodes.
   This may involve changing the tolerations, adjusting the resources, adding the `nodeSelector` field to each model and
   configuring it with a valid `nodeSelector` for the
   [pod template](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#label-selectors), etc. It is
   not recommended that you change other options, such as the `extraArgs` array to ensure that the model is correctly
   configured for agentic code assistance tasks to complete the user tasks.

8. Install the quickstart with helm:

```
helm install maas-code-assistant ./charts/maas-code-assistant -f environment.yaml
```

## Tags

- **Product**: Red Hat AI Enterprise
- **Use case**: Code development
- **Industry**: Adopt and scale AI
- **Partner**: NVIDIA
