# fiap-soat-tech-challenge-infra-db

## Visão geral

Repositório responsável pelo provisionamento do banco de dados do FIAP SOAT Tech Challenge. Utiliza Terraform para criar e gerenciar uma instância **AWS RDS PostgreSQL 17** dentro da VPC provisionada pelo [`infra-k8s`](https://github.com/zmathmatos/fiap-soat-tech-challenge-infra-k8s).

O estado remoto é lido via backend S3 (mesmo bucket do `infra-k8s`), e os outputs de rede (`vpc_id`, `private_subnet_ids`, `eks_cluster_security_group_id`) são consumidos via `terraform_remote_state`.

## Dependências

> **Importante:** o repositório `infra-k8s` **deve** ser provisionado antes deste. O módulo RDS lê os outputs:
> - `vpc_id`
> - `private_subnet_ids`
> - `eks_cluster_security_group_id`

Sem a VPC e subnets privadas criadas pelo `infra-k8s`, o provisionamento falhará com `DBSubnetGroupNotAllowedFault`.

## Pré-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- [AWS CLI v2](https://aws.amazon.com/cli/) configurado com credenciais válidas
- Bucket S3 pré-criado para armazenamento do estado remoto (o mesmo do `infra-k8s`)
- State do `infra-k8s` aplicado previamente

## Setup do bucket de state

O bucket S3 é compartilhado com o `infra-k8s` e identificado pela variável `TF_STATE_BUCKET`. Se o bucket não existir (por exemplo, após reset de sessão do AWS Academy):

```bash
aws s3 mb s3://<BUCKET_NAME> --region us-east-1
```

## Setup local

```bash
# 1. Copiar o arquivo de variáveis e preencher os valores
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# preencher: rds_database_name, rds_master_username, rds_master_password

# 2. Definir o nome do bucket de state em um .env
echo 'export TF_STATE_BUCKET=<BUCKET_NAME>' > .env
source .env
```

Edite o `terraform/terraform.tfvars` com os valores desejados:

```hcl
environment         = "dev"
state_bucket        = "<BUCKET_NAME>"

rds_database_name   = "fiap_soat_db"
rds_master_username = "postgres"
rds_master_password = "sua_senha_segura"
rds_database_port   = 5432
```

> **Atenção:** o arquivo `terraform.tfvars` está no `.gitignore`. Nunca o commite no repositório.

## Provisionamento via CLI

```bash
cd terraform

source ../.env

terraform init -backend-config="bucket=$TF_STATE_BUCKET"

terraform plan
terraform apply
```

Confirme digitando `yes` quando solicitado.

## Módulo único: `modules/rds`

| Recurso | Descrição |
|---|---|
| **DB Subnet Group** | Agrupa as subnets privadas fornecidas pelo `infra-k8s` |
| **Security Group** | Porta 5432 aberta apenas para o EKS Cluster Security Group (ingress do `eks_cluster_security_group_id`) |
| **RDS Instance** | PostgreSQL 17, `db.t3.micro`, 20 GB storage (autoscale até 100 GB), criptografado, Multi-AZ desligado, backup 7 dias, deletion protection desligado |

## Variáveis Terraform

| Variável | Descrição | Padrão | Obrigatório |
|---|---|---|---|
| `project_name` | Nome do projeto | `fiap-soat` | não |
| `environment` | Ambiente de implantação (`dev`, `staging`, `production`) | `dev` | não |
| `aws_region` | Região AWS | `us-east-1` | não |
| `state_bucket` | Bucket S3 do backend (também usado para ler remote state do `infra-k8s`) | — | **sim** |
| `rds_engine_version` | Versão do PostgreSQL | `17` | não |
| `rds_instance_class` | Classe da instância RDS | `db.t3.micro` | não |
| `rds_allocated_storage` | Armazenamento inicial (GB) | `20` | não |
| `rds_max_allocated_storage` | Limite de autoscaling de storage (GB) | `100` | não |
| `rds_storage_encrypted` | Habilitar criptografia em repouso | `true` | não |
| `rds_database_name` | Nome do banco de dados inicial | — | **sim** |
| `rds_database_port` | Porta de escuta do banco (default PostgreSQL 5432) | `5432` | não |
| `rds_master_username` | Usuário administrador do RDS *(sensitive)* | — | **sim** |
| `rds_master_password` | Senha do usuário administrador *(sensitive)* | — | **sim** |
| `rds_multi_az` | Habilitar Multi-AZ | `false` | não |
| `rds_backup_retention_period` | Retenção de backups automáticos (dias) | `7` | não |
| `rds_deletion_protection` | Habilitar proteção contra deleção | `false` | não |
| `rds_skip_final_snapshot` | Pular snapshot final ao destruir | `false` | não |

## Outputs

| Output | Descrição |
|---|---|
| `rds_endpoint` | Endpoint completo do RDS (`host:porta`) |
| `rds_address` | Hostname do RDS (sem porta) |
| `rds_port` | Porta de conexão |
| `rds_database_name` | Nome do banco de dados criado |
| `rds_security_group_id` | ID do Security Group do RDS |

## GitHub Actions

### `plan.yml`

Disparado automaticamente em **Pull Requests** para `main` e manualmente via `workflow_dispatch`.

Executa: `terraform init` → `terraform validate` → `terraform plan`.

### `apply.yml`

Disparado **manualmente** via `workflow_dispatch`. Usa o GitHub Environment `production` (requer aprovação manual antes de executar).

Executa: `terraform init` → `terraform apply -auto-approve`.

### Secrets e variáveis necessários

| Nome | Tipo | Descrição |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Secret | Chave de acesso AWS (credenciais temporárias do AWS Academy) |
| `AWS_SECRET_ACCESS_KEY` | Secret | Chave secreta AWS |
| `AWS_SESSION_TOKEN` | Secret | Token de sessão AWS Academy (obrigatório — sessões temporárias) |
| `DB_USER` | Secret | Master username do RDS |
| `DB_PASSWORD` | Secret | Master password do RDS (mínimo 8 caracteres; não use `/`, `"` ou `@`) |
| `RDS_DATABASE_NAME` | Secret | Nome do banco de dados inicial criado na instância |
| `RDS_DATABASE_PORT` | Secret | Porta de escuta do banco (geralmente `5432`) |
| `TF_STATE_BUCKET` | Var | Nome do bucket S3 do backend, ex: `fiap-soat-backend-430891654117` (mesmo do `infra-k8s`) |
| `ENVIRONMENT` | Var | Ambiente alvo, ex: `dev`, `staging`, `production` |

## Como verificar recursos

```bash
# Listar instâncias RDS com status
aws rds describe-db-instances \
  --region us-east-1 \
  --query 'DBInstances[].[DBInstanceIdentifier,Endpoint.Address,DBInstanceStatus]'

# Ver outputs do Terraform
terraform output rds_endpoint

# Testar conexão (requer acesso à VPC — via bastion ou dentro do cluster)
psql -h $(terraform output -raw rds_address) -U <user> -d <db>
```

> O RDS está em subnets privadas. A conexão direta só funciona de dentro da VPC (pod no EKS, bastion host ou VPN).

## Como destruir (poupar créditos AWS Academy)

O RDS (`db.t3.micro`) custa aproximadamente **$0.40/dia** + storage. Destrua quando não estiver em uso.

> **Ordem correta de destruição:** destrua este repo **antes** do `infra-k8s` (o RDS depende da VPC). Se for destruir tudo: app → lambda → **infra-db** → infra-k8s.

```bash
cd terraform
terraform destroy -auto-approve
```

O RDS demora aproximadamente 5 minutos para ser removido. Se `rds_skip_final_snapshot = false` (padrão), um snapshot final será criado automaticamente, o que aumenta o tempo de destruição.

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| `S3 bucket does not exist` | Bucket do Academy foi resetado entre sessões | Recriar o bucket: `aws s3 mb s3://$TF_STATE_BUCKET --region us-east-1` |
| `DBSubnetGroupNotAllowedFault` | `infra-k8s` não foi provisionado; subnets privadas não existem | Provisionar o `infra-k8s` primeiro |
| `InvalidParameterValue: must contain only alphanumeric chars` | Senha do RDS contém caracteres especiais inválidos (`/`, `"`, `@`) | Trocar `DB_PASSWORD` por uma senha sem esses caracteres |
| `terraform destroy` demora mais que o esperado | `rds_skip_final_snapshot = false` — snapshot final está sendo criado | Aguardar (~10 min) |

## Estrutura do projeto

```
fiap-soat-tech-challenge-infra-db/
├── .github/
│   └── workflows/
│       ├── plan.yml        # Executa terraform plan em Pull Requests
│       └── apply.yml       # Executa terraform apply manualmente via workflow_dispatch
├── docs/
│   └── infrastructure.mmd  # Diagrama Mermaid da infraestrutura provisionada
├── terraform/
│   ├── backend.tf          # Configuração do backend S3 (partial — bucket via -backend-config)
│   ├── main.tf             # Módulo raiz — instancia o módulo RDS
│   ├── variables.tf        # Declaração das variáveis de entrada
│   ├── outputs.tf          # Outputs exportados (endpoint, porta, etc.)
│   ├── terraform.tfvars.example  # Modelo de arquivo de variáveis
│   └── modules/
│       └── rds/
│           ├── main.tf     # Recursos AWS: RDS instance, security group, subnet group
│           ├── variables.tf
│           └── outputs.tf
└── README.md
```

Clique aqui para visualizar o [diagrama da infraestrutura provisionada](https://github.com/zmathmatos/fiap-soat-tech-challenge-infra-db/blob/main/docs/infrastructure.mmd).
