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
ROLLOUT_FILE="${ROLLOUT_FILE:-cicd/k8s/rollout.yaml}"
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
  if [[ "${LOAD_TO_KIND}" == "true" ]]; then
    command -v kind >/dev/null 2>&1 || die "Dependência 'kind' ausente para LOAD_TO_KIND=true"
  fi
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

atualizar_deployment_ou_rollout(){
  [[ "$APPLY_DEPLOYMENT" == "true" ]] || { warn "APPLY_DEPLOYMENT=false; pulando atualização"; return; }
  local full_ref="${IMAGE_NAME}:${IMAGE_TAG}"
  local target_container="$CONTAINER_NAME"
  local ns_flag=""
  if [[ -n "${NAMESPACE:-}" ]]; then
    ns_flag="-n $NAMESPACE"
  fi
  # Preferir rollout se recurso existir
  if kubectl get rollout fastapi-rollout $ns_flag >/dev/null 2>&1; then
    if [ -z "$target_container" ]; then
      target_container=$(kubectl get rollout fastapi-rollout $ns_flag -o jsonpath='{.spec.template.spec.containers[0].name}' 2>/dev/null || echo "fastapi")
    fi
    log "Atualizando Rollout fastapi-rollout container '$target_container' para $full_ref"
    if command -v kubectl-argo-rollouts >/dev/null 2>&1; then
      kubectl argo rollouts set image fastapi-rollout "${target_container}=${full_ref}" $ns_flag || die "Falha set image via plugin"
    else
      # Fallback patch strategy spec.template
      kubectl $ns_flag patch rollout fastapi-rollout \
        --type='merge' \
        -p "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"$target_container\",\"image\":\"$full_ref\"}]}}}}" || die "Falha patch rollout"
    fi
    log "Aguardando steps do canary (Rollout)"
    kubectl argo rollouts get rollout fastapi-rollout $ns_flag 2>/dev/null || true
    # Espera até alcançar 100% (Weight 100) ou timeout
    local deadline=$(( $(date +%s) + 600 ))
    while true; do
      local phase
      phase=$(kubectl get rollout fastapi-rollout $ns_flag -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
      if [[ "$phase" == "Healthy" ]]; then
        ok "Rollout Healthy"
        break
      fi
      if (( $(date +%s) > deadline )); then
        warn "Timeout aguardando Rollout Healthy"
        break
      fi
      sleep 5
    done
    return 0
  fi
  # Caso não haja rollout, usar deployment padrão
  [[ -f "$DEPLOYMENT_FILE" ]] || die "Deployment file não encontrado: $DEPLOYMENT_FILE"
  log "Aplicando Deployment ($DEPLOYMENT_FILE)"
  kubectl apply -f "$DEPLOYMENT_FILE"
  if [ -z "$target_container" ]; then
    target_container=$(kubectl get deployment fastapi-deployment -o jsonpath='{.spec.template.spec.containers[0].name}' 2>/dev/null || echo "fastapi")
  fi
  log "Atualizando imagem do Deployment container '$target_container' para $full_ref"
  kubectl set image deployment/fastapi-deployment "${target_container}=${full_ref}" --record || warn "Falha set image deployment"
  kubectl rollout status deployment/fastapi-deployment --timeout=180s || warn "Rollout deployment não confirmou"
  ok "Deployment atualizado"
}

main(){
  checar_dep
  copiar_codigo_para_pvc
  criar_pipelinerun
  aguardar_pipelinerun
  extrair_imagem_do_pvc
  atualizar_deployment_ou_rollout
  log "Deploy concluído (imagem ${IMAGE_NAME}:${IMAGE_TAG})"
}

main "$@"
