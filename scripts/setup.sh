#!/bin/bash

# Configurações Iniciais
PROJECT_ID=$(gcloud config get-value project)
LOCATION="us-east1"
WORKFLOW_NAME="retail-media-orchestrator"

echo "🚀 Iniciando o setup do Toolkit Retail Media no projeto: $PROJECT_ID"

# 1. Habilitar APIs Necessárias
echo "🔧 Habilitando APIs (BigQuery, Dataform, Workflows)..."
gcloud services enable \
    bigquery.googleapis.com \
    dataform.googleapis.com \
    workflows.googleapis.com \
    workflowexecutions.googleapis.com

# 2. Criar Datasets de Destino (Silver e Gold)
echo "📂 Criando Datasets Silver e Gold..."
bq --location=$LOCATION mk -d --if_exists silver_retail
bq --location=$LOCATION mk -d --if_exists gold_retail

# 3. Deploy do Cloud Workflow
echo "🤖 Fazendo deploy do Orquestrador (Cloud Workflows)..."
gcloud workflows deploy $WORKFLOW_NAME \
    --source=workflow/main_orchestrator.yaml \
    --location=$LOCATION

echo "✅ Setup concluído com sucesso!"