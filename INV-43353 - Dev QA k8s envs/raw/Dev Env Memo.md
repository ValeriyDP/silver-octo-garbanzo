---
name: Dev Env Memo
date: 2026-10-21T15:42:00.000Z
tags:
  - dev-env
  - kubernetes
  - helm
  - aws
  - eks
  - telepresence
  - how-to
---

# Dev Env Memo

Bring a personal dev namespace up on EKS from scratch, run one service locally against it, and tear it down clean. Reconstructed from shell history, with the dead ends removed.

Namespace used throughout: `valeriii-test`. Cluster: `dev-cluster-01` (account `472345033518`, `us-east-1`).

## 1. Verify the AWS account

```bash
aws sts get-caller-identity
```

Never add `--profile`. An explicit `--profile` flag removes the environment-variable provider from the botocore credential chain, and the command fails with `NoCredentials`. Credentials come from `pass` via `direnv`, so every command here only works inside a directory where `.envrc` has loaded.

## 2. Point kubectl at the cluster

```bash
aws eks --region us-east-1 update-kubeconfig --name dev-cluster-01
kubectl config use-context arn:aws:eks:us-east-1:472345033518:cluster/dev-cluster-01
kubectl auth whoami
kubectl get ns -o name
```

There are two dev clusters in two accounts: `aws-use1-eks-dev01` in `403170495167` and `dev-cluster-01` in `472345033518`. `dev-cluster-01` is the deploy script's default.

If `aws eks get-token` succeeds but the API server answers `You must be logged in to the server (Unauthorized)`, that is authorization, not authentication — the IAM principal is not mapped to RBAC via an access entry or `aws-auth`. Fixed cluster-side; local config is not involved.

## 3. One-time tooling

```bash
brew install helm helmfile derailed/k9s/k9s
helm plugin install https://github.com/databus23/helm-diff --verify=false
helm registry login registry-1.docker.io -u <dockerhub-user>

PLATFORM=$(uname -s | tr 'A-Z' 'a-z'); ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
mkdir -p ~/.local/bin
curl -fsSL -o ~/.local/bin/telepresence \
"https://github.com/telepresenceio/telepresence/releases/download/v2.23.6/telepresence-$PLATFORM-$ARCH"
chmod +x ~/.local/bin/telepresence && telepresence version
```

Telepresence is pinned to v2.23.6 to match the cluster traffic-manager.

## 4. Session prerequisites

```bash
cd inveniam.io && git checkout develop && git pull --rebase origin develop
```

The SSH key is required because the deploy script clones `helm_env_configs` over SSH on every run.

## 5. Deploy the namespace

One command, on a published application tag:

```bash
./helm/deploy_helm_to_aws_k8s.sh -k dev-cluster-01 -n valeriii-test -t <app-tag>
```

`-t` applies to the application services only. The three dev-tools releases that carry a tag — `inv-db`, `inv-rabbitmq`, `inv-mongodb` — pin their own in `helm/configs/defaults.yaml` and ignore it, because their images are published by the manual Dev Build workflow rather than on every app build.

`<app-tag>` is a develop build, shaped `major.minor.<run_number>`; the main CI mints one on every push to develop. Read the current value off a namespace that is already working:

```bash
kubectl get deploy inv-hub -n <working-namespace> \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

The script switches the kubectl context itself, clones or refreshes `helm_env_configs` into `helm/.cache/helm_env_configs`, writes the per-service `sa_annotations` ConfigMaps, provisions the `inv-efs` NFS server with its PVs, and runs helmfile.

Variants:

```bash
# render manifests, no cluster writes
./helm/deploy_helm_to_aws_k8s.sh -k dev-cluster-01 -n valeriii-test -T
# subset of services
./helm/deploy_helm_to_aws_k8s.sh -k dev-cluster-01 -n valeriii-test -l inv-iam,inv-ai -t <app-tag>
# uncommitted helm_env_configs checkout
./helm/deploy_helm_to_aws_k8s.sh -k dev-cluster-01 -n valeriii-test -L ~/git/inveniam/src/helm_env_configs
```

## 6. Verify

```bash
kubectl get pods -n valeriii-test
k9s -n valeriii-test
```

## 7. Run one service locally

```bash
telepresence connect -n valeriii-test
docker build -t inv-front:local apps/front
./start_component_locally.sh -n valeriii-test -l inv-front -i inv-front:local
```

No `-P` flag. The script resolves credentials from the environment and assumes the pod's IAM role itself, so the container inherits the pod's exact Vault policy.

## 8. Teardown

```bash
helm list -n valeriii-test -q | xargs -r helm uninstall -n valeriii-test
kubectl delete pvc --all -n valeriii-test
kubectl delete jobs,cronjobs --all -n valeriii-test
kubectl delete pv valeriii-test-ai-extraction valeriii-test-cron valeriii-test-bulk-download
kubectl get all,pvc -n valeriii-test
```

If pods or PVCs hang in `Terminating`, a finalizer is holding them:

```bash
kubectl delete pods --all -n valeriii-test --grace-period=0 --force
kubectl patch pvc <name> -n valeriii-test -p '{"metadata":{"finalizers":null}}'
```

## Traps

**Never deploy from `develop` without `-t`.** The script defaults to `LOCAL-<branch>-<sha8>`, but CI only publishes `LOCAL-` tags for branches whose name starts with `INV-`; on develop it publishes `major.minor.<run_number>` and `latest` instead. Deploying from develop with no `-t` therefore asks for `LOCAL-develop--<sha>` — note the double hyphen, which comes from `awk -F '[_-]'` finding no separator in the word `develop` — and that tag has never existed in any registry. Every pod lands in `ImagePullBackOff` with `not found`.

**`./create_aws_configmap.sh <ns>` is no longer a step.** `deploy_helm_to_aws_k8s.sh` has an `ensure_dev_sa_configmaps` function that writes the `sa_annotations` ConfigMaps for all twenty services before the helm apply, and its comment says it mirrors the legacy script. Running the old script by hand is redundant and covers a narrower set of names.

**`-L ./helm/.cache/helm_env_configs` is a no-op.** That is the path the script clones into by default, so passing it only tells the script to skip its own fetch and use a possibly stale checkout. Use `-L` for a real external checkout.

**The PV deletion in teardown is the part that bites.** The deploy script creates three cluster-scoped PVs — `<namespace>-ai-extraction`, `<namespace>-cron`, `<namespace>-bulk-download` — with `persistentVolumeReclaimPolicy: Retain`. Being cluster-scoped they survive even `kubectl delete namespace`, and on redeploy the script detects the stale NFS server IP and has to force-delete them through their finalizers. Removing them during teardown keeps the next deploy clean.

**Deployments scaled to zero come back.** Helm's three-way merge keeps a live `replicas=0` when the chart value has not changed, so the deploy script explicitly restores `inv-db`, `inv-redis`, `inv-efs`, `inv-immudb`, `inv-maildev`, `inv-mongodb`, `inv-rabbitmq`, and `inv-provenance-os` to one replica. Suppress per service with `DEPLOY_DEV_<NAME>_ENABLED=false`.

## Related

- `inveniam.io/helm/deploy_helm_to_aws_k8s.sh` — deploy entry point, `--help` lists every component alias.
- `inveniam.io/start_component_locally.sh` — Telepresence intercept wrapper.
- `inveniam.io/How to Dev Env practical guide.md` — the raw shell history this memo was distilled from.
