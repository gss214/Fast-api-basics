#!/bin/bash

CLUSTER_NAME="my-simple-cluster"
CLUSTER_CONFIG="cicd-tekton-k8s/kind/simple-cluster.yaml"

# Verifica se o arquivo de configuração do cluster existe
if [ ! -f "$CLUSTER_CONFIG" ]; then
  echo "Erro: Arquivo de configuração do cluster '$CLUSTER_CONFIG' não encontrado."
  exit 1
fi

echo "Criando o cluster Kind usando a configuração em '$CLUSTER_CONFIG'..."
kind create cluster --name $CLUSTER_NAME --config=$CLUSTER_CONFIG

# Verifica se o cluster foi criado com sucesso
if [ $? -ne 0 ]; then
  echo "Erro: Falha ao criar o cluster Kind '$CLUSTER_NAME'."
  exit 1
fi

echo "Cluster Kind '$CLUSTER_NAME' criado com sucesso."

echo "Instalando Tekton Pipelines..."
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Erro: Falha ao instalar o Tekton Pipelines."
  exit 1
fi
echo "Tekton Pipelines instalado com sucesso."

echo "Instalando Tekton Dashboard..."
kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Erro: Falha ao instalar o Tekton Dashboard."
  exit 1
fi
echo "Tekton Dashboard instalado com sucesso."

echo "Aplicando recursos do Kubernetes..."
kubectl apply -f cicd-tekton-k8s/k8s/pvc.yaml
sleep 5
kubectl apply -f cicd-tekton-k8s/k8s/copy-files-to-pvc.yaml

# Espera até que o pod 'copy-files-to-pvc' esteja pronto
echo "Aguardando o pod 'copy-files-to-pvc' ficar pronto..."
kubectl wait --for=condition=Ready pod/copy-files-to-pvc --timeout=120s

# Verifica se o pod está realmente em execução
POD_STATUS=$(kubectl get pod copy-files-to-pvc -o jsonpath='{.status.phase}')
if [[ $POD_STATUS == "Running" ]]; then
    echo "Pod 'copy-files-to-pvc' está pronto. Copiando arquivos..."
    kubectl cp requirements.txt copy-files-to-pvc:/mnt/workspace/
    kubectl cp Dockerfile copy-files-to-pvc:/mnt/workspace/
    kubectl cp app copy-files-to-pvc:/mnt/workspace/app/
    echo "Arquivos copiados com sucesso para o pod 'copy-files-to-pvc'."
else
    echo "Erro: O pod 'copy-files-to-pvc' não está em execução. Status atual: $POD_STATUS"
    kubectl logs pod/copy-files-to-pvc
    exit 1
fi

sleep 10
echo "Aplicando tasks e pipelines do Tekton..."
kubectl apply -f cicd-tekton-k8s/tekton/tasks/
sleep 1
kubectl apply -f cicd-tekton-k8s/tekton/pipelines/
sleep 1
kubectl apply -f cicd-tekton-k8s/tekton/pipelinesRuns/

echo "Aguardando execução da PipelineRun..."
kubectl wait --for=condition=Succeeded pipelinerun/fastapi-deploy-pipelinerun --timeout=300s

# Verifica o status da PipelineRun
PIPELINE_RUN_STATUS=$(kubectl get pipelinerun fastapi-deploy-pipelinerun -o jsonpath='{.status.conditions[0].status}')
if [[ $PIPELINE_RUN_STATUS == "True" ]]; then
    echo "Pipeline executada com sucesso."
else
    echo "Erro: A execução da PipelineRun falhou."
    exit 1
fi

echo "Buildando a imagem..."
docker build -t fastapi:local .

echo "Carregando a imagem no cluster Kind..."
kind load docker-image fastapi:local --name $CLUSTER_NAME
if [ $? -ne 0 ]; then
  echo "Erro: Falha ao carregar a imagem no cluster Kind."
  exit 1
fi

echo "Aplicando o deployment da aplicação..."
kubectl apply -f cicd-tekton-k8s/k8s/deployment.yaml
if [ $? -ne 0 ]; then
  echo "Erro: Falha ao aplicar o deployment."
  exit 1
fi

echo "Deployment concluído com sucesso. Verificando status dos pods..."
kubectl get pods
