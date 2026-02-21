# Accelerate enterprise development with NVIDIA and MaaS

Optimize app development using the latest NVIDIA Nemotron models through Models-as-a-Service on your own private multi-tenant infrastructure in Red Hat AI.


## Table of contents

<!-- Table of contents is optional, but recommended. 

REMEMBER: to remove this section if you don't use a TOC.

-->

## Detailed description

Developing software with speed and efficiency is a competitive necessity. Developers are often overwhelmed and slowed down by repetitive code, complex debugging and testing requirements, and the steep learning curve of new technologies. This quickstart demonstrates how you can reclaim some of that lost time with a quick-to-deploy, private AI code assistant powered by NVIDIA Nemotron models and delivered via a fully integrated Models as a Service (MaaS).

For organizations restricted by strict data privacy requirements, regulations, or specific performance needs, a public AI hosted service often is not an option. Models as a Service (MaaS) is a pattern, fully integrated into Red Hat AI, that solves this by enabling centralized IT teams to host and manage private models that remote teams can consume easily and securely. This ensures proprietary data remains within the organization’s resources while providing developers the generative AI technology they need. By providing access to the models via API tokens, administrators can implement specific rate limits and quotas. This approach doesn’t just simplify access and usage, it allows organizations to monitor metrics, forecast capacity and compute needs, and manage chargebacks with accuracy.

### See it in action 

<!-- 

*This section is optional but recommended*

Arcades are a great way to showcase your quickstart before installation.

-->

### Architecture diagrams

![Code Assistant w/ MaaS Architecture](docs/images/code-assist-diagram.jpg)

*This diagram illustrates a models-as-a-service architecture on Red Hat AI including the model deployments in addition to the code assistant application with OpenShift DevSpaces. For more details click [here](docs/images/code-assist-diagram.jpg).*

| Layer/Component | Technology | Purpose/Description |
|-----------------|------------|---------------------|
| **Orchestration** | Red Hat AI Enterprise | Container orchestration and comprehensive AI platform |
| **Inference** | vLLM and llm-d | High performance inference engine for Gen AI model deployment and kubernetes-native distributed inference capabilities with llm-d |
| **LLM** | nemotron-3-nano-30b-a3b-fp8 | A quantized 30B-parameter hybrid Mamba-Transformer MoE model with a 1M-token context window, designed for efficient reasoning, chat, and agentic AI applications |
| **Models-as-a-Service** | Red Hat AI Enterprise | Integrated LLM governance layer that provides rate-limited model access with usage tracking and chargeback across teams |
| **GPU Acceleration** | NVIDIA GPU Operator | Enables GPUs and manages drivers, DCGM, container toolkit, and MIG capabilities for GPU acceleration |
| **Development Environment** | OpenShift DevSpaces | Provides IDE instances for development teams to develop and deploy all on the same cluster |
| **Observability** | Prometheus Operator | Monitors model inference metrics and GPU telemetry | 
| **Dashboard** | Grafana | Metrics scraped from Prometheus are then surfaced and shown visually in custom Grafana dashboards |


## Requirements


### Minimum hardware requirements 

- One NVIDIA GPU node with 48GB VRAM for Nemotron model
- One NVIDIA GPU node with 48GB VRAM for gpt-oss model

Models in quickstart tested with 2 L40S GPU instances on AWS (instance type g6e.2xlarge). 

### Minimum software requirements

- Red Hat OpenShift 4.20
- Red Hat OpenShift AI 3.2
- Helm CLI
- OpenShift Client CLI
- Bash shell available in PATH
- sed available in PATH

### Required user permissions

- Regular user permissions for usage of Models-as-a-Service enabled endpoint, access to DevSpaces workspace, and access to Grafana dashboard for viewing usage data.
- Cluster Admin access needed for any changes to model deployments or MaaS configurations.

## Deploy

The following instructions will easily deploy the quickstart to your Red Hat AI environment using an auto-pilot script-based installation. This will configure the necessary prerequisites for your environment and wire everything together, removing the need for additional configuration.

### Prerequisites

- OpenShift cluster (specific version is specified in the software requirements section)
	- Optional: certificates managed for the OpenShift Router
- OpenShift cluster has GPUs available 
- The NVIDIA GPU Operator is installed and configured with a ClusterPolicy to configure the driver
- You do not have other workloads or configurations in the cluster, such as:
	- An identity provider deployed and configured
	- Red Hat OpenShift AI installed
	- Red Hat Connectivity Link deployed and configured
	- Red Hat OpenShift Dev Spaces deployed

### Installation Steps

1. Ensure you’re logged into your cluster as a cluster-admin user, such as `kube:admin` or `system:admin`:

```
oc whoami
	```

2. Run all-in-one.sh. Enter passwords for the admin and user accounts when prompted.

```
./all-in-one.sh
```

<!-- CONTRIBUTOR TODO: add installation instructions 

*Section is required. Include the explicit steps needed to deploy your
quickstart. 

Assume user will follow your instructions EXACTLY. 

If screenshots are included, remember to put them in the
`docs/images` folder.*

-->

### Delete

<!-- CONTRIBUTOR TODO: add uninstall instructions

*Section required. Include explicit steps to cleanup quickstart.*

Some users may need to reclaim space by removing this quickstart. Make it easy.

-->

## References 

- vLLM: The High-Throughput and Memory-Efficient inference and serving engine for LLMs.
- llm-d: a Kubernetes-native high-performance distributed LLM inference framework.
- Red Hat OpenShift DevSpaces: a container-based, in-browser development environment offered by Red Hat that facilitates cloud-native development directly within the OpenShift ecosystem. Included within the OpenShift product offering.
- NVIDIA Nemotron: a family of open models with open weights, training data, and recipes, delivering leading efficiency and accuracy for building specialized AI agents.
- NVIDIA GPU Operator: uses the operator framework within Kubernetes to automate the management of all NVIDIA software components needed to provision GPU.

## Advanced Deployment

This advanced deployment option will allow you to control the deployment of all prerequisites separately and tailor it to your specific environment.

### Prerequisites

The following prerequisites are required in your environment to prevent any conflicts with the quickstart:

- An OIDC  identity provider (IdP) deployed and integrated with OpenShift OAuth. 
- Users have been configured with some amount of privilege, backed by this IdP.
- Grafana is deployed and managed through the Grafana Operator
	- With a Grafana instance available
- OpenShift Dev Spaces is deployed
	- Basic CheCluster resource is configured
- OpenShift cluster and user-workload monitoring is configured, as documented.
- Red Hat OpenShift AI version 3.2.0 has been deployed from the fast-3.x channel
	- A Data Science Cluster has been created that enables at least the Dashboard and KServe components.
- Red Hat Connectivity Link has been deployed from the stable channel
	- A Kuadrant resource has been installed in the `kuadrant-system` namespace, as documented.

### Installation Steps

<!-- 

*Section is optional.* 

Here is your chance to share technical details. 

Welcome to add sections as needed. Keep additions as structured and consistent as possible.

-->

## Tags

<!-- CONTRIBUTOR TODO: add metadata and tags for publication

TAG requirements: 
	* Title: max char: 64, describes quickstart (match H1 heading) 
	* Description: max char: 160, match SHORT DESCRIPTION above
	* Industry: target industry, ie. Healthcare OR Financial Services
	* Product: list primary product, ie. OpenShift AI OR OpenShift OR RHEL 
	* Use case: use case descriptor, ie. security, automation, 
	* Contributor org: defaults to Red Hat unless partner or community
	
Additional MIST tags, populated by web team.

-->
