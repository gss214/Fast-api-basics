
## FastAPI Basics (Pokémon themed) + Local Tekton/Kind CI

This repository contains a small FastAPI application (Pokémon themed) and a minimal local CI iteration workflow powered by:
* Kind (local Kubernetes cluster)
* Tekton Pipelines + Tekton Dashboard (version pinned for reproducibility)
* A PVC + helper pod to share source code and retrieve the built image tar

The goal is fast local feedback: change code → run `./cicd/deploy.sh` → new container image is built inside the cluster → image is loaded into Kind → Deployment updated.

---

## Table of Contents
1. Prerequisites
2. Quick Start
3. Development (run locally without Kubernetes)
4. Local CI Loop (infra + deploy)
5. Environment Variables (`deploy.sh`)
6. How the Tekton Pipeline Works
7. Accessing the App

---

## 1. Prerequisites

Install (or ensure you have):
* Docker (for Kind + optional docker load)
* kind
* kubectl
* bash / coreutils
* (Optional) Devbox – for reproducible dev environment

Check versions (optional):
```bash
docker --version
kind --version
kubectl version --client --output=yaml
```

## 2. Quick Start

Provision infrastructure (cluster + Tekton + PVC + pipeline + helper pod):
```bash
./cicd/infra.sh
```

Deploy (build image and update deployment):
```bash
./cicd/deploy.sh
```

Port-forward to test:
```bash
kubectl port-forward deployment/fastapi-deployment 5000:5000
# Then open http://localhost:5000/docs
```

Iterate (edit code) and rerun:
```bash
./cicd/deploy.sh
```

## 3. Development Without Kubernetes

Install dependencies and run with uvicorn directly:
```bash
pip install -r requirements.txt
python -m uvicorn app.main:app --reload
```
Visit: http://localhost:8000/docs (or whichever port uvicorn prints).

## 4. Local CI Loop (Two Scripts)

### `cicd/infra.sh` (idempotent)
Does one‑time or occasional setup:
* Creates Kind cluster if missing (name: `my-simple-cluster` by default)
* Installs Tekton Pipelines + Dashboard (pinned versions)
* Creates PVC `source-pvc`
* Creates helper pod `copy-files-to-pvc` (used to sync source + extract image.tar)
* Applies Tekton Task + Pipeline definitions

Re-run `./infra.sh` safely if something seems out of sync.

### `cicd/deploy.sh` (fast iteration)
Steps:
1. Copies local source (`app/`, `Dockerfile`, `requirements.txt`) into the PVC via helper pod
2. Creates a new `PipelineRun` with an image tag (default: timestamp)
3. Tekton Task builds the image (Docker-in-Docker) and saves `image.tar` in the workspace
4. Script copies `image.tar` back to host and loads it into Kind
5. Script patches the Kubernetes Deployment to use `IMAGE_NAME:IMAGE_TAG`

Result: New pods start with the fresh image.

## 5. Environment Variables (`deploy.sh`)

| Variable | Default | Purpose |
|----------|---------|---------|
| `IMAGE_NAME` | `fastapi` | Logical image name (no registry prefix) |
| `IMAGE_TAG` | current timestamp | Custom tag for reproducibility / uniqueness |
| `WORKSPACE_PVC` | `source-pvc` | PVC used as Tekton workspace |
| `CLUSTER_NAME` | `my-simple-cluster` | Kind cluster name (matches infra) |
| `LOAD_TO_KIND` | `true` | If `false`, skip loading the tar into cluster (no effect then) |
| `APPLY_DEPLOYMENT` | `true` | If `false`, skip updating the deployment image |
| `DEPLOYMENT_FILE` | `cicd/k8s/deployment.yaml` | Deployment manifest path |
| `CONTAINER_NAME` | (auto-detect) | Explicit container name inside deployment if needed |

Examples:
```bash
IMAGE_TAG=dev ./cicd/deploy.sh
IMAGE_NAME=fastapi IMAGE_TAG=feature-x ./cicd/deploy.sh
APPLY_DEPLOYMENT=false ./cicd/deploy.sh   # just build & load image
LOAD_TO_KIND=false ./cicd/deploy.sh       # skip loading into kind
```

Use a git short SHA:
```bash
IMAGE_TAG=$(git rev-parse --short HEAD) ./cicd/deploy.sh
```

## 6. How the Tekton Pipeline Works

Definitions (see `cicd/tekton/`):
* Task: `build-and-load-docker-image`
  * Image: `docker:23.0.0-dind` (Docker-in-Docker, privileged)
  * Builds: `docker build -t ${imageName}:${imageTag} .`
  * Saves: `docker save ${imageName}:${imageTag} -o image.tar`
* Pipeline: passes `imageName` + `imageTag` params to the Task
* Workspace: Mounted PVC. Inside the Task container Tekton mounts it at `/workspace/workspace/`. The `image.tar` ends up at the root of that workspace volume, which corresponds to `/mnt/workspace/image.tar` inside the helper pod.

The `cicd/deploy.sh` script copies that tar out via:
```
kubectl cp copy-files-to-pvc:/mnt/workspace/image.tar image.tar
```
Then loads into Kind:
```
kind load image-archive image.tar --name <cluster>
```

## 7. Accessing the App

Check pods:
```bash
kubectl get pods
```

Port-forward (example):
```bash
kubectl port-forward deployment/fastapi-deployment 5000:5000
```
Visit: http://localhost:5000/docs

Confirm deployment image:
```bash
kubectl get deployment fastapi-deployment -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
```

---

## Devbox (Optional)

You can still use Devbox for an isolated environment:
```bash
devbox shell
```
Then run local FastAPI or the scripts as usual.

---

## License

Educational / personal learning project. Use freely.

---

### Zero-to-Running (Quick Recap)
1. Clone repo
2. (Optional) Activate devbox or virtualenv
3. `./cicd/infra.sh`
4. `./cicd/deploy.sh`
5. `kubectl port-forward deployment/fastapi-deployment 5000:5000`
6. Open http://localhost:5000/docs
