# Developer Environment Work Guide

This document is an end-to-end guide for developers who work on the Inveniam development Kubernetes clusters: **dev01** (AWS), **dev21** (Azure) and the legacy **dev-cluster-01** (AWS). It covers access, running a personal copy of the Inveniam microservices and the Hub in a dedicated `-test` namespace, reaching the shared databases, Redis and Vault, and deploying builds to the shared environments.

It consolidates information previously spread across:

- [Developer Environment Guide](https://inveniam.atlassian.net/wiki/spaces/InveniamDevOps/pages/2426568707/Developer+Environment+Guide) (previous version)
- [Azure Developer Environment Guide](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/1133510674/Azure+Developer+Environment+Guide)
- [Developer Quickstart — dev-cluster-01](https://inveniam.atlassian.net/wiki/spaces/InveniamDevOps/pages/2426896391/Developer+Quickstart+dev-cluster-01) and [Dev Namespace Walkthrough — the short version](https://inveniam.atlassian.net/wiki/spaces/InveniamDevOps/pages/2560819205/Dev+Namespace+Walkthrough+the+short+version)
- [How to Set Up AWS SSO and Connect to EKS Clusters](https://inveniam.atlassian.net/wiki/spaces/IN/pages/1846476813/How+to+Set+Up+AWS+SSO+and+Connect+to+EKS+Clusters)
- [Connect to PostgreSQL from DBeaver (AWS SSM / Azure Bastion)](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/2721382414/Connect+to+PostgreSQL+from+DBeaver+AWS+SSM+Azure+Bastion)
- The legacy [User's Kubernetes Local Dev env (Inveniam and Hub)](https://inveniam.atlassian.net/wiki/spaces/IN/pages/5463413/User+s+Kubernetes+Local+Dev+env+Inveniam+and+Hub)

Deploys to your namespace use the Helm scripts in the [inveniam.io](https://github.com/inveniamcapital/inveniam.io) and [hub](https://github.com/inveniamcapital/hub) repositories (`helm/deploy_helm_to_aws_k8s.sh` and `helm/deploy_helm_to_azure_k8s.sh`). The Terraform deploy scripts described in earlier versions of this guide (`start_deployment_to_aws_kubernetes.sh`, `start_deployment_to_azure_kubernetes.sh`) were removed from inveniam.io in July 2026.

The load-testing cluster `aws-use2-eks-dev03` (`lodus01`) has its own guide: [Load Testing Environment — Developer Access Guide](https://inveniam.atlassian.net/wiki/spaces/IN/pages/2042003461/Load+Testing+Environment+Developer+Access+Guide).

For access requests or issues, contact: devops@inveniam.io

---

## Table of Contents

---

## 1. Overview

There are four ways to develop Inveniam locally:

- **Docker Compose** — best when you only need 1–3 microservices at a time on your laptop. Covered in section 7.1 of `inveniam.io/README.md`.
- **Kubernetes (this guide)** — best when you need the full backend stack running at once. Each developer has a dedicated namespace on each development cluster.
- **Hybrid (frontend local + API in cluster)** — deploy the full stack in Kubernetes and run the frontend locally pointing at it. See section 15.
- **One service local, the rest in the cluster (Telepresence)** — run a single service from your machine while the rest of the stack keeps running in your namespace. Available on dev-cluster-01 only. See section 16.

When you deploy via Kubernetes, the Inveniam application, its microservices and the Hub run inside your personal namespace: `<firstname><lastinitial>-test` on the AWS clusters and `<firstinitial><lastname>-test` on the Azure cluster (section 7). The deploy scripts render one Helm release per microservice and dev-tool from the shared `inveniam/app` chart, using the per-service values in [helm\_env\_configs](https://github.com/inveniamcapital/helm_env_configs) — the same values the real environments are deployed from — and apply them to the cluster you pass with `-k`.

The same flow works for AWS EKS and Azure AKS — the cluster identity, login method and Vault auth method differ, but the developer-facing commands are nearly identical.

Shared environments (`devus01`, `devus21`, `qa3`, and so on) are not deployed with these scripts. They are deployed by ArgoCD, and you choose their build in the ArgoCD UI (section 17).

---

## 2. Prerequisites

### Tooling

Install the following on your development machine.

**macOS (Homebrew):**

```
brew update
brew install awscli kubectl jq helm helmfile
brew tap hashicorp/tap && brew install hashicorp/tap/vault
helm plugin install https://github.com/databus23/helm-diff

# AWS clusters: SSM tunnels to the dev01 database
brew install --cask session-manager-plugin

# Azure only
brew install azure-cli
brew install Azure/kubelogin/kubelogin
az extension add --name ssh

# Optional but recommended
brew install redis
brew install --cask docker        # building images, Telepresence (section 16)
```

**Ubuntu / Debian:**

```
sudo apt-get update
sudo apt-get install -y jq unzip curl wget gnupg lsb-release redis-tools

# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -o awscliv2.zip && sudo ./aws/install --update

# Session Manager plugin (dev01 database tunnels)
curl -fsSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o session-manager-plugin.deb
sudo dpkg -i session-manager-plugin.deb

# kubectl
curl -fsSLO "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl

# Vault (HashiCorp repo)
wget -O- https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y vault

# Helm + helm-diff
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm plugin install https://github.com/databus23/helm-diff

# Azure CLI, kubelogin and the ssh extension (Azure only)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
sudo az aks install-cli
az extension add --name ssh

# Docker Engine (optional: building images, Telepresence)
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$(id -un)" && newgrp docker
```

On Ubuntu, install Helmfile from its [releases page](https://github.com/helmfile/helmfile/releases): download the `linux_amd64` archive and put the `helmfile` binary on your `PATH`.

If you build images locally, both repositories pin Node `v20.18.3` in `.nvmrc`; run `nvm install && nvm use` inside each repository.

Required versions:

- AWS CLI v2 (SSO is not supported in v1)
- `kubectl` matching the cluster version (see [EKS Multi-Cluster Version & Chart Tracking](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/943095822/EKS+Multi-Cluster+Version+Chart+Tracking))
- `vault` CLI
- Helm 3, Helmfile and the `helm-diff` plugin (Helmfile uses it to compute changes)
- Telepresence client `2.23.6`, only if you use section 16

Terraform and GNU `parallel` are no longer needed.

### Access

- **VPN.** Required to reach the cluster APIs, the dev21 bastion, Vault and the environment URLs. Set it up at [openvpn.inveniam.io](https://openvpn.inveniam.io/) with your `firstname.lastname` login (see [OpenVPN - User Guide](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/69009495/OpenVPN+-+User+Guide)). Contact IT for VPN credentials.
- **AWS IAM user** with access key + secret for `dev-cluster-01` (legacy), or **AWS SSO** with email `<first>.<last>@invconsultants.net`. For **dev01**, you need SSO access to the Inveniam Dev account (`403170495167`) with the `AWSPowerUserAccess` permission set.
- **Azure AD** membership in the `Developers` group, with access to the Dev subscription (**dev21**).
- **GitHub** SSH access to [inveniamcapital/inveniam.io](https://github.com/inveniamcapital/inveniam.io) and [inveniamcapital/hub](https://github.com/inveniamcapital/hub).
- **Docker Hub.** The Inveniam container images and the `inveniam/app` Helm chart are **private** on Docker Hub. The cluster pulls the images with the namespace's `dockerhub-regcred` secret, which DevOps provisions at namespace creation. The Helm chart, however, is pulled by `helm` on your machine, so you must run `helm registry login registry-1.docker.io` once with an account that has pull access to the `inveniam` org (section 9.1). If you do not know your Docker Hub login or do not have access to the `inveniam` org, contact Wasim Buden.
- **Vault role.** Needed to read secrets by hand. The role depends on the cluster and on how you log in (section 8).

### Operating System

- macOS (latest version) and Ubuntu 20.04+ are supported.
- Windows is not supported for the Kubernetes development flow.

> **Note:** VPN access is required to reach the EKS / AKS endpoints, the Azure bastion and the Vault services.

---

## 3. Cluster Inventory

| Cluster | Cloud | Region | Account / subscription | Environments | Description |
| --- | --- | --- | --- | --- | --- |
| `dev-cluster-01` | AWS | us-east-1 | `472345033518` | `qa1`–`qa16` | Legacy AWS dev cluster. The QA environments are being retired. |
| `aws-use1-eks-dev01` (dev01) | AWS | us-east-1 | `403170495167` (Inveniam Dev) | `devus01`–`devus03`; staging `stgus01`, `stgus02` | AWS development and staging cluster |
| `az-use1-aks-dev21` (dev21) | Azure | eastus | Subscription `13b6951a-e53b-49ed-afe5-26ca73207500` (Dev) | `devus21`–`devus30`; staging `devus24` | Azure development and staging cluster |
| `aws-use2-eks-dev03` (dev03) | AWS | us-east-2 | `403170495167` | `lodus01` | Load testing cluster. Not covered here; see [Load Testing Environment — Developer Access Guide](https://inveniam.atlassian.net/wiki/spaces/IN/pages/2042003461/Load+Testing+Environment+Developer+Access+Guide). |

### 3.1 Cluster Details

|  | dev-cluster-01 | dev01 | dev21 |
| --- | --- | --- | --- |
| How you log in | IAM access key (section 4.2) or AWS SSO | AWS SSO, profile `inveniam-dev` (section 4.6) | Azure CLI + `kubelogin` (section 5) |
| inveniam.io Vault | `https://vault-dev.inveniam.io` | `https://vault.dev01.inveniam.io` | `https://vault.dev21.inveniam.io` |
| Hub Vault | `https://vault-hub-dev.inveniam.io` | `https://vault-hub.dev01.inveniam.io` | `https://vault-hub.dev21.inveniam.io` |
| Bastion | Not used in this guide | `aws-use1-vpc-dev01-svc-bastion` (`i-0c752dbd7d5bb60cc`), reached with SSM | `az-use1-bastion-dev21` (resource group `dev21`), reached with `az ssh vm` |
| Shared PostgreSQL | Not covered; use your namespace's `inv-db` (section 14.4) | `aws-use1-eks-dev01-postgres.clahbqmoy4gt.us-east-1.rds.amazonaws.com` | `az-use1-postgresql-dev21.postgres.database.azure.com` |
| Shared Redis | Not covered; use your namespace's `inv-redis` | `redis-master` in namespace `redis` | `redis-master` in namespace `redis` |
| DNS zone | `inveniam.io` | `dev01.inveniam.io` | `dev21.inveniam.io` |
| Personal namespace | `<firstname><lastinitial>-test` | `<firstname><lastinitial>-test` | `<firstinitial><lastname>-test` |
| Telepresence (section 16) | Available | Not available | Not available |

For the complete inventory including prod clusters, the URL of every environment and the version deployed in each one, see [DevOps Infrastructure Details](https://inveniam.atlassian.net/wiki/spaces/InveniamDevOps/pages/1201635346/DevOps+Infrastructure+Details) (updated automatically) and [EKS Multi-Cluster Version & Chart Tracking](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/943095822/EKS+Multi-Cluster+Version+Chart+Tracking). To see which team uses which environment, see [Inveniam Environment Information](https://inveniam.atlassian.net/wiki/spaces/InveniamDevOps/pages/1201864718/Inveniam+Environment+Information).

> **Note:** dev01 is AWS and dev21 is Azure, and there is no network path between the two clouds: the Azure bastion cannot reach an AWS database and SSM cannot reach an Azure one. dev01 and dev-cluster-01 are also in different AWS accounts, so credentials for one do not work on the other.

---

## 4. AWS Setup

This section covers how to authenticate to AWS and connect `kubectl` to the AWS development clusters. Two authentication flows are in use depending on which cluster you target:

- **IAM access key + secret** — used by `dev-cluster-01` (legacy). Documented in sections 4.1–4.5.
- **AWS SSO** — used by `aws-use1-eks-dev01` (dev01). Documented in section 4.6.

### 4.1 IAM Access Prerequisites

Before configuring local credentials for `dev-cluster-01`, verify the following:

- AWS CLI v2 is installed (see section 2).
- VPN is connected. The cluster API endpoint is reachable only through VPN.
- The DevOps team has already:
    - Created an IAM user for you in the AWS account `472345033518`.
    - Added that user to the appropriate group (e.g. `devpro-development` for developers, `devpro-qa` for QA).
    - Attached the EKS access policy (`dev-cluster-01-eks-access-from-IAM-users-policy`) to that group.
    - Mapped your IAM user to the cluster with an identity mapping bound to your namespace.
    - Issued you an AWS **access key ID** and a **secret access key**.

To request access, contact devops@inveniam.io with:

- Your full name and email.
- Whether you need developer- or QA-level access.
- Cluster name (`dev-cluster-01`) and the namespace they should provision (see section 7).

See also: [SOP: User Onboarding - Kubernetes, Vault, Kibana, team city](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/1128726687/SOP+User+Onboarding+-+Kubernetes+Vault+Kibana+team+city).

### 4.2 Configure AWS CLI with Access Key + Secret

DevOps will deliver an access key ID and a secret access key. Place them under `~/.aws/`.

Create the directory if it does not exist:

```
mkdir -p ~/.aws
```

Edit `~/.aws/credentials` and add:

```
[default]
aws_access_key_id = <YOUR_AWS_ACCESS_KEY_ID>
aws_secret_access_key = <YOUR_AWS_SECRET_ACCESS_KEY>
```

Edit `~/.aws/config` and add:

```
[default]
output = json
region = us-east-1
```

Alternatively, the same configuration can be created interactively:

```
aws configure
```

Provide the access key, secret, region (`us-east-1`), and output format (`json`) when prompted.

> **Note:** Keep your access key and secret out of any shared file, version control, or chat. Treat them like a password. If a key is exposed, contact DevOps immediately to rotate it.

### 4.3 Verify AWS Credentials

```
aws sts get-caller-identity
```

The output should include an ARN of the form:

```
arn:aws:iam::472345033518:user/<your-iam-user>
```

If you see `Unable to locate credentials` or `AccessDenied`, re-check `~/.aws/credentials` and confirm with DevOps that your onboarding is complete.

### 4.4 Connect kubectl to dev-cluster-01

Generate or update the kubeconfig entry:

```
aws eks --region us-east-1 update-kubeconfig --name dev-cluster-01
```

Confirm connectivity by listing pods in your namespace:

```
kubectl get pods -n <your-namespace>
```

Expected outcomes:

- `No resources found in <namespace> namespace` — the connection is working and the namespace is empty, ready for a deploy.
- `Error from server (Forbidden)` — your IAM user is not yet mapped to the cluster RBAC. Contact DevOps with the full error output.
- `You must be logged in to the server (Unauthorized)` — re-run `aws sts get-caller-identity` to confirm the credentials are still in place, then `aws eks update-kubeconfig --name dev-cluster-01` again.

On dev-cluster-01, an access-key user can only work inside their own namespace.

### 4.5 Verify

```
kubectl config get-contexts
```

The newly added context for `dev-cluster-01` should appear in the list. Switch to it with:

```
kubectl config use-context arn:aws:eks:us-east-1:472345033518:cluster/dev-cluster-01
```

### 4.6 AWS SSO (dev01)

dev01 runs in the Inveniam Dev account (`403170495167`) and uses AWS SSO instead of IAM access keys. Only one AWS CLI profile is needed: `inveniam-dev`.

1. Configure the SSO profile (one-time):

```
aws configure sso --profile inveniam-dev
```

Answer the prompts with these values:

| Prompt | Value |
| --- | --- |
| SSO session name | Press Enter (leave blank) |
| SSO start URL | `https://inveniam.awsapps.com/start` |
| SSO region | `us-east-1` |
| AWS account | Inveniam Dev (`403170495167`) |
| Role | `AWSPowerUserAccess` |
| Default client region | `us-east-1` |
| Default output format | `json` |

This writes the profile to `~/.aws/config`:

```
[profile inveniam-dev]
sso_start_url = https://inveniam.awsapps.com/start
sso_region = us-east-1
sso_account_id = 403170495167
sso_role_name = AWSPowerUserAccess
region = us-east-1
output = json
```

1. Authenticate (each session — the token expires after a few hours). A browser window opens; sign in with your SSO credentials:

```
aws sso login --profile inveniam-dev
```

1. Generate the kubeconfig entry for dev01:

```
aws eks --region us-east-1 update-kubeconfig \
  --profile inveniam-dev --name aws-use1-eks-dev01
```

1. Verify:

```
aws sts get-caller-identity --profile inveniam-dev     # Account must be 403170495167
kubectl get ns
```

Pass `--profile inveniam-dev` on every AWS command for dev01, or run `export AWS_PROFILE=inveniam-dev` once per terminal. A command without a profile reads the `default` profile — which holds your dev-cluster-01 key, or nothing — and fails with `Unable to locate credentials` or acts on the wrong account.

The `AWSPowerUserAccess` role is mapped to developer access on dev01: you can read and change resources in every namespace, not only your personal one. Deploy only to your own namespace, and change shared environments through ArgoCD (section 17). The QA permission set (`OperatorAccess`) is not mapped to the cluster and cannot open sessions on the bastion.

If you use AWS SSO for dev-cluster-01 as well, create a separate profile for account `472345033518` and select it with `export AWS_PROFILE=<your-profile>` before working on that cluster.

### 4.7 Working with Multiple Clusters

Add a kubeconfig entry for each cluster you use. Every entry becomes a separate context:

```
aws eks --region us-east-1 update-kubeconfig --name dev-cluster-01
aws eks --region us-east-1 update-kubeconfig --profile inveniam-dev --name aws-use1-eks-dev01
az aks get-credentials --resource-group dev21 --name az-use1-aks-dev21 --overwrite-existing   # section 5.4
```

List and switch contexts:

```
kubectl config get-contexts
kubectl config use-context arn:aws:eks:us-east-1:403170495167:cluster/aws-use1-eks-dev01
kubectl config use-context arn:aws:eks:us-east-1:472345033518:cluster/dev-cluster-01
kubectl config use-context az-use1-aks-dev21
```

> **Note:** Tools such as IDE Kubernetes extensions and the deploy scripts can change your current context. When you work with more than one cluster, check `kubectl config current-context` before running commands, or pass `--context <name>` explicitly.

### 4.8 Authenticate to Vault (AWS clusters)

The deploy scripts do not need your Vault login. You need it to read secrets by hand, for example database credentials (section 8.2). Vault checks your identity with a request signed by your AWS credentials.

**dev-cluster-01 with IAM access keys** (default profile in `~/.aws/credentials`) — the Vault CLI picks the credentials up automatically:

```
vault login -method=aws \
  -address="https://vault-dev.inveniam.io" \
  -format=json \
  role="<your-vault-role>"
```

Your `<your-vault-role>` is normally `name.surname` (e.g. `rafael.vieira`).

**dev-cluster-01 with AWS SSO** — the Vault CLI cannot read an SSO session, so export the temporary credentials first, then log in:

```
eval "$(aws configure export-credentials --profile <your-profile> --format env)"

vault login -method=aws \
  -address="https://vault-dev.inveniam.io" \
  -format=json \
  role="sso-developer-role"
```

**dev01** — same pattern, with the dev01 Vault:

```
aws sso login --profile inveniam-dev
eval "$(aws configure export-credentials --profile inveniam-dev --format env)"

export VAULT_ADDR="https://vault.dev01.inveniam.io"      # Hub secrets: https://vault-hub.dev01.inveniam.io
vault login -method=aws role="sso-developer-role"        # QA: sso-qa-role
```

All flows return a Vault token good for subsequent CLI calls. On dev01 the token lasts one hour. The exported AWS credentials also expire (typically 1–8 hours); when Vault starts refusing you, re-run the `eval` line and the login.

---

## 5. Azure Setup

This section walks through the full Azure setup needed to authenticate to Azure AD and connect `kubectl` to the `az-use1-aks-dev21` cluster. The Azure development cluster hosts both the `hub` and `inveniam.io` applications in the `devus21`–`devus30` environments.

### 5.1 Azure Prerequisites

Before configuring access, verify the following:

- **Azure CLI** is installed, with the `ssh` extension (see section 2 for install commands).
- `kubelogin` is installed and on your `PATH`. It is used by `kubectl` to authenticate to AKS via Azure CLI.
- Your account is a member of the Azure AD group `Developers` (QA engineers: `QA`).
- You have access to the Dev subscription.
- Connected to VPN. The AKS API endpoint and the bastion's SSH port only accept connections from the VPN.

The relevant identifiers for the dev21 cluster are:

| Resource | Value |
| --- | --- |
| Tenant ID | `4cd2b728-f5a4-4510-b911-64f62ce654bb` |
| Subscription ID | `13b6951a-e53b-49ed-afe5-26ca73207500` |
| AKS cluster | `az-use1-aks-dev21` |
| Resource group | `dev21` |
| Bastion VM | `az-use1-bastion-dev21` |
| PostgreSQL server | `az-use1-postgresql-dev21.postgres.database.azure.com` |
| Inveniam Vault | `https://vault.dev21.inveniam.io` |
| Hub Vault | `https://vault-hub.dev21.inveniam.io` |
| DNS zone | `dev21.inveniam.io` |
| Environments | `devus21`–`devus30` (`devus24` is the Azure staging environment) |

### 5.2 Login to Azure CLI

```
az login --tenant 4cd2b728-f5a4-4510-b911-64f62ce654bb
```

A browser window opens. Sign in with your Azure AD credentials. Select the **Dev** subscription when prompted, or set it explicitly afterwards:

```
az account set --subscription 13b6951a-e53b-49ed-afe5-26ca73207500
```

Get an access token (used for the Vault login in section 5.7):

```
az account get-access-token --resource=https://management.azure.com/
```

### 5.3 Developer Group Access

All users in the Azure AD group `Developers` automatically have permissions to access:

- Azure Kubernetes Service (AKS) — Azure Kubernetes Service RBAC Admin on the whole cluster
- HashiCorp Vault instances (Inveniam and Hub), through the `aad-developer-role` Vault role
- The PostgreSQL server, through the bastion host (you log in to the bastion with your Azure account)
- Environment-specific Azure resources of your personal namespace, through your personal identity (section 5.5)

Members of the `QA` group get the same AKS, bastion and Vault access (Vault role `aad-qa-role`), but no personal namespace. The `DevOps` group is the cluster administrator group.

> **Access level:** Each developer is granted **admin privileges** within the AKS cluster:
> 
> - You can view and manage all namespaces, including those of other developers and of the shared environments.
> - You can create, update, and delete Kubernetes resources.
> - System namespaces such as `kube-system` are **not** protected from your role. Be careful outside your own namespace, and change shared environments only through ArgoCD (section 17).

If permissions look wrong even after being added to the group, see section 19 — Azure token claims are cached and may need a forced refresh.

### 5.4 Connect kubectl to the AKS Cluster

```
# 1) Download credentials
az aks get-credentials \
  --resource-group dev21 \
  --name az-use1-aks-dev21 \
  --overwrite-existing

# 2) Enable Azure CLI authentication for kubectl
kubelogin convert-kubeconfig -l azurecli

# 3) Confirm
kubectl get ns
```

After this, `kubectl` calls trigger an Azure CLI token refresh transparently. You do not need to manage long-lived service principal credentials in `~/.kube/config`.

Each member of the `Developers` group has a dedicated namespace ending in `-test`, created automatically. On Azure the name is the **first letter of your first name** followed by your **last name** (e.g. `sdandekar-test`) — different from the AWS clusters. The namespace comes with its RBAC, its personal identity and the DNS records `<ns>`, `<ns>-api`, `hub-<ns>` and `hub-<ns>-api` under `dev21.inveniam.io`. See section 7.

### 5.5 Developer Identity

Each developer has a personal user-assigned managed identity, created together with the namespace: `az-use1-aks-dev21-<your-namespace>-identity`. Pods in your namespace authenticate to Azure services as this identity. It has these roles:

- Azure Kubernetes Service RBAC Admin on the cluster
- Contributor on the `dev21` resource group
- Storage Blob Data Contributor and Azure Service Bus Data Owner on the resource group
- Cognitive Services User, Contributor, Data Contributor and OpenAI Contributor on the resource group

The identity's client ID is published in the `developer-config` ConfigMap of your namespace, which the Helm chart reads when it creates the service accounts:

```
kubectl get configmap developer-config -n <your-namespace> -o yaml
```

The federated credentials that let the service accounts of your namespace act as this identity are created from the `inveniam.io` repository:

```
./create_federated_credentials.sh <your-namespace> dev21
```

> **Note:** The shared identity `az-use1-aks-dev21-developer-identity` (client ID `ae5ebeae-2d83-4614-ba33-ae4655f6cda7`) documented in earlier versions no longer exists. Use your personal identity.

### 5.6 Bastion Host

The bastion VM (`az-use1-bastion-dev21`) is a jump box used to securely reach internal services that are not exposed to the internet. It has network access to the managed **PostgreSQL** server shared by all dev21 environments. It accepts SSH only from the VPN, and you log in with your Azure account, so there are no SSH keys to manage.

SSH into the bastion:

```
az ssh vm --name az-use1-bastion-dev21 --resource-group dev21
```

#### Tunneling connections through the bastion

You can use the bastion to tunnel access to the PostgreSQL server from your local machine. The command below forwards port `15432` on your machine to the database; `-N` keeps the connection open without starting a shell. Local port `15432` avoids a clash with a PostgreSQL already listening on `5432` on your machine (for example a Docker `inv-db` or an old tunnel).

**PostgreSQL**

```
az ssh vm \
   --name az-use1-bastion-dev21 \
   --resource-group dev21 \
   -- -N -L 15432:az-use1-postgresql-dev21.postgres.database.azure.com:5432
```

Keep the terminal open while you need the connection, and connect your client to `127.0.0.1:15432` (section 14.7).

**Redis** is not behind the bastion: it runs inside the cluster. Use `kubectl port-forward` instead (section 14.8).

> Database credentials are in Vault (section 8.2) and in the [Password Manager – devus21](https://passwords.inveniam.io/index.php/prj/view/289).

### 5.7 Vault Access from Your Terminal

URLs:

- **Inveniam Vault:** <https://vault.dev21.inveniam.io>
- **Hub Vault:** <https://vault-hub.dev21.inveniam.io>

Authentication steps:

1. **Login to Azure:**

```
az login --tenant 4cd2b728-f5a4-4510-b911-64f62ce654bb
```

1. **Set the Vault address:**

```
export VAULT_ADDR="https://vault.dev21.inveniam.io"
```

1. **Login to Vault with an Azure access token:**

```
export VAULT_TOKEN="$(vault write -field=token auth/azure/login role="aad-developer-role" \
  jwt="$(az account get-access-token --resource=https://management.azure.com/ --query accessToken -o tsv)")"
```

`vault write` returns the token but, unlike `vault login`, does not save it for later commands. Exporting it as `VAULT_TOKEN` makes the following `vault` commands use it.

> **Notes:**
> 
> - The Vault token returned during login is valid for **1 hour**.
> - The `aad-developer-role` is bound to the `Developers` Azure AD group. QA engineers use `aad-qa-role`.

### 5.8 Vault Access from Docker

If you need to log in to Vault from inside a container, the same flow works with the Azure CLI mounted from your host:

```
docker run --rm -it \
  -v ~/.azure:/root/.azure \
  -e VAULT_ADDR=https://vault.dev21.inveniam.io \
  --platform linux/amd64 \
  472345033518.dkr.ecr.us-east-1.amazonaws.com/vault:1.17.5 \
  bash -c '
    echo "Getting Azure token..." && \
    ACCESS_TOKEN=$(az account get-access-token --resource=https://management.azure.com/ --query accessToken -o tsv) && \
    echo "Logging into Vault..." && \
    vault write auth/azure/login role="aad-developer-role" jwt="$ACCESS_TOKEN"
  '
```

### 5.9 Vault Access from Pods

Applications running in Kubernetes pods access Vault using the **Kubernetes authentication method** — the pod's service account token is exchanged for a Vault token. Each microservice is bound to a Vault role configured by the DevOps team.

You can test this manually by running an interactive Vault container in the cluster:

```
kubectl run -i --tty vault-test -n <your-namespace> --image=hashicorp/vault:1.17.5 -- bash
```

Then, inside the pod:

```
export VAULT_ADDR="https://vault.dev21.inveniam.io"
JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
vault write auth/kubernetes/login role="my-app-role" jwt="$JWT"
vault kv get devus21-cluster/service/ds/db
```

> Replace `my-app-role` with the Vault role configured for your app. See section 8.2 for the secret paths.

---

## 6. Repository Setup

You need local checkouts of [inveniam.io](https://github.com/inveniamcapital/inveniam.io) and [hub](https://github.com/inveniamcapital/hub) to run the deploy scripts. Both deploy with Helm: a helmfile in each repository renders the shared `inveniam/app` chart with the per-service values from [helm\_env\_configs](https://github.com/inveniamcapital/helm_env_configs).

```
git clone git@github.com:inveniamcapital/inveniam.io.git
git clone git@github.com:inveniamcapital/hub.git
```

You do not need to clone `helm_env_configs`. The deploy scripts keep a copy in `helm/.cache/helm_env_configs` and update it on every run. To test changes to `helm_env_configs` that you have not pushed yet, point the scripts at your own checkout with `-L <path>`.

The deploy and lifecycle scripts:

| Repository | Script | Purpose |
| --- | --- | --- |
| inveniam.io | `helm/deploy_helm_to_aws_k8s.sh` | Deploy / upgrade all (or a subset of) components to an AWS cluster (dev-cluster-01, dev01) |
| inveniam.io | `helm/deploy_helm_to_azure_k8s.sh` | Same, for Azure (dev21) |
| inveniam.io | `helm/destroy_helm_releases.sh` | Uninstall the releases from your namespace (section 18) |
| inveniam.io | `create_federated_credentials.sh` | Azure only: federated credentials for the service accounts of your namespace (section 5.5) |
| inveniam.io and hub | `start_component_locally.sh` | Run one service locally with Telepresence (section 16) |
| hub | `helm/deploy_helm_to_aws_k8s.sh`, `helm/deploy_helm_to_azure_k8s.sh` | Deploy the Hub to AWS or Azure (section 10) |
| hub | `helm/scripts/create_dev_user.sh` | Invite yourself into the Hub database of your namespace (section 10.6) |

> **Note:** The Terraform scripts `start_deployment_to_aws_kubernetes.sh`, `start_deployment_to_azure_kubernetes.sh`, `wipe_aws_kubernetes.sh` and `wipe_azure_kubernetes.sh`, and the per-service `deployment_to_kubernetes/` folders, were removed from inveniam.io. If an old checkout still has them, do not use them. `create_aws_configmap.sh` is not needed with Helm: the AWS deploy script creates the ConfigMap itself.

---

## 7. Namespace Conventions

### AWS clusters (dev-cluster-01 and dev01)

Each developer has a personal namespace built from their IAM or SSO email (`<first>.<last>@invconsultants.net`):

```
<first name><first letter of last name>-test
```

Examples:

| Name | Email | Namespace |
| --- | --- | --- |
| Sanjay Dandekar | `sanjay.dandekar@invconsultants.net` | `sanjayd-test` |
| Rafael Vieira | `rafael.vieira@invconsultants.net` | `rafaelv-test` |
| John Doe | `john.doe@invconsultants.net` | `johnd-test` |

On dev-cluster-01, namespaces are pre-created by DevOps and have RBAC pre-configured. A small number of developers whose IAM email does not follow the `first.last` format have **custom namespaces** maintained by hand (e.g. `rrossi-test`, `rvieira-test`). If you are one of them, DevOps will tell you what your namespace is.

On dev01, a namespace is created automatically for each member of the AWS developer and QA SSO groups. If your login has no dot, the whole login is used before `-test`.

### Azure cluster (dev21)

On dev21 the rule is the other way around:

```
<first letter of first name><last name>-test
```

| Name | Email | Namespace |
| --- | --- | --- |
| Sanjay Dandekar | `sanjay.dandekar@invconsultants.net` | `sdandekar-test` |
| Rafael Vieira | `rafael.vieira@invconsultants.net` | `rvieira-test` |
| John Doe | `john.doe@invconsultants.net` | `jdoe-test` |

A namespace is created automatically for each member of the `Developers` group (section 5.4). If your login has no dot, the whole login is used, with `_` and `.` replaced by `-`.

On every cluster, deploy workloads **only inside your own namespace**.

### Shared Environment Namespaces

On dev01 and dev21, each shared environment uses these namespaces. They are deployed by ArgoCD; do not change them with `kubectl` or the deploy scripts.

| Application | Namespace |
| --- | --- |
| inveniam.io services, UI, Chat, Studio | `<env>-cluster` (e.g. `devus01-cluster`) |
| Hub | `hub-<env>-cluster` (e.g. `hub-devus21-cluster`) |
| immudb | `inveniam-immudb-<env>-cluster` |

### Requesting a Namespace

If you do not yet have a namespace, contact devops@inveniam.io with:

- Your full name and email
- Cloud (AWS or Azure)
- Cluster name where the namespace should be created

See also: [SOP: User Onboarding - Kubernetes, Vault, Kibana, team city](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/1128726687/SOP+User+Onboarding+-+Kubernetes+Vault+Kibana+team+city).

---

## 8. Vault Roles and Secrets

The Helm deploy scripts do not log in to Vault: each pod authenticates on its own through the `vault-k8s-init` init container (section 11). You need your own Vault login to read secrets by hand, for example database credentials.

### 8.1 Vault Role per Cluster

| Cluster | Vault addresses | Login method | Developer role | QA role |
| --- | --- | --- | --- | --- |
| dev-cluster-01 | `https://vault-dev.inveniam.io`Hub: `https://vault-hub-dev.inveniam.io` | AWS (section 4.8) | `name.surname` with an access key; `sso-developer-role` with SSO | Provided by DevOps |
| dev01 | `https://vault.dev01.inveniam.io`Hub: `https://vault-hub.dev01.inveniam.io` | AWS (section 4.8) | `sso-developer-role` | `sso-qa-role` |
| dev21 | `https://vault.dev21.inveniam.io`Hub: `https://vault-hub.dev21.inveniam.io` | Azure (section 5.7) | `aad-developer-role` | `aad-qa-role` |

Vault tells you which mistake you made: `IAM Principal ... is not authorized to login for role X` means the role exists but is bound to a different identity; `entry for role X not found` means it does not exist on that Vault.

### 8.2 Where Secrets Live (dev01 and dev21)

After logging in to the right Vault, read the secret for the environment and service you need. A database secret has the keys `host`, `port`, `name`, `username`, `password` and `sslmode`.

| Secret | Vault | Path |
| --- | --- | --- |
| inveniam.io service database | Inveniam | `<env>-cluster/service/<service>/db` |
| inveniam.io event store | Inveniam | `<env>-cluster/service/<service>/eventstore` |
| Redis | Inveniam | `<env>-cluster/redis` |
| Hub database | Hub | `hub-<env>/service/<service>/db` |

```
vault kv list devus21-cluster/service           # list the service names
vault kv get devus21-cluster/service/ds/db      # read one database secret
```

See also: [Notes on how to interact with Vault](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/5463134/Notes+on+how+to+interact+with+Vault).

---

## 9. Deploying Microservices to Your Namespace

The inveniam.io deploy is driven by `helm/deploy_helm_to_aws_k8s.sh` (AWS) and `helm/deploy_helm_to_azure_k8s.sh` (Azure). Both scripts live in the `helm/` folder of the `inveniam.io` repo.

### 9.1 First-time Setup

Once per machine, before the first deploy:

- **Log in to Docker Hub.** The `inveniam/app` chart is a private OCI artifact that `helm` pulls from your machine. Without this login the deploy fails at `helm pull` with `401 unauthorized`. A previous `docker login registry-1.docker.io` also works, because `helm` reads `~/.docker/config.json`.

```
helm registry login registry-1.docker.io -u <your-dockerhub-user>
```

- **Install the **`helm-diff`** plugin**, if you have not yet (section 2). Without it, Helmfile fails with `unknown command "diff" for "helm"`.
- **Connect **`kubectl` to the target cluster: section 4.4 (dev-cluster-01), 4.6 (dev01) or 5.4 (dev21).

**Azure only:** your namespace must have the `developer-config` ConfigMap, which is created together with the namespace (section 5.5). If the deploy stops and asks you to run `create_azure_configmap.sh`, contact DevOps instead: that script reads the client ID from the existing ConfigMap and cannot create it from scratch. Create the federated credentials once with `./create_federated_credentials.sh <your-namespace> dev21`.

### 9.2 Log in to Vault

Not needed for deploys. The pods authenticate to Vault themselves. Log in only to read secrets by hand (section 8).

### 9.3 Quick Start (AWS)

Deploy all services to your personal namespace on `dev01`:

```
export AWS_PROFILE=inveniam-dev
./helm/deploy_helm_to_aws_k8s.sh -n <your-namespace> -k aws-use1-eks-dev01 -t <image-tag>
```

Deploy all services to your personal namespace on `dev-cluster-01`:

```
./helm/deploy_helm_to_aws_k8s.sh -n <your-namespace> -k dev-cluster-01 -t <image-tag>
```

Without `-t`, the script computes the image tag from your current git state (section 9.6):

```
./helm/deploy_helm_to_aws_k8s.sh -n <your-namespace> -k aws-use1-eks-dev01
```

> **Note:** `-k` must be the full cluster name. If you omit it, the AWS script defaults to `dev-cluster-01`. The script also switches your `kubectl` context to the cluster it deploys to.

### 9.4 Quick Start (Azure)

```
./helm/deploy_helm_to_azure_k8s.sh \
  -n <your-namespace> \
  -k az-use1-aks-dev21 \
  -i <image-tag>
```

The Azure script still accepts the Terraform-era resource group (`-r`), tenant ID (`-t`) and subscription ID (`-s`) flags so old command lines keep working, but it ignores them. Use `-i` for the image tag.

### 9.5 Deploy Script Flags

Common flags for both scripts:

| Flag | Description |
| --- | --- |
| `-n`, `--namespace` | Kubernetes namespace (required) |
| `-k`, `--cluster-name` | Kubernetes cluster name: `dev-cluster-01`, `aws-use1-eks-dev01` or `az-use1-aks-dev21`. Required on Azure; defaults to `dev-cluster-01` on AWS. |
| `-l`, `--list` | Comma-separated components to deploy (default: all; names in section 9.7) |
| `-b`, `--branch` | Git branch in `INV-NNNN-something` format — used to compute the image tag |
| `-c`, `--commit` | Commit hash (requires `-b`) — used to compute the image tag |
| `-i`, `--image-tag` | Use this exact image tag (e.g. `LOCAL-INV-32001-4f1b41db`) |
| `-V`, `--vault-kv-path` | Vault KV path prefix the services read (default: `development`) |
| `-L`, `--local` | Use a local `helm_env_configs` checkout at this path instead of the cached copy |
| `-T`, `--template` | Render the manifests without applying them |
| `-h`, `--help` | Show help |

Script-specific:

| Flag | Script | Description |
| --- | --- | --- |
| `-t`, `--tag` | AWS | Same as `-i` |
| `-r`, `-t`, `-s` | Azure | Resource group, tenant ID, subscription ID. Accepted for compatibility, not used. |

### 9.6 Image Tag Logic

Images are built by GitHub Actions and pushed to Docker Hub (`inveniam/<image>`). The script computes the tag from your local git state unless you override it, using the format `LOCAL-<branch-short>-<commit-short>` (e.g. `LOCAL-INV-32001-4f1b41db`), which is the branch tag the Dev CI workflow pushes:

1. **No** `-b`/`-c`/`-i` — uses your current branch + current `git HEAD` commit.
2. **Only** `-b <branch>` — uses the given branch + your current `git HEAD` commit.
3. **Both** `-b <branch>` and `-c <commit>` — uses both, you do not need to be on that branch/commit locally.
4. `-i <image-tag>` (or `-t` on AWS) — uses the tag as-is. Handy for deploying any existing build.

The Dev CI workflow runs only when you start it. Push your `INV-NNNN-something` branch, then:

```
gh workflow run workflow_dev_ci_build.yml --repo inveniamcapital/inveniam.io --ref INV-32001-feature
```

Tags produced by GitHub Actions:

| Build | inveniam.io tag | Example |
| --- | --- | --- |
| Dev CI on an `INV-` branch | `<version>-INV-<ticket>.<run>` and `LOCAL-INV-<ticket>-<commit-short>` | `LOCAL-INV-32001-4f1b41db` |
| Pull request | `<version>-M<pr>.<run>` | `1.97.99-M9640.127` |
| Merge to `develop` | `<major>.<minor>.<run>` | `1.97.134` |

> **Note:** Any published tag can be deployed with `-i`, including pull request builds. The run page of each GitHub Actions workflow shows the tags it pushed.

### 9.7 Component Name Mapping

The `-l` flag takes a comma-separated subset of these names. The Terraform-era names (for example `inv-iam-ms`) are still accepted as aliases.

| Component | What it deploys |
| --- | --- |
| `inv-db` | In-namespace PostgreSQL |
| `inv-rabbitmq` | In-namespace RabbitMQ |
| `inv-redis` | In-namespace Redis |
| `inv-mongodb` | In-namespace MongoDB (AWS only) |
| `inv-immudb` | In-namespace ImmuDB (AWS only) |
| `inv-maildev` | In-namespace MailDev (catches outgoing email) |
| `inv-front` | Frontend UI |
| `inv-awf` | Automated workflow service |
| `inv-cron` | Cron service |
| `inv-ds` | Data Room service |
| `inv-hub` | Hub service |
| `inv-ns` | Notifications service |
| `inv-organisations` | Organisations service |
| `inv-ss` | Scheduler service |
| `inv-tasks` | Tasks service |
| `inv-relay` | Relay service |
| `inv-ws-main` | WebSockets main service |
| `inv-metachain` | Metachain service |
| `inv-deals` | Deals service |
| `inv-bs` | Batch processing service |
| `inv-iam` | IAM service |
| `inv-ai` | AI service |
| `inv-workflows` | Workflows service |
| `inv-mcp` | MCP service |
| `inv-help-center` | Help center |
| `inv-provenance-os` | Provenance OS service |

### 9.8 Common Examples

Deploy a specific subset of services:

```
./helm/deploy_helm_to_aws_k8s.sh \
  -n <your-namespace> -k aws-use1-eks-dev01 \
  -l inv-iam,inv-ai,inv-front
```

Skip the dev-tools (DB, Redis, etc.) and deploy only application microservices — list the apps explicitly and leave the dev-tools out of `-l`:

```
./helm/deploy_helm_to_aws_k8s.sh \
  -n <your-namespace> -k aws-use1-eks-dev01 \
  -l inv-front,inv-iam,inv-organisations,inv-ds
```

Deploy a specific Dev CI build:

```
./helm/deploy_helm_to_aws_k8s.sh \
  -n <your-namespace> -k aws-use1-eks-dev01 \
  -t LOCAL-INV-32001-4f1b41db
```

Deploy a specific branch + commit (no need to be on it):

```
./helm/deploy_helm_to_aws_k8s.sh \
  -n <your-namespace> -k aws-use1-eks-dev01 \
  -b INV-32001-feature -c 4f1b41db
```

Review the manifests without applying anything:

```
./helm/deploy_helm_to_aws_k8s.sh -n <your-namespace> -k aws-use1-eks-dev01 -t <image-tag> -T
```

Deploy with unpushed `helm_env_configs` changes from your own checkout:

```
./helm/deploy_helm_to_aws_k8s.sh -n <your-namespace> -k aws-use1-eks-dev01 -t <image-tag> \
  -L ~/git/inveniam/src/helm_env_configs
```

The same examples work on dev21 with `./helm/deploy_helm_to_azure_k8s.sh -k az-use1-aks-dev21 -i <image-tag>`, and on dev-cluster-01 with `-k dev-cluster-01`.

---

## 10. Deploying the Hub to Your Namespace

The Hub deploys the same way, from the `hub` repository: a helmfile drives the shared `inveniam/app` chart with the Hub values from `helm_env_configs`. There is no Vault login step and no ConfigMap script: the pods authenticate to Vault themselves, and the script handles the rest. The Docker Hub login and the `helm-diff` plugin from section 9.1 are required here too.

### 10.1 Deploy

```
cd hub

# dev01
./helm/deploy_helm_to_aws_k8s.sh -n <your-namespace> -k aws-use1-eks-dev01 -i <hub-tag> --vault-kv hub-devus01

# dev21
./helm/deploy_helm_to_azure_k8s.sh -n <your-namespace> -k az-use1-aks-dev21 -i <hub-tag> --vault-kv hub-devus21

# dev-cluster-01
./helm/deploy_helm_to_aws_k8s.sh -n <your-namespace> -k dev-cluster-01 -i <hub-tag>
```

You only say **where** (namespace + cluster) and **what** (image tag). In a personal namespace, the script brings up the three Hub services (`hub-api`, `hub-front`, `hub-ns`) plus your own database and queues, so your stack is self-contained (section 10.3).

### 10.2 What the Script Derives

Everything else is derived. For `-n rvieira-test -k aws-use1-eks-dev01`:

| Derived | From | Result |
| --- | --- | --- |
| Workload (cluster, Vault address, cloud) | `-k`, matched against each workload's `k8s_cluster` in `helm_env_configs` | `dev01.yaml` |
| Environment | The namespace, minus a `hub-` prefix and a `-cluster` suffix | `rvieira-test` |
| Ingress hosts | `hub-<env>.<zone>` and `hub-<env>-api.<zone>` | `hub-rvieira-test.dev01.inveniam.io`, `hub-rvieira-test-api.dev01.inveniam.io` |
| Vault KV | `--vault-kv` if given; otherwise `hub-dev` for a personal namespace on dev-cluster-01; otherwise `hub-<env>` | `hub-rvieira-test` — which does not exist, so pass `--vault-kv hub-devus01` |
| Database and queues | A personal namespace gets its own | `hub-db` + `hub-aws` |

An environment namespace works the same way: `-n hub-devus01-cluster` derives the environment `devus01` and the KV `hub-devus01`, and keeps the shared database and queues. Environment namespaces on dev01 and dev21 are deployed by ArgoCD, so do not deploy there by hand.

### 10.3 Shared vs. Your Own Database and Queues

| Pod | Reached at | What it replaces |
| --- | --- | --- |
| `hub-db` | `hub-db:5432` | The shared Hub database |
| `hub-aws` (AWS clusters) | `http://hub-aws:4566` | The shared SQS/SNS queues |
| `hub-azure` (dev21) | In-namespace Service Bus emulator | The shared Service Bus |

`hub-aws` is localstack. Its topic and queues are created on startup with the same names as the real ones, so nothing in the application code changes.

The database and the queues always travel together. An isolated database on the shared queues would publish events referencing rows nobody else can see, and — because SQS is a competing consumer — your pods would take messages that then never reach the shared stack.

On dev-cluster-01 you can use the shared hub-dev data instead (e.g. to reproduce something against the existing organizations) with `--with-shared-infra`. Then remove the two releases you no longer use:

```
./helm/deploy_helm_to_aws_k8s.sh -n <your-namespace> -k dev-cluster-01 -i <hub-tag> --with-shared-infra
helm uninstall hub-db hub-aws -n <your-namespace>
```

### 10.4 Common Deploy Variations

```
# Deploy your branch (the tag is computed from the current git HEAD)
./helm/deploy_helm_to_aws_k8s.sh -n <your-namespace> -k aws-use1-eks-dev01 --vault-kv hub-devus01

# Deploy a specific branch you are not currently on
./helm/deploy_helm_to_aws_k8s.sh -n <your-namespace> -k aws-use1-eks-dev01 --vault-kv hub-devus01 -b INV-12345-my-feature

# Re-deploy only the API with a new image, leaving UI and NS alone
./helm/deploy_helm_to_aws_k8s.sh -n <your-namespace> -k aws-use1-eks-dev01 --vault-kv hub-devus01 -l hub-api -i <hub-tag>

# Deploy unpushed helm_env_configs changes from your own checkout
./helm/deploy_helm_to_aws_k8s.sh -n <your-namespace> -k aws-use1-eks-dev01 --vault-kv hub-devus01 -i <hub-tag> -L ~/git/inveniam/src/helm_env_configs

# Review the manifests without applying anything (-t or -T on AWS, -T on Azure)
./helm/deploy_helm_to_aws_k8s.sh -n <your-namespace> -k aws-use1-eks-dev01 --vault-kv hub-devus01 -i <hub-tag> -T
```

> **Note:** In the hub AWS script, `-t` means *template*, not tag. Always use `-i` for the Hub image tag.

### 10.5 Component Names

The `-l` flag takes a comma-separated list of the names below; omit `-l` to deploy all of them.

| Component | What it deploys | Pod name |
| --- | --- | --- |
| `hub-api` | Hub API | `hub-api` |
| `hub-front` (alias: `hub-ui`) | Hub UI | `hub-front` |
| `hub-ns` | Notifications service | `hub-ns` |
| `hub-db` | Your in-namespace PostgreSQL | `hub-db` |
| `hub-aws` | Your in-namespace localstack (SQS/SNS), AWS only | `hub-aws` |

The Helm release for the UI is named `hub-ui` but its pods are named `hub-front` — `kubectl get pods` shows `hub-front`, `helm list` shows `hub-ui`. You do not need to list `hub-db` / `hub-aws` yourself: the script adds them to whatever you passed in `-l`. Naming them alongside `--with-shared-infra` is an error.

### 10.6 Create a User for Yourself

Your Hub database starts empty, so there is no user you can log in with:

```
./helm/scripts/create_dev_user.sh -n <your-namespace> -e you@inveniam.io
```

It runs the repo's `create-hub-system-admin` task as a one-off Job inside your namespace, so it reads the database and FusionAuth settings from that stack. FusionAuth is shared across dev, so the invitation email may link to another host; use the link the script prints when it finishes, which points at your own host.

For the details of the value layering and the dev-infra config files, see `helm/DEPLOY.md` and `helm/README.md` in the [hub](https://github.com/inveniamcapital/hub) repo.

---

## 11. What the Deploy Scripts Do

When you invoke `helm/deploy_helm_to_aws_k8s.sh` or `helm/deploy_helm_to_azure_k8s.sh` in inveniam.io, the script:

1. Parses the namespace, cluster, optional component list, and image-tag arguments, and computes the image tag from git (or uses `-i`/`-t`).
2. Clones or updates `helm_env_configs` into `helm/.cache/helm_env_configs` (or uses your checkout with `-L`).
3. Finds the workload file whose `k8s_cluster` matches `-k`. This is why `-k` must be the full cluster name: `-k dev01` fails with `no workload file found`.
4. Derives the environment name from the namespace (a `-cluster` suffix is removed; a personal namespace keeps its name).
5. Applies the development settings: in-namespace dev-tools, the Vault KV path from `-V` (default `development`), and the cloud identity. On AWS, pods use the IAM role `inveniam-development-role` on dev-cluster-01 and `<workload>-development-role` on the other clusters (for example `dev01-development-role`). On Azure, pods authenticate to Vault with the Kubernetes method and your personal identity (section 5.5).
6. On AWS, creates the ConfigMap the pods need and switches your `kubectl` context to the target cluster.
7. Runs Helmfile for the selected components: `apply`, or `template` with `-T`.

Final step: `kubectl get pods -n <namespace>` to show the current state.

### Vault Authentication

Each pod runs an init container `vault-k8s-init` that authenticates to Vault with its **Kubernetes service-account token** to fetch the runtime secrets the app needs. The `vault-k8s-init` role is created by the Vault bootstrap script and accepts any service account from any namespace.

> **Note:** Never point the deploy scripts at a shared environment namespace (`<env>-cluster`). They always apply the development settings above, and they would conflict with ArgoCD.

---

## 12. Dev-Tools (in-namespace data stores)

The deploy script treats the in-namespace data stores as just-another component. They are deployed automatically when you don't pass `-l`, or explicitly when you include them in the list:

- `inv-db` — PostgreSQL
- `inv-rabbitmq` — RabbitMQ
- `inv-redis` — Redis
- `inv-mongodb` — MongoDB (AWS only)
- `inv-immudb` — ImmuDB (AWS only)
- `inv-maildev` — MailDev, which catches the emails the services send

The Hub has its own: `hub-db` and, on AWS, `hub-aws` (section 10.3).

To **skip** dev-tools, list only the application microservices in `-l`:

```
./helm/deploy_helm_to_aws_k8s.sh \
  -n <your-namespace> -k aws-use1-eks-dev01 \
  -l inv-front,inv-iam,inv-ai,...
```

> **Note:** The application microservices in dev are configured to talk to the in-namespace data stores by hostname (`inv-db`, `inv-redis`, etc.). If you skip them, the services have nothing to connect to. `helm/README.md` mentions `--without-dev-db`, `--without-dev-rabbitmq` and `--without-dev-redis`, but the scripts do not accept those flags yet. The typical pattern is "deploy with dev-tools".

---

## 13. Verifying the Deployment

### 13.1 Pod Status

```
kubectl get pods -n <namespace>
```

The `READY` column should show `1/1` (or `2/2` if the pod has a sidecar) for every pod. The first deployment can take up to 30 minutes (image pulls, DB migrations, Vault bootstrap).

If the `READY` column still shows `0/1` or `1/2` after 30 minutes, inspect events and logs:

```
kubectl describe pod -n <namespace> <pod-name>
kubectl logs -n <namespace> <pod-name>
```

> **Note:** On dev-cluster-01, a job scales every deployment in the `-test` namespaces to zero every day at 19:30 UTC. If you find your pods gone, bring them back with `kubectl scale deploy --all -n <namespace> --replicas=1` (dev-tools first, then the apps).

### 13.2 Application URLs (your namespace)

After a successful deploy, the application is accessible at:

| Endpoint | dev-cluster-01 | dev01 | dev21 |
| --- | --- | --- | --- |
| Frontend UI | `https://<namespace>.inveniam.io` | `https://<namespace>.dev01.inveniam.io` | `https://<namespace>.dev21.inveniam.io` |
| API microservices | `https://<namespace>-api.inveniam.io/<microservice-name>` | `https://<namespace>-api.dev01.inveniam.io/<microservice-name>` | `https://<namespace>-api.dev21.inveniam.io/<microservice-name>` |
| Hub UI (if Hub components are deployed) | `https://hub-<namespace>.inveniam.io` | `https://hub-<namespace>.dev01.inveniam.io` | `https://hub-<namespace>.dev21.inveniam.io` |
| Hub API | `https://hub-<namespace>-api.inveniam.io/` | `https://hub-<namespace>-api.dev01.inveniam.io/` | `https://hub-<namespace>-api.dev21.inveniam.io/` |

To see the exact hosts and paths of each service, list the ingresses of your namespace:

```
kubectl get ingress -n <namespace>
```

### 13.3 Shared Environment URLs

| Endpoint | dev-cluster-01 (`qa1`–`qa16`) | dev01 | dev21 |
| --- | --- | --- | --- |
| UI | `https://<env>.inveniam.io` | `https://<env>.dev01.inveniam.io` | `https://<env>.dev21.inveniam.io` |
| Legacy UI | `https://<env>-v1.inveniam.io` | `https://<env>-v1.dev01.inveniam.io` | `https://<env>-v1.dev21.inveniam.io` |
| Public API | `https://<env>-api.inveniam.app` | `https://<env>-api.dev01.inveniam.app` | `https://<env>-api.dev21.inveniam.io` |
| Hub | `https://hub-<env>.inveniam.io` | `https://hub-<env>.dev01.inveniam.io` | `https://hub-<env>.dev21.inveniam.io` |

The full list, including Chat, Cron, CDN and Studio, and the version deployed in each environment is in [DevOps Infrastructure Details](https://inveniam.atlassian.net/wiki/spaces/InveniamDevOps/pages/1201635346/DevOps+Infrastructure+Details).

---

## 14. Working with the Deployed Services

### 14.1 Logs (kubectl)

Tail logs of a running service:

```
kubectl logs -f -n <namespace> service/<inv-service-name>
```

Filter healthcheck noise:

```
kubectl logs -n <namespace> <pod-name> \
  | grep -v "/status" | grep -v "statusCode\":200"
```

Format JSON logs with Bunyan or pino-pretty:

```
kubectl logs -f -n <namespace> service/<inv-service-name> \
  | ./node_modules/.bin/bunyan
```

### 14.2 Logs (Kibana) and Metrics (Grafana)

For aggregated logs across environments:

- **AWS clusters (dev-cluster-01, dev01):** <https://kibana.inveniam.io/>, index pattern `inveniam-logs1-dev*`
- **Azure cluster (dev21):** <https://kibana.sharedsvc21.inveniam.io/>

Pod CPU, memory and restarts are on the [K8s Pod Metrics](https://dashboard.inveniam.io/d/r1m-inuIk/k8s-pod-metrics) Grafana dashboard: select the cluster's data source and the namespace.

Contact DevOps if you do not have access.

### 14.3 Connect to a Container

```
kubectl exec -ti -n <namespace> <pod-name> -- sh
```

### 14.4 Database Access (In-Namespace `inv-db` and `hub-db`)

If you deployed with dev-tools, port-forward to your in-namespace Postgres:

```
kubectl port-forward -n <namespace> service/inv-db 5555:5432
```

Then connect with your client of choice on `localhost:5555`.

For the Hub database:

```
kubectl port-forward -n <namespace> service/hub-db 5556:5432
```

Connect on `localhost:5556` (`hubuser` / `hubdb`).

Reset the local Postgres data (use with care):

```
kubectl exec -ti -n <namespace> service/inv-db -- \
  bash -c 'rm -rf /var/lib/postgresql/data/*'
```

### 14.5 Database Access (dev01 Shared PostgreSQL via SSM)

All dev01 environments share one PostgreSQL server, which is not reachable from the internet or from the VPN. AWS Systems Manager (SSM) tunnels a connection through the bastion to the managed RDS instance, avoiding direct network access. You need the Session Manager plugin and an active SSO session (section 4.6).

```
aws sso login --profile inveniam-dev

aws ssm start-session \
  --profile inveniam-dev \
  --region us-east-1 \
  --target i-0c752dbd7d5bb60cc \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["aws-use1-eks-dev01-postgres.clahbqmoy4gt.us-east-1.rds.amazonaws.com"],"portNumber":["5432"],"localPortNumber":["15432"]}'
```

Once the session is established, the command prints:

```
Starting session with SessionId: ...
Port 15432 opened for sessionId ...
Waiting for connections...
```

Connect to PostgreSQL on `127.0.0.1:15432` using your preferred client (section 14.7). The local port is `15432` rather than `5432` so it does not clash with a PostgreSQL already running on your machine.

> **Note:** Keep this terminal session open while you need database access. Closing it will terminate the tunnel.

To confirm the RDS endpoint:

```
aws rds describe-db-instances --profile inveniam-dev --region us-east-1 \
  --query 'DBInstances[].[DBInstanceIdentifier,Endpoint.Address,Endpoint.Port,DBInstanceStatus]' --output table
```

### 14.6 Database Access (dev21 Shared PostgreSQL via the Azure Bastion)

All dev21 environments share one private PostgreSQL server, reachable only from the bastion (section 5.6):

```
az login --tenant 4cd2b728-f5a4-4510-b911-64f62ce654bb
az account set --subscription 13b6951a-e53b-49ed-afe5-26ca73207500

az ssh vm \
   --name az-use1-bastion-dev21 \
   --resource-group dev21 \
   -- -N -L 15432:az-use1-postgresql-dev21.postgres.database.azure.com:5432
```

Connect to PostgreSQL on `127.0.0.1:15432` (section 14.7). Credentials live in Vault (section 8.2) and in the [Password Manager – devus21](https://passwords.inveniam.io/index.php/prj/view/289).

### 14.7 SQL Client Settings for the Tunnels

With a tunnel running (sections 14.5 and 14.6), your SQL client connects to **your machine**, not to the cloud hostname:

| Field | Value |
| --- | --- |
| Host | `127.0.0.1` (prefer it over `localhost`, which can resolve to IPv6 and miss the tunnel) |
| Port | The tunnel's local port, `15432` in the examples |
| Database, username, password | From Vault (section 8.2), or from the [password manager](https://passwords.inveniam.io/) — search by environment name (e.g. `devus01`, `devus21`), not by hostname |
| SSL | SSL mode `require`. Leave server certificate verification off: the certificate names the server, not `127.0.0.1`. |

Do not put the RDS or Azure hostname in the client's host field; that host is only reachable from the bastion. Before opening a tunnel, you can check whether the local port is free with `lsof -nP -iTCP:15432 -sTCP:LISTEN`. For a step-by-step DBeaver setup, see [Connect to PostgreSQL from DBeaver (AWS SSM / Azure Bastion)](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/2721382414/Connect+to+PostgreSQL+from+DBeaver+AWS+SSM+Azure+Bastion).

### 14.8 Redis Access

In-namespace Redis (dev-tools):

```
kubectl port-forward -n <namespace> service/inv-redis 6379:6379
```

Shared Redis on dev01 and dev21. It runs inside each cluster in the `redis` namespace, is shared by every environment of that cluster, and is not behind the bastion, so use a port-forward on both clouds:

```
kubectl port-forward -n redis svc/redis-master 16379:6379
```

In a second terminal, log in to the cluster's Inveniam Vault (sections 4.8 and 5.7) and connect:

```
export REDISCLI_AUTH="$(vault kv get -field=password <env>-cluster/redis)"
redis-cli -h 127.0.0.1 -p 16379
```

> **Note:** Every environment of the cluster uses the shared Redis. Do not flush it or delete keys in bulk.

### 14.9 Other In-Cluster Services

Any other service inside a cluster is reached the same way. For example, each shared environment's immudb runs in `inveniam-immudb-<env>-cluster`: list its services, then forward the port you need.

```
kubectl get svc -n inveniam-immudb-<env>-cluster
kubectl port-forward -n inveniam-immudb-<env>-cluster svc/<service> <local-port>:<service-port>
```

---

## 15. Hybrid: Frontend Locally + API in Cluster

You can run the full backend stack in Kubernetes and the `inv-front` container locally pointing at it. Useful for frontend developers who want to iterate on the UI without rebuilding the backend each time.

```
cd inveniam.io

# Build shared modules
npm run build:shared-modules

# Start inv-front pointing at the remote API (dev01 example)
BACKEND_HOST=https://<your-namespace>-api.dev01.inveniam.io \
  docker compose up --build inv-front
```

Use the API host of your cluster: `https://<your-namespace>-api.inveniam.io` on dev-cluster-01, `https://<your-namespace>-api.dev01.inveniam.io` on dev01, `https://<your-namespace>-api.dev21.inveniam.io` on dev21. If you omit `BACKEND_HOST`, the local frontend tries to reach `http://localhost:8881`.

To make the override permanent, add it to your shell profile:

```
export BACKEND_HOST=https://<your-namespace>-api.dev01.inveniam.io
```

This pattern also lets several developers share the same backend environment by pointing each local frontend at a common API URL.

For a fuller local-development setup — running any single microservice locally against your namespace — see section 16.

---

## 16. Running a Service Locally with Telepresence (dev-cluster-01)

You edit the code, build the image locally, and run it — while the rest of the stack keeps running in your namespace. Cluster traffic addressed to that service is routed to your container instead of the pod, and your container reaches the cluster services by their normal names. No commit → CI → image → redeploy loop for every change.

It works the same for both products: `start_component_locally.sh` sits at the root of the `inveniam.io` and the `hub` repos. Underneath it is [Telepresence](https://telepresence.io/) (the open-source, CNCF build) — no cluster install and no Ambassador Cloud account.

> **Note:** This works on **dev-cluster-01 only**. dev01 and dev21 have no Telepresence traffic manager, and the script is built for AWS IAM roles, so it does not run on Azure.

### 16.1 Install the Client

Version-matched to the cluster traffic-manager (currently `2.23.6`). A different version fails the intercept with an obscure port-forward timeout:

```
PLATFORM=$(uname -s | tr 'A-Z' 'a-z')                      # darwin or linux
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')  # amd64 or arm64
mkdir -p ~/.local/bin
curl -fsSL -o ~/.local/bin/telepresence \
  "https://github.com/telepresenceio/telepresence/releases/download/v2.23.6/telepresence-$PLATFORM-$ARCH"
chmod +x ~/.local/bin/telepresence
export PATH="$HOME/.local/bin:$PATH"
telepresence version   # OSS Client : v2.23.6
```

Pick the service to intercept. It must already exist as a Deployment in your namespace — Telepresence taps an existing workload, it does not create one:

```
kubectl get deploy -n <your-namespace>
```

### 16.2 Build and Run a Hub Service

The service images build `FROM hub-shared-modules`, a **local** base image. Build it once, and again whenever `shared-modules/` or a `package.json` changes. Build the `hub-api-telepresence` target, not the production image: the production entrypoint runs migrations first and is not meant for local dev.

```
cd hub

npm run build:hub:shared-modules            # base image, once
docker build --target hub-api-telepresence -t hub-api:local apps/backend

./start_component_locally.sh -n <your-namespace> -l hub-api -i hub-api:local
```

Hot reload — mount your source over the container's so changes rebuild in place, without rebuilding the image:

```
./start_component_locally.sh -n <your-namespace> -l hub-api -i hub-api:local -- \
  -v "$PWD/apps/backend/src:/opt/app/apps/backend/src"
```

### 16.3 Build and Run an inveniam.io Service

Same shape, with that repo's own base image:

```
cd inveniam.io

npm run build:shared-modules                # base image, once
docker compose build inv-hub-ms             # your change -> image "inv-hub-ms"

./start_component_locally.sh -n <your-namespace> -l inv-hub -i inv-hub-ms
```

> **The base images are heavy.** Building both at once can exhaust Docker's memory and take the daemon (or your machine) down with it. Build one at a time, and give Docker Desktop a generous memory limit.

### 16.4 What the Script Does for You

It connects Telepresence, captures the live pod's environment, and runs your image in the foreground. When the app prints that it is listening, cluster traffic to that service is hitting your machine. Because the container inherits the pod's environment, it talks to the same database and queues that pod does — your own `hub-db` / `hub-aws` / `inv-db`, with no extra configuration.

Two things it handles that are easy to get wrong by hand:

- **Vault.** Off-cluster there is no IRSA token, so the container cannot authenticate the way the pod does. The script **assumes the IAM role the pod uses** (`inveniam-development-role`) and hands that session to the container, which therefore holds the pod's exact Vault policy. Your IAM user must be allowed to assume that role; ask DevOps if the script says it cannot. Authenticating as *yourself* instead is the subtle trap: your role logs in to Vault fine and then gets a `403` on every secret the app reads.
- **Cluster DNS.** The script points the container at the Telepresence DNS, so `hub-db`, `inv-db` and friends resolve live — including Services created after you started.

### 16.5 Flags

| Flag | When you need it |
| --- | --- |
| `-P <aws-profile>` | Only if the AWS CLI would otherwise resolve the wrong profile (for example, you use SSO and did not `export AWS_PROFILE`). |
| `-r <vault-role>` | Only if you cannot assume the pod's IAM role (see above). That role must be allowed to read the app's secrets. |
| `-i <image>` | Defaults to `<deployment>:local`. |
| `-s`, `-p` | Service / port, when they cannot be derived from the Deployment. |
| `--host` / `--docker` | Network mode. Defaults to host on Linux, docker on macOS — behind a VPN on Linux, keep the default. |
| `-- <docker args>` | Everything after `--` is passed to `docker run` (e.g. extra `-e`, `-v`). |

### 16.6 Check and Stop

**Run more than one service** by opening another terminal and running the script again — the Telepresence connection is shared, so it just adds a second intercept. This is how you test a cross-product change, e.g. `inv-hub` locally against a Hub stack in the same namespace.

```
telepresence status                     # connection + active intercepts
telepresence list -n <your-namespace>
```

`Ctrl-C` in each terminal stops that container and releases its intercept; the cluster pod takes over again instantly. To tear the whole connection down:

```
telepresence quit -s
```

While an intercept is active the pod shows `2/2`: the original container keeps running (bypassed) next to the injected `traffic-agent` sidecar that reroutes the traffic. That is by design — leaving the intercept restores the cluster pod with no redeploy. If your local container crashes, the pod drops to `1/2`: the readiness probe is forwarded to your machine, so it fails while your container is down.

The same guide is versioned next to the code in `LOCAL_DEV.md` at the root of the `hub` repo; that copy is the source of truth when the two disagree.

---

## 17. Deploying a Build to a Shared Environment (ArgoCD)

Shared environments are deployed by ArgoCD from [helm\_env\_configs](https://github.com/inveniamcapital/helm_env_configs). On every dev01, dev21 and dev-cluster-01 environment you choose the build yourself in the ArgoCD UI, and the value you set stays until someone changes it — ArgoCD does not reset it from Git.

1. Open [ArgoCD](https://argocd.sharedsvc01.inveniam.io/login) and find the application `<app>-<env>`, for example `inveniam-devus01`, `hub-devus21` or `inveniam-qa3`.
2. Open **Details**, go to the **Parameters** tab, click **Edit**, set `IMAGE_TAG` to the tag you want (section 9.6) and save.
3. Click **Sync**.

Before deploying to an environment, check in [Inveniam Environment Information](https://inveniam.atlassian.net/wiki/spaces/InveniamDevOps/pages/1201864718/Inveniam+Environment+Information) which team uses it. For screenshots of these steps, see [Using the ArgoCD UI](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/2404581377/Using+the+ArgoCD+UI). To change an application parameter permanently, see [Managing application parameters through helm env configs](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/2463072261/Managing+application+parameters+through+helm+env+configs).

---

## 18. Destroying the Deployment

Uninstall the inveniam.io releases from a `-test` namespace. The script has no cluster flag and uses your current `kubectl` context, so check it first:

```
kubectl config current-context
./helm/destroy_helm_releases.sh -n <your-namespace>
```

Options:

| Option | Description |
| --- | --- |
| `-l <releases>` | Uninstall only these releases (default: all app releases + dev-tools) |
| `--keep-dev-tools` | Keep `inv-db`, `inv-rabbitmq`, `inv-redis`, `inv-mongodb`, `inv-immudb`, `inv-maildev` |
| `--only-dev-tools` | Uninstall only the dev-tools |

Uninstall the Hub releases (on dev21 there is no `hub-aws`; run `helm list -n <your-namespace>` to see the names):

```
helm uninstall hub-api hub-ui hub-ns hub-db hub-aws -n <your-namespace>
```

To delete persistent volume claims that the uninstall preserves (this wipes your databases):

```
kubectl delete pvc -n <namespace> --all
```

---

## 19. Troubleshooting

### Deploy Script Errors

`no workload file found`

`-k` must be the full cluster name: `dev-cluster-01`, `aws-use1-eks-dev01` or `az-use1-aks-dev21`, not `dev01` or `dev21`.

`helm pull ... 401 unauthorized: authentication required`

The `inveniam/app` chart is private and your local `helm` is not logged in to Docker Hub. Run `helm registry login registry-1.docker.io -u <your-dockerhub-user>` (section 9.1). If it still fails after logging in, your Docker Hub user lacks access to the private repo — contact Wasim Buden.

`unknown command "diff" for "helm"`

Helmfile computes changes with the `helm-diff` plugin, which is not installed. Run `helm plugin install https://github.com/databus23/helm-diff`, then re-run the deploy.

`local helm_env_configs dir not found: <path>`

The path you passed to `-L` does not exist. Fix the path, or drop `-L` and let the script fetch the repo into `helm/.cache/`.

`unknown argument` for `--without-dev-db` / `--without-dev-rabbitmq` / `--without-dev-redis`

These flags are documented in `helm/README.md` but not implemented. To skip dev-tools, list only the apps in `-l` (section 12).

`hub-db is not part of this deploy (shared infra)`

You named an infra release in `-l` while the Hub deploy uses the shared database and queues. Drop it from `-l`, or remove `--with-shared-infra` (section 10.3).

Deploy stops asking to run `create_azure_configmap.sh` (dev21)

Your namespace has no `developer-config` ConfigMap. Contact DevOps: the ConfigMap is created together with the namespace, and the script cannot create it from scratch (section 9.1).

`ImagePullBackOff` / `ErrImagePull`

Two causes:

- **Missing tag** — the image tag does not exist for that image. Check that the GitHub Actions run for your branch finished (section 9.6), or pass an existing tag with `-i`.
- **Auth failure** (`401 unauthorized` / `authentication required` in the pod events) — the Inveniam Docker Hub image repos are **private**, and the namespace's `dockerhub-regcred` pull secret is missing or expired. DevOps provisions it at namespace creation; contact them to restore it. (This is separate from the local `helm registry login`.)

### Pod Init Failures

**Pod stuck in** `Init:Error` / `Init:CrashLoopBackOff`

Check the init container logs:

```
kubectl logs -n <namespace> <pod-name> -c vault-k8s-init
```

Common causes:

- `invalid role name` — the Vault Kubernetes auth role does not exist for your service account. Contact DevOps to run the Vault bootstrap or create the role manually.
- `permission denied` on a secret path — the Vault KV the deploy reads does not exist or your role cannot read it. For the Hub on dev01/dev21, check that you passed `--vault-kv` (section 10.2).
- `403 Forbidden (HTML)` — the pod cannot reach Vault via the external URL. Check that network policies allow the egress.

### AWS Authentication

**"Unable to locate credentials"** / `no credentials found` / `Could not export AWS credentials for profile 'default'`

- IAM flow (dev-cluster-01): confirm `~/.aws/credentials` has a valid `[default]` block with `aws_access_key_id` and `aws_secret_access_key`.
- SSO flow (dev01): the command did not name your profile, so it read `default`. Pass `--profile inveniam-dev` or `export AWS_PROFILE=inveniam-dev`, and re-run `aws sso login --profile inveniam-dev` if the session expired.

In both cases, sanity-check with:

```
aws sts get-caller-identity
```

`AccessDenied` when calling the AssumeRole operation

```
User: arn:aws:iam::472345033518:user/<your-user> is not authorized to perform: sts:AssumeRole
```

The IAM policy that allows EKS access is not attached to your IAM user group. Contact DevOps.

`Error from server (Forbidden)` on `kubectl` after a successful AWS login

Your AWS identity is authenticated but not mapped to the cluster RBAC. Send DevOps:

- Your IAM user ARN (or SSO identity and permission set)
- Cluster name
- Namespace
- Full `kubectl` error output

**"You must be logged in to the server (Unauthorized)"**

- IAM flow: re-run `aws sts get-caller-identity`. If that succeeds, regenerate the kubeconfig with `aws eks --region us-east-1 update-kubeconfig --name dev-cluster-01`.
- SSO flow: re-run `aws sso login --profile inveniam-dev`, then `aws sts get-caller-identity --profile inveniam-dev`. The ARN must show `AWSReservedSSO_AWSPowerUserAccess`: other permission sets, such as `OperatorAccess`, are not mapped to dev01.

**Timeouts / cannot reach cluster endpoint**

Common causes: VPN not connected, DNS restrictions. The dev-cluster-01 and dev01 API endpoints only accept connections from the VPN.

**Exec plugin / apiVersion errors**

Upgrade AWS CLI v2 and regenerate the kubeconfig with `--force`:

```
aws eks update-kubeconfig --name <cluster> --region <region> --force
```

If the error mentions `client.authentication.k8s.io/v1alpha1`, manually replace that string with `client.authentication.k8s.io/v1beta1` in `~/.kube/config`.

### Azure

**Permission issues after being added to the** `Developers` group

Token claims are cached; force a refresh:

```
az account clear
az logout
az login --tenant 4cd2b728-f5a4-4510-b911-64f62ce654bb
```

`kubelogin` not found

macOS:

```
brew install Azure/kubelogin/kubelogin
```

Ubuntu:

```
sudo az aks install-cli
```

`kubectl` or `az ssh vm` times out

The AKS API endpoint and the bastion's SSH port only accept connections from the VPN. Connect the VPN and try again.

### Database Tunnels

`SessionManagerPlugin is not found`

The AWS SSM tunnel needs the Session Manager plugin. Install it (section 2).

`AccessDeniedException` when calling the `StartSession` operation

Your SSO permission set cannot open sessions on the bastion. Use `AWSPowerUserAccess`; the QA permission set has no bastion access.

The tunnel shows `Waiting for connections`, but the SQL client times out or is reset

SSM or SSH can start even when the local port is already owned by Docker or an old tunnel; your client then talks to the wrong process. Check with `lsof -nP -iTCP:15432 -sTCP:LISTEN` and use a free local port in both the tunnel and the client.

Timeout after tunnelling an `*.rds.amazonaws.com` host through the Azure bastion (or an Azure host through SSM)

There is no network path between the clouds. Pick the tunnel by the database hostname: `*.rds.amazonaws.com` uses SSM (section 14.5), `*.postgres.database.azure.com` uses the Azure bastion (section 14.6).

`no pg_hba.conf entry ... no encryption`

SSL is disabled in your client. Set SSL mode to `require` (section 14.7).

### Vault

`vault: command not found`

Install the Vault CLI (see section 2) and log in again (sections 4.8 and 5.7).

`vault login` → `NoCredentialProviders: no valid providers in chain`

`vault login -method=aws` signs a request with your AWS credentials, and it cannot read an SSO session. Run `eval "$(aws configure export-credentials --profile <profile> --format env)"` first (section 4.8). The exported credentials expire; re-run it when Vault starts refusing you again.

`vault login` → `IAM Principal ... is not authorized to login for role X` / `entry for role X not found`

The first means the role exists but is bound to a different identity; the second that it does not exist on this Vault. Check the role for your cluster and login method in section 8.1.

`permission denied` when reading a secret you could read before

Your token expired (one hour on dev01 and dev21), or `VAULT_ADDR` points at the wrong instance — Hub secrets exist only in the Hub Vault. On dev21, make sure you exported `VAULT_TOKEN` (section 5.7).

### Hub

The Hub UI logs you out, or shows no organizations

Your database is your own and starts empty. Invite yourself a user (section 10.6), or, on dev-cluster-01, redeploy with `--with-shared-infra` to use the hub-dev data.

Hub pods in a personal namespace on dev01 or dev21 cannot read their secrets

The deploy ran without `--vault-kv`, so it looked for a Vault KV named after your namespace, which does not exist. Deploy again with `--vault-kv hub-<env>` (section 10.2).

### Telepresence (dev-cluster-01)

| Symptom | Fix |
| --- | --- |
| `pull access denied … hub-shared-modules` when building an image | `hub-shared-modules` is a local base image. Run `npm run build:hub:shared-modules` first (section 16.2). |
| `Nest could not find DataSource` during the hub-api migration | You built the production image. Build the `hub-api-telepresence` target instead. |
| Your locally-run service logs in to Vault, then gets `403` on every secret | It is authenticating as you instead of as the pod. Drop `-r` and let the script assume the pod's IAM role. |
| `Could not assume inveniam-development-role with your credentials` | Your IAM user needs `sts:AssumeRole` on that role — ask DevOps. `-r` is not a substitute: a personal role cannot read the app's secrets. |
| Intercept times out → `timeout waiting for port-forward to traffic-agent` / `context deadline exceeded` (Linux + VPN) | Your `tel0` MTU is above the VPN's, so handshakes get dropped. The script lowers it automatically in host mode (you will see `Lowered tel0 MTU to ...`). If you still hit it, confirm the client is `v2.23.6` and that you are in host mode (the Linux default — do not force `--docker` behind a VPN). |
| `using OSS client vX to connect to an enterprise traffic manager v2.20.2` | You connected by hand without `--manager-namespace default` and hit the legacy manager. The script always passes it. |
| `Unable to create network …-cn: … netns … no such process` | Stale Docker network from a crashed session. `docker network rm <the -cn network>` (restart Docker first if it will not delete), then reconnect. |
| `timed out while waiting for agent … to arrive` | The deployment has no running pod, usually after the nightly scale-down. `kubectl scale deploy --all -n <ns> --replicas=1` (dev-tools first), or redeploy. |
| `Failed to intercept` → `AGENT_ERROR: Conflicts with the currently-waiting-to-be-served intercept` | A previous run died without cleaning up (Docker Desktop crashing does exactly this). `telepresence uninstall <deployment>`, then run the script again. |
| Docker died while a component ran locally, and the pod sits at `1/2` and keeps restarting | The traffic-agent is still in the pod, sending the health probes to a container that no longer exists. `telepresence uninstall <deployment>` puts the pod back to `1/1`. |

### Application

**Pod logs:** `Unable to connect to the database (eventstore)`

The in-namespace Postgres is in a bad state. Before re-running the deploy:

```
kubectl get deployment -n <namespace>
kubectl delete deployment -n <namespace> inv-db

kubectl get pvc -n <namespace>
kubectl delete pvc -n <namespace> pg-data

kubectl get configmap -n <namespace> inv-db-config
kubectl delete configmap -n <namespace> inv-db-config
```

Then redeploy. If the names differ in your namespace, use the ones the `kubectl get` commands show.

---

## 20. Useful Links

### Internal Documentation

- [Developer Quickstart — dev-cluster-01](https://inveniam.atlassian.net/wiki/spaces/InveniamDevOps/pages/2426896391/Developer+Quickstart+dev-cluster-01)
- [Dev Namespace Walkthrough — the short version](https://inveniam.atlassian.net/wiki/spaces/InveniamDevOps/pages/2560819205/Dev+Namespace+Walkthrough+the+short+version)
- [How to Set Up AWS SSO and Connect to EKS Clusters](https://inveniam.atlassian.net/wiki/spaces/IN/pages/1846476813/How+to+Set+Up+AWS+SSO+and+Connect+to+EKS+Clusters)
- [Load Testing Environment — Developer Access Guide](https://inveniam.atlassian.net/wiki/spaces/IN/pages/2042003461/Load+Testing+Environment+Developer+Access+Guide)
- [Azure Developer Environment Guide](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/1133510674/Azure+Developer+Environment+Guide)
- [Connect to PostgreSQL from DBeaver (AWS SSM / Azure Bastion)](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/2721382414/Connect+to+PostgreSQL+from+DBeaver+AWS+SSM+Azure+Bastion)
- [Using the ArgoCD UI](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/2404581377/Using+the+ArgoCD+UI)
- [Rolling out a release through ArgoCD](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/2385870849/Rolling+out+a+release+through+ArgoCD)
- [Managing application parameters through helm env configs](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/2463072261/Managing+application+parameters+through+helm+env+configs)
- [Using the Argo Workflows UI](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/2515697668/Using+the+Argo+Workflows+UI)
- [SOP: User Onboarding - Kubernetes, Vault, Kibana, team city](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/1128726687/SOP+User+Onboarding+-+Kubernetes+Vault+Kibana+team+city)
- [Accesses & Permissions](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/2518482963/Accesses+Permissions)
- [OpenVPN - User Guide](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/69009495/OpenVPN+-+User+Guide)
- [DevOps Infrastructure Details](https://inveniam.atlassian.net/wiki/spaces/InveniamDevOps/pages/1201635346/DevOps+Infrastructure+Details)
- [Inveniam Environment Information](https://inveniam.atlassian.net/wiki/spaces/InveniamDevOps/pages/1201864718/Inveniam+Environment+Information)
- [EKS Multi-Cluster Version & Chart Tracking](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/943095822/EKS+Multi-Cluster+Version+Chart+Tracking)
- [Inveniam.io environments — Inventory](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/5445025)
- [Notes on how to interact with Vault](https://inveniam.atlassian.net/wiki/spaces/IPPP/pages/5463134/Notes+on+how+to+interact+with+Vault)

### External

- [inveniam.io repo](https://github.com/inveniamcapital/inveniam.io)
- [hub repo](https://github.com/inveniamcapital/hub)
- [helm\_env\_configs repo](https://github.com/inveniamcapital/helm_env_configs)
- [AWS SSO portal](https://inveniam.awsapps.com/start)
- [AWS Console](https://inveniam.signin.aws.amazon.com/console)
- [Azure Portal](https://portal.azure.com)
- [Kibana (AWS)](https://kibana.inveniam.io/) and [Kibana (Azure)](https://kibana.sharedsvc21.inveniam.io/)
- [TeamCity](https://teamcity.inveniam.io/) (VPN required)
- [Grafana (Dev)](https://grafana-dev.inveniam.io/)
- [ArgoCD UI](https://argocd.sharedsvc01.inveniam.io/login)
- [OpenVPN](https://openvpn.inveniam.io/)
