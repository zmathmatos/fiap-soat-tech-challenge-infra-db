# fiap-soat-tech-challenge-infra-db

Repositório responsável pelo provisionamento da infraestrutura de banco de dados do FIAP SOAT Tech Challenge. Utiliza Terraform para criar e gerenciar uma instância **AWS RDS PostgreSQL** em uma VPC compartilhada com o cluster EKS do projeto.

## Pré-requisitos

> **Atenção:** a infraestrutura base do repositório [fiap-soat-tech-challenge-infra-k8s](https://github.com/zmathmatos/fiap-soat-tech-challenge-infra-k8s) deve ser provisionada previamente.

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0.
- [AWS CLI](https://aws.amazon.com/cli/) configurado com credenciais válidas.
- Acesso ao bucket S3 `fiap-soat-backend-bucket` (armazenamento do estado remoto).
- State do repositório `infra-k8s` aplicado previamente (o RDS depende da VPC e subnets provisionadas por ele).

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
│   ├── backend.tf          # Configuração do backend S3 para estado remoto
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

## Setup local

### 1. Autenticar na AWS

> **Atenção:** antes de rodar o comando a seguir configurar as credenciais necessárias para a AWS CLI. Normal ficam no arquivo `credentials` do diretório `.aws/`.

```bash
aws configure
```

### 2. Criar o arquivo de variáveis

Copie o arquivo de exemplo e preencha com os valores desejados:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edite o arquivo `terraform/terraform.tfvars`:

```hcl
environment         = "dev"

rds_database_name   = "fiap_soat_db"
rds_master_username = "postgres"
rds_master_password = "sua_senha_segura"
rds_database_port   = 5432
```

> **Atenção:** o arquivo `terraform.tfvars` está no `.gitignore` para evitar o vazamento de credenciais. Nunca o commite no repositório.

### 3. Inicializar o Terraform

Dentro do diretório `terraform/`, execute:

```bash
cd terraform
terraform init
```

Este comando baixa os providers necessários e configura o backend S3 para armazenamento do estado remoto.

## Provisionamento

### Validar o código terraform

Antes de aplicar qualquer mudança, valide se o código está correto:

```bash
terraform validate
```

### Visualizar o plano de execução

Antes de aplicar qualquer mudança, gere o plano para revisar os recursos que serão criados ou alterados:

```bash
terraform plan
```

### Aplicar a infraestrutura

```bash
terraform apply
```

Confirme digitando `yes` quando solicitado. O Terraform irá criar:

- **DB Subnet Group** — agrupa as subnets privadas da VPC para o RDS
- **Security Group** — restringe o acesso à porta PostgreSQL apenas ao security group do cluster EKS
- **RDS Instance** — instância PostgreSQL com as configurações definidas nas variáveis

Ao final, os outputs exibirão as informações de conexão:

```
rds_address          = "xxxx.xxxx.us-east-1.rds.amazonaws.com"
rds_endpoint         = "xxxx.xxxx.us-east-1.rds.amazonaws.com:5432"
rds_port             = 5432
rds_database_name    = "fiap_soat_db"
rds_security_group_id = "sg-xxxxxxxxxxxxxxxxx"
```

### Destruir a infraestrutura

```bash
terraform destroy
```

## Variáveis disponíveis

| Variável | Descrição | Padrão |
|---|---|---|
| `project_name` | Nome do projeto | `fiap-soat` |
| `environment` | Ambiente de implantação | `dev` |
| `aws_region` | Região AWS | `us-east-1` |
| `rds_engine_version` | Versão do PostgreSQL | `17` |
| `rds_instance_class` | Classe da instância RDS | `db.t3.micro` |
| `rds_allocated_storage` | Armazenamento inicial (GB) | `20` |
| `rds_max_allocated_storage` | Limite de autoscaling de storage (GB) | `100` |
| `rds_storage_encrypted` | Habilitar criptografia em repouso | `true` |
| `rds_database_name` | Nome do banco de dados | obrigatório |
| `rds_database_port` | Porta do banco de dados | `5432` |
| `rds_master_username` | Usuário administrador | obrigatório |
| `rds_master_password` | Senha do usuário administrador | obrigatório |
| `rds_multi_az` | Habilitar Multi-AZ | `false` |
| `rds_backup_retention_period` | Retenção de backups automáticos (dias) | `7` |
| `rds_deletion_protection` | Habilitar proteção contra deleção | `false` |
| `rds_skip_final_snapshot` | Pular snapshot final ao destruir | `false` |

## CI/CD

O repositório possui dois workflows no GitHub Actions:

- **`plan.yml`** — disparado automaticamente em Pull Requests para `main`. Executa `terraform init`, `terraform validate` e `terraform plan`, permitindo revisar as mudanças antes do merge.
- **`apply.yml`** — disparado manualmente via `workflow_dispatch`. Executa `terraform apply -auto-approve` após aprovação do ambiente de produção no GitHub.

> **Atenção:** o workflow de CD (`apply.yml`) está configurado com disparo manual devido ao projeto utilizar o AWS Academy, que possui recursos limitados.

As credenciais AWS e os valores sensíveis das variáveis são injetados via GitHub Secrets e Variables, sem necessidade do arquivo `terraform.tfvars` no ambiente de CI.
