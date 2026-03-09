Este é o Guia Definitivo de Implementação do Toolkit Retail Media v4. Este documento foi consolidado após a validação técnica de todos os gargalos de permissões e erros de sintaxe encontrados nas versões anteriores.

📑 Documentação Oficial: Retail Media Toolkit v4
Esta arquitetura utiliza Dataform para transformação, Cloud Workflows para orquestração inteligente e Cloud Scheduler para automação diária.

🛠️ Fase 1: Infraestrutura e Base de Dados
1.1. Ativação de APIs (Terminal)
O primeiro passo é habilitar os serviços necessários para que o GCP registre os provedores de recursos.

Bash
gcloud services enable \
    bigquery.googleapis.com \
    dataform.googleapis.com \
    workflows.googleapis.com \
    workflowexecutions.googleapis.com \
    cloudscheduler.googleapis.com \
    secretmanager.googleapis.com \
    compute.googleapis.com
1.2. Criação dos Datasets (Manual - BigQuery)
Crie os datasets abaixo no BigQuery, todos na região us-east1:

analytics_123456789 (Dados do GA4)

google_ads_raw (Dados de Ads)

salesforce_raw (Dados de CRM)

silver_retail (Camada de Staging)

gold_retail (Camada de Negócio/Cubo)

1.3. Geração de Dados de Teste (SQL)
Rode o SQL no console do BigQuery para simular as origens:

SQL
CREATE OR REPLACE TABLE `analytics_123456789.events_20260308` AS
SELECT '20260308' as event_date, 'purchase' as event_name, 'user_01' as user_pseudo_id;

CREATE OR REPLACE TABLE `google_ads_raw.campaign_performance_report` AS
SELECT DATE('2026-03-08') as segments_date, 'PMax' as campaign_name, 500 as metrics_cost_micros;

CREATE OR REPLACE TABLE `salesforce_raw.Opportunity` AS
SELECT 'user_01' as ContactId, 'Closed Won' as StageName, 1000 as Amount;
🔑 Fase 2: IAM e Segurança (A Ordem Crítica)
Para evitar erros de "Service Account not found", siga exatamente esta sequência:

2.1. Despertar Identidades (Terminal)
Bash
# Força a criação da conta interna do Dataform
gcloud beta services identity create --service=dataform.googleapis.com
2.2. Configuração de Variáveis (Terminal)
Bash
PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=18412386695
USER_EMAIL=$(gcloud config get-value account)
COMPUTE_SA="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"
DATAFORM_SA="service-$PROJECT_NUMBER@gcp-sa-dataform.iam.gserviceaccount.com"
2.3. Atribuição de Permissões (Terminal)
Bash
# 1. Dataform gerencia BigQuery (Admin)
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$DATAFORM_SA" --role="roles/bigquery.admin"

# 2. Workflow (Compute SA) gerencia Dataform
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$COMPUTE_SA" --role="roles/dataform.editor"

# 3. Ajuste Fino: Workflow precisa ler BigQuery para os passos de Check
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$COMPUTE_SA" --role="roles/bigquery.jobUser"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$COMPUTE_SA" --role="roles/bigquery.dataViewer"

# 4. Permissão ActAs para seu usuário
gcloud iam service-accounts add-iam-policy-binding $COMPUTE_SA --member="user:$USER_EMAIL" --role="roles/iam.serviceAccountUser"
📂 Fase 3: Conexão GitHub e Secret Manager
3.1. Criar Segredo do GitHub (Terminal)
Substitua SEU_TOKEN pelo seu Personal Access Token do GitHub.

Bash
gcloud secrets create dataform-github-token --replication-policy="automatic"
echo -n "SEU_TOKEN" | gcloud secrets versions add dataform-github-token --data-file=-

# Permissão para o Dataform ler o Segredo
gcloud secrets add-iam-policy-binding dataform-github-token \
    --member="serviceAccount:$DATAFORM_SA" \
    --role="roles/secretmanager.secretAccessor"
3.2. Configuração do Repositório (Manual - Dataform)
Crie o repositório toolkit-retail-media em us-east1.

Conexão Git: Use a URL do seu GitHub e selecione o segredo criado acima.

Configuração de Execução (Obrigatório): Vá em Settings do repo e, em Execution Service Account, selecione 18412386695-compute@developer.gserviceaccount.com.

🎼 Fase 4: Orquestração (Cloud Workflows)
4.1. Deploy do Workflow (Terminal)
Certifique-se de estar na pasta onde o arquivo workflow/main_orchestrator.yaml está localizado.

Bash
gcloud workflows deploy retail-media-orchestrator \
    --source=workflow/main_orchestrator.yaml \
    --location=us-east1
⏰ Fase 5: Automação (Cloud Scheduler)
5.1. Criar Gatilho Diário (Terminal)
Bash
gcloud scheduler jobs create http daily-retail-sync-v4 \
    --schedule="0 6 * * *" \
    --uri="https://workflowexecutions.googleapis.com/v1/projects/$PROJECT_ID/locations/us-east1/workflows/retail-media-orchestrator/executions" \
    --message-body="{}" \
    --time-zone="America/Sao_Paulo" \
    --location="us-east1" \
    --oauth-service-account-email="18412386695-compute@developer.gserviceaccount.com"
✅ Checklist de Validação Final
Manual Dataform: Rode uma execução manual para garantir que o SQL está correto.

Workflow Test: Execute o Workflow no console para validar a integração IAM.

Scheduler Test: Use o botão "Force Run" no Scheduler e verifique se uma nova execução de Workflow foi criada.
