# fiap-soat-tech-challenge-infra-db

## Visão geral

Repositório de **infraestrutura centralizada** do FIAP SOAT Tech Challenge (Fase 4). Um único `terraform apply` provisiona toda a base compartilhada pelos microsserviços:

- **Rede** — VPC, subnets públicas/privadas e NAT Gateway
- **Kubernetes (EKS)** — cluster onde rodam os microsserviços, o RabbitMQ e o MongoDB
- **PostgreSQL (RDS)** — banco relacional compartilhado, com **isolamento lógico por schema**
- **RabbitMQ** — mensageria (comunicação assíncrona entre serviços) rodando no EKS
- **MongoDB** — banco não relacional rodando no EKS (usado pelo `billing-service`)
- **Bootstrap de schemas** — cria os schemas do Postgres automaticamente ao provisionar
- **Observabilidade (New Relic)** — opcional

Antes da Fase 4 a infraestrutura estava dividida em dois repositórios (`infra-k8s` e `infra-db`). Agora está **consolidada aqui**, atendendo ao requisito de centralizar a criação de k8s + DB + Rabbit + Mongo e criar os schemas ao provisionar.

## ⚠️ Decisão de arquitetura: banco único com isolamento lógico por schema

> **Este projeto NÃO provisiona um banco por microsserviço.** Todos os serviços SQL compartilham **uma única instância RDS PostgreSQL**, e cada um recebe **seu próprio schema** (`os`, `execution`). O `billing-service` usa um **database dedicado** dentro de um único MongoDB.

**Por quê?** O AWS Academy tem limite de créditos — múltiplas instâncias RDS/DocumentDB estourariam o orçamento do laboratório. Optamos por **isolamento lógico** em vez de físico:

| Nível | Como o isolamento é garantido |
|---|---|
| PostgreSQL | Um schema por serviço (`os`, `execution`), criados automaticamente no provisionamento pelo módulo `db-bootstrap` |
| MongoDB | Database `billing` exclusivo, com usuário próprio de acesso restrito (`readWrite` apenas nesse database) |
| Regra de ouro | **Nenhum serviço acessa o schema/database de outro** — toda comunicação entre serviços é via RabbitMQ ou REST |

Estamos cientes de que, em uma arquitetura de microsserviços em produção real, **cada serviço teria sua própria instância de banco dedicada** (database-per-service). A separação por schema preserva o desacoplamento lógico e permite migrar para instâncias dedicadas sem mudança de código nos serviços — apenas de connection string.

## Arquitetura provisionada

| Camada | Recurso | Detalhe |
|---|---|---|
| Rede | VPC + subnets + NAT | `10.0.0.0/16`, 2 subnets públicas e 2 privadas |
| Orquestração | EKS | Kubernetes gerenciado; node group `t3.medium` |
| Relacional (SQL) | RDS PostgreSQL 17 | `db.t3.micro`, criptografado, em subnets privadas |
| Não relacional (NoSQL) | MongoDB 7 | StatefulSet no EKS, com volume persistente |
| Mensageria | RabbitMQ 3.13 | StatefulSet no EKS, com painel de gestão |
| Observabilidade | New Relic | Opcional (`newrelic_enabled = true`) |

**Mapa de dados por microsserviço:**

| Microsserviço | Banco | Isolamento |
|---|---|---|
| `os-service` | PostgreSQL | schema `os` |
| `execution-service` | PostgreSQL | schema `execution` |
| `billing-service` | MongoDB | database `billing` |

Todos os serviços trocam eventos via RabbitMQ (vhost `fiap-soat`) — nenhum serviço acessa o banco do outro diretamente.

## Pré-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- [AWS CLI v2](https://aws.amazon.com/cli/) com credenciais válidas
- Bucket S3 pré-criado para o estado remoto do Terraform
- `kubectl` (para inspecionar o cluster após o provisionamento)

## Setup do bucket de state

O estado do Terraform é guardado em um bucket S3, identificado pela variável `TF_STATE_BUCKET`. Se o bucket não existir (por exemplo, após reset de sessão do AWS Academy):

```bash
aws s3 mb s3://<BUCKET_NAME> --region us-east-1
```

## Setup local

```bash
# 1. Copiar o arquivo de variáveis e preencher os valores
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# 2. Definir o nome do bucket de state em um .env
echo 'export TF_STATE_BUCKET=<BUCKET_NAME>' > .env
source .env
```

Edite o `terraform/terraform.tfvars` com os valores desejados (senhas do RDS, RabbitMQ e MongoDB, e — no AWS Academy — o ARN da LabRole).

> **Atenção:** `terraform.tfvars` está no `.gitignore`. Nunca o commite.

## Provisionamento via CLI

```bash
cd terraform

source ../.env

terraform init -backend-config="bucket=$TF_STATE_BUCKET"

terraform plan
terraform apply
```

Confirme digitando `yes` quando solicitado.

Após o `apply`, configure o `kubectl`:

```bash
$(terraform output -raw eks_configure_kubectl)
```

## Módulos

| Módulo | Descrição |
|---|---|
| `network` | VPC, subnets públicas/privadas, Internet Gateway, NAT Gateway e rotas |
| `eks` | Cluster EKS, node group e security group |
| `kubernetes-namespace` | Namespace da aplicação (`fiap-soat`) |
| `rds` | Instância RDS PostgreSQL, DB subnet group e security group |
| `rabbitmq` | RabbitMQ (StatefulSet + Service + Secret) no EKS |
| `mongodb` | MongoDB (StatefulSet + Service + Secret + init) no EKS |
| `db-bootstrap` | Job que cria os schemas do Postgres ao provisionar |
| `observability` | New Relic (dashboards, alertas, synthetics) — opcional |

### Como os schemas são criados ao provisionar

- **PostgreSQL:** o módulo `db-bootstrap` roda um Job dentro do cluster (portanto com acesso à rede privada onde o RDS vive). O Job aguarda o banco ficar disponível e executa `CREATE SCHEMA IF NOT EXISTS` para cada schema em `postgres_schemas` (padrão: `os`, `execution`). É idempotente — rodar de novo não quebra nada.
- **MongoDB:** o módulo `mongodb` cria o database e o usuário da aplicação (`billing`) via script de inicialização executado no primeiro boot do container.
- **RabbitMQ:** o virtual host da aplicação (`fiap-soat`) é criado automaticamente pelo próprio RabbitMQ na inicialização.

## Variáveis principais

| Variável | Descrição | Padrão |
|---|---|---|
| `environment` | Ambiente (`dev`, `staging`, `production`) | `dev` |
| `aws_region` | Região AWS | `us-east-1` |
| `kubernetes_version` | Versão do Kubernetes | `1.32` |
| `eks_cluster_role_arn` | ARN da role do cluster (AWS Academy: LabRole) | `null` |
| `eks_node_group_role_arn` | ARN da role do node group | `null` |
| `eks_access_principal_arn` | ARN do principal com acesso ao cluster | `null` |
| `rds_database_name` | Banco inicial do Postgres | `fiap_soat_db` |
| `rds_master_username` / `rds_master_password` | Credenciais do RDS *(sensitive)* | — |
| `postgres_schemas` | Schemas criados no provisionamento | `["os", "execution"]` |
| `rabbitmq_username` / `rabbitmq_password` | Credenciais do RabbitMQ | `fiap` / *(sensitive)* |
| `rabbitmq_vhost` | Virtual host da aplicação | `fiap-soat` |
| `mongodb_root_username` / `mongodb_root_password` | Credenciais root do Mongo | `root` / *(sensitive)* |
| `mongodb_database` | Database da aplicação | `billing` |
| `mongodb_app_username` / `mongodb_app_password` | Usuário da aplicação no Mongo | `billing` / *(sensitive)* |
| `newrelic_enabled` | Habilita observabilidade | `false` |

Lista completa em [`terraform/variables.tf`](terraform/variables.tf).

## Outputs

| Output | Descrição |
|---|---|
| `eks_cluster_name` | Nome do cluster EKS |
| `eks_configure_kubectl` | Comando para configurar o `kubectl` |
| `namespace` | Namespace da aplicação |
| `rds_endpoint` / `rds_address` / `rds_port` | Conexão do PostgreSQL |
| `postgres_schemas` | Schemas criados |
| `rabbitmq_service` / `rabbitmq_amqp_url` | Conexão do RabbitMQ (interna ao cluster) |
| `mongodb_service` / `mongodb_uri` | Conexão do MongoDB (interna ao cluster) |

Valores marcados como sensíveis exigem `terraform output -raw <nome>`.

## GitHub Actions

| Workflow | Gatilho | Ação |
|---|---|---|
| `plan.yml` | Pull Request para `main` + manual | `init` → `validate` → `plan` |
| `apply.yml` | Manual (`workflow_dispatch`) | `init` → `apply` (Environment `production`, requer aprovação) |
| `destroy.yml` | Manual (`workflow_dispatch`) | `init` → `destroy` |

### Secrets e variáveis necessários

| Nome | Tipo | Descrição |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Secret | Chave de acesso AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret | Chave secreta AWS |
| `AWS_SESSION_TOKEN` | Secret | Token de sessão (AWS Academy) |
| `DB_USER` / `DB_PASSWORD` | Secret | Credenciais master do RDS (senha sem `/`, `"`, `@`) |
| `RDS_DATABASE_NAME` / `RDS_DATABASE_PORT` | Secret | Banco inicial e porta |
| `RABBITMQ_PASSWORD` | Secret | Senha do RabbitMQ |
| `MONGODB_ROOT_PASSWORD` | Secret | Senha root do MongoDB |
| `MONGODB_APP_PASSWORD` | Secret | Senha do usuário da aplicação no MongoDB |
| `EKS_CLUSTER_ROLE_ARN` | Secret | ARN da role do cluster (AWS Academy: LabRole) |
| `EKS_NODE_GROUP_ROLE_ARN` | Secret | ARN da role do node group |
| `EKS_ACCESS_PRINCIPAL_ARN` | Secret | ARN do principal com acesso ao cluster |
| `TF_STATE_BUCKET` | Var | Bucket S3 do backend |
| `ENVIRONMENT` | Var | Ambiente alvo (`dev`, `staging`, `production`) |

## Como verificar os recursos

```bash
# Configurar kubectl
$(terraform output -raw eks_configure_kubectl)

# Ver os pods de RabbitMQ e MongoDB
kubectl get pods -n fiap-soat

# Confirmar que os schemas foram criados
kubectl logs job/db-bootstrap -n fiap-soat

# Ver instância RDS
aws rds describe-db-instances --region us-east-1 \
  --query 'DBInstances[].[DBInstanceIdentifier,Endpoint.Address,DBInstanceStatus]'
```

## Como destruir (poupar créditos AWS Academy)

```bash
cd terraform
terraform destroy -auto-approve
```

> O EKS e o RDS levam alguns minutos para serem removidos. Se `rds_skip_final_snapshot = false` (padrão), um snapshot final é criado, aumentando o tempo.

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| `S3 bucket does not exist` | Bucket do Academy foi resetado | Recriar: `aws s3 mb s3://$TF_STATE_BUCKET --region us-east-1` |
| `InvalidParameterValue: must contain only alphanumeric` | Senha do RDS com caracteres inválidos (`/`, `"`, `@`) | Trocar por senha sem esses caracteres |
| Job `db-bootstrap` em `Error`/`Backoff` | RDS ainda subindo ou security group bloqueando | Aguardar; conferir `kubectl logs job/db-bootstrap -n fiap-soat` |
| Pods `rabbitmq`/`mongodb` em `Pending` | Sem volume/PV disponível ou nós insuficientes | Conferir `kubectl describe pod` e a capacidade do node group |

## Estrutura do projeto

```
fiap-soat-tech-challenge-infra-db/
├── .github/
│   └── workflows/
│       ├── plan.yml
│       ├── apply.yml
│       └── destroy.yml
├── docs/
│   └── infrastructure.mmd        # Diagrama Mermaid da infraestrutura
├── terraform/
│   ├── backend.tf                # Backend S3 (bucket via -backend-config)
│   ├── providers.tf              # Providers aws, kubernetes, helm, newrelic
│   ├── main.tf                   # Módulo raiz — orquestra todos os módulos
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── network/
│       ├── eks/
│       ├── kubernetes-namespace/
│       ├── rds/
│       ├── rabbitmq/
│       ├── mongodb/
│       ├── db-bootstrap/
│       └── observability/
└── README.md
```
