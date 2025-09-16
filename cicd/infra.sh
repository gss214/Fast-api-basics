#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

CLUSTER_NAME="${CLUSTER_NAME:-my-simple-cluster}"
CLUSTER_CONFIG="${CLUSTER_CONFIG:-cicd/kind/simple-cluster.yaml}"
TEKTON_PIPELINES_VERSION="v1.0.0"
TEKTON_DASHBOARD_VERSION="v0.61.0"
ARGO_ROLLOUTS_INSTALL_URL="https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml"

YELLOW="\033[33m"; GREEN="\033[32m"; RED="\033[31m"; CYAN="\033[36m"; RESET="\033[0m"
log(){ echo -e "${CYAN}==>${RESET} $*"; }
ok(){ echo -e "${GREEN}[OK]${RESET} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${RESET} $*"; }
err(){ echo -e "${RED}[ERRO]${RESET} $*" >&2; }
die(){ err "$*"; exit 1; }

trap 'err "Falha na linha $LINENO"' ERR

checar_dep(){
  for bin in kind kubectl docker; do
    command -v "$bin" >/dev/null 2>&1 || die "Dependência '$bin' não encontrada"
  done
  ok "Dependências ok"
}


criar_cluster(){
  if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    warn "Cluster ${CLUSTER_NAME} já existe; pulando"
    return
  fi
  local config_uso="$CLUSTER_CONFIG"
  [[ -f "$config_uso" ]] || die "Config Kind não encontrada: $config_uso"
  log "Criando cluster Kind (${CLUSTER_NAME})"
  kind create cluster --name "$CLUSTER_NAME" --config "$config_uso"
  ok "Cluster criado"
}

instalar_tekton(){
  log "Instalando Tekton Pipelines (previous/${TEKTON_PIPELINES_VERSION})"
  kubectl apply -f "https://storage.googleapis.com/tekton-releases/pipeline/previous/${TEKTON_PIPELINES_VERSION}/release.yaml"
  log "Instalando Tekton Dashboard (previous/${TEKTON_DASHBOARD_VERSION})"
  kubectl apply -f "https://storage.googleapis.com/tekton-releases/dashboard/previous/${TEKTON_DASHBOARD_VERSION}/release.yaml"

  log "Esperando CRDs"
  for crd in pipelineruns.tekton.dev pipelines.tekton.dev tasks.tekton.dev; do
    kubectl wait --for=condition=Established crd/$crd --timeout=180s
  done
  log "Aguardando pods tekton-pipelines"
  timeout 240 bash -c 'while kubectl get pods -n tekton-pipelines 2>/dev/null | grep -E "0/[1-9]"; do sleep 5; done'
  ok "Tekton pronto"
}

instalar_argo_rollouts(){
  log "Verificando Argo Rollouts"
  if kubectl api-resources | grep -q "rollouts.argoproj.io"; then
    ok "Argo Rollouts já presente"
    return 0
  fi
  log "Criando namespace argo-rollouts"
  kubectl create namespace argo-rollouts || warn "Namespace argo-rollouts já existe"
  log "Instalando Argo Rollouts (controller + CRDs)"
  kubectl apply -n argo-rollouts -f "$ARGO_ROLLOUTS_INSTALL_URL"
  kubectl wait --for=condition=Available deploy/argo-rollouts -n argo-rollouts --timeout=180s || warn "Controller argo-rollouts não ficou Available a tempo"
  kubectl wait --for=condition=Established crd/rollouts.argoproj.io --timeout=120s || warn "CRD rollouts não Established a tempo"
  ok "Argo Rollouts instalado"
}

criar_pvc_e_pod(){
  log "Aplicando PVC e pod auxiliar"
  kubectl apply -f cicd/k8s/pvc.yaml
  kubectl apply -f cicd/k8s/copy-files-to-pvc.yaml
  kubectl wait --for=condition=Ready pod/copy-files-to-pvc --timeout=180s || warn "Pod não ficou Ready; prosseguindo"
  ok "PVC/pod aplicados"
}

aplicar_tasks_pipeline(){
  log "Aplicando Tasks e Pipeline"
  kubectl apply -f cicd/tekton/tasks/
  kubectl apply -f cicd/tekton/pipelines/
  ok "Pipeline base aplicada"
}

aplicar_rollout_inicial(){
  if [[ -f cicd/k8s/rollout.yaml ]]; then
    log "Aplicando rollout inicial (tag 0.1)"
    kubectl apply -f cicd/k8s/rollout.yaml
    ok "Rollout aplicado"
  else
    warn "cicd/k8s/rollout.yaml não encontrado; pulando rollout inicial"
  fi
}


main(){
  checar_dep
  criar_cluster
  instalar_tekton
  instalar_argo_rollouts
  criar_pvc_e_pod
  aplicar_tasks_pipeline
  log "Infraestrutura pronta"
  if [[ "${TRIGGER_INITIAL_DEPLOY:-true}" == "true" ]]; then
    log "Executando deploy inicial (IMAGE_TAG=0.1)"
    ./cicd/deploy.sh IMAGE_TAG=0.1 IMAGE_NAME=fastapi APPLY_DEPLOYMENT=true || warn "Deploy inicial falhou"
  else
    warn "TRIGGER_INITIAL_DEPLOY=false; não executando deploy inicial"
  fi
  aplicar_rollout_inicial
}

main "$@"
