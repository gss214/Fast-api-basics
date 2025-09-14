#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Configs
IMAGE_NAME="${IMAGE_NAME:-fastapi}"
IMAGE_TAG="${IMAGE_TAG:-$(date +%Y%m%d%H%M%S)}"
PIPELINERUN_NAME="fastapi-deploy-$(date +%Y%m%d%H%M%S)"
WORKSPACE_PVC="${WORKSPACE_PVC:-source-pvc}"
CLUSTER_NAME="${CLUSTER_NAME:-my-simple-cluster}"
LOAD_TO_KIND="${LOAD_TO_KIND:-true}"
APPLY_DEPLOYMENT="${APPLY_DEPLOYMENT:-true}"
DEPLOYMENT_FILE="${DEPLOYMENT_FILE:-cicd/k8s/deployment.yaml}"
CONTAINER_NAME="${CONTAINER_NAME:-}"

YELLOW="\033[33m"; GREEN="\033[32m"; RED="\033[31m"; CYAN="\033[36m"; RESET="\033[0m"
log(){ echo -e "${CYAN}==>${RESET} $*"; }
ok(){ echo -e "${GREEN}[OK]${RESET} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${RESET} $*"; }
err(){ echo -e "${RED}[ERRO]${RESET} $*" >&2; }
die(){ err "$*"; exit 1; }

trap 'err "Falha na linha $LINENO"; coletar_logs || true' ERR

coletar_logs(){
  warn "Diagnóstico PipelineRun ${PIPELINERUN_NAME}";
  kubectl get pipelinerun "$PIPELINERUN_NAME" -o yaml 2>/dev/null || true
  kubectl describe pipelinerun "$PIPELINERUN_NAME" 2>/dev/null || true
}

checar_dep(){
  for bin in kubectl; do
    command -v "$bin" >/dev/null 2>&1 || die "Dependência '$bin' ausente"
  done
}

copiar_codigo_para_pvc(){
  if ! kubectl get pod copy-files-to-pvc >/dev/null 2>&1; then
    die "Pod copy-files-to-pvc não encontrado. Execute ./infra.sh primeiro."
  fi
  log "Atualizando código no PVC"
  kubectl exec copy-files-to-pvc -- rm -rf /mnt/workspace/app || true
  kubectl exec copy-files-to-pvc -- mkdir -p /mnt/workspace/app
  kubectl cp requirements.txt copy-files-to-pvc:/mnt/workspace/
  kubectl cp Dockerfile copy-files-to-pvc:/mnt/workspace/
  kubectl cp app/. copy-files-to-pvc:/mnt/workspace/app/
  ok "Código sincronizado"
}

gerar_pipelinerun_manifest(){
  cat <<YAML
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: ${PIPELINERUN_NAME}
spec:
  pipelineRef:
    name: fastapi-deploy-pipeline
  params:
    - name: imageName
      value: ${IMAGE_NAME}
    - name: imageTag
      value: ${IMAGE_TAG}
  workspaces:
    - name: workspace
      persistentVolumeClaim:
        claimName: ${WORKSPACE_PVC}
YAML
}

criar_pipelinerun(){
  local ref_display="${IMAGE_NAME}:${IMAGE_TAG}"
  log "Criando PipelineRun ${PIPELINERUN_NAME} (Imagem: ${ref_display})"
  gerar_pipelinerun_manifest | kubectl apply -f -
  ok "PipelineRun criada"
}

aguardar_pipelinerun(){
  log "Aguardando PipelineRun completar"
  local deadline=$(( $(date +%s) + 900 ))
  while true; do
    local status
    status=$(kubectl get pipelinerun "${PIPELINERUN_NAME}" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null || echo "")
    if [[ "$status" == "True" ]]; then
      ok "PipelineRun Succeeded"
      return 0
    fi
    if [[ "$status" == "False" ]]; then
      die "PipelineRun falhou"
    fi
    if (( $(date +%s) > deadline )); then
      die "Timeout aguardando PipelineRun"
    fi
    sleep 5
  done
}

extrair_imagem_do_pvc(){
  [[ "$LOAD_TO_KIND" == "true" ]] || { warn "LOAD_TO_KIND=false; pulando load"; return; }
  command -v kind >/dev/null 2>&1 || die "kind não encontrado para carregar imagem"
  log "Extraindo image.tar do PVC para host"
 kubectl exec copy-files-to-pvc -- ls -l /mnt/workspace || true
  if ! kubectl cp copy-files-to-pvc:/mnt/workspace/image.tar image.tar 2>/dev/null; then
    err "Falha ao copiar image.tar do PVC (caminho esperado: /mnt/workspace/image.tar)"
    kubectl exec copy-files-to-pvc -- find /mnt/workspace -maxdepth 2 -type f -name 'image.tar' || true
    die "image.tar não encontrado no PVC"
  fi
  [[ -f image.tar ]] || die "image.tar não encontrado no host após kubectl cp"
  log "Carregando imagem no Docker local (docker load)"
  docker load -i image.tar >/dev/null 2>&1 || warn "Falha docker load (talvez daemon ausente?)"
  log "Carregando imagem no Kind"
  kind load image-archive image.tar --name "$CLUSTER_NAME"
  ok "Imagem carregada no Kind"
}

atualizar_deployment(){
  [[ "$APPLY_DEPLOYMENT" == "true" ]] || { warn "APPLY_DEPLOYMENT=false; pulando deployment"; return; }
  [[ -f "$DEPLOYMENT_FILE" ]] || die "Deployment file não encontrado: $DEPLOYMENT_FILE"
  local full_ref="${IMAGE_NAME}:${IMAGE_TAG}"
  log "Atualizando deployment com nova imagem $full_ref"
  kubectl apply -f "$DEPLOYMENT_FILE"
  local target_container="$CONTAINER_NAME"
  if [ -z "$target_container" ]; then
    target_container=$(kubectl get deployment fastapi-deployment -o jsonpath='{.spec.template.spec.containers[0].name}' 2>/dev/null || echo "")
    if [ -z "$target_container" ]; then
      warn "Não foi possível detectar nome do container; usando 'fastapi' como fallback"
      target_container="fastapi"
    fi
  fi
  log "Atualizando imagem do container '$target_container' para $full_ref"
  if ! kubectl set image deployment/fastapi-deployment "${target_container}=${full_ref}" --record; then
    warn "Falha ao atualizar imagem (container $target_container). Verifique nome do container e deployment"
  fi
  kubectl rollout status deployment/fastapi-deployment --timeout=180s || warn "Rollout não confirmou em 180s"
  ok "Deployment atualizado"
}

main(){
  checar_dep
  copiar_codigo_para_pvc
  criar_pipelinerun
  aguardar_pipelinerun
  extrair_imagem_do_pvc
  atualizar_deployment
  log "Deploy concluído (imagem ${IMAGE_NAME}:${IMAGE_TAG})"
}

main "$@"
