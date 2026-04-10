# FIAP SOAT Tech Challenge - Infraestrutura Database

Repositório de infraestrutura de banco de dados (RDS PostgreSQL) gerenciado via Terraform.

## Dependência

Este repositório depende do **infra-k8s** estar provisionado primeiro, pois utiliza `terraform_remote_state` para obter:
- `vpc_id`
- `private_subnet_ids`
- `eks_cluster_security_group_id`

## Módulos

- **rds**: RDS PostgreSQL instance, Security Group, Subnet Group, Parameter Group

## Uso

```bash
cd terraform
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Outputs

- `rds_endpoint`: Endpoint completo do RDS
- `rds_address`: Host do RDS (usado pelo infra-k8s para configurar a aplicação)
- `rds_port`: Porta do RDS
- `rds_database_name`: Nome do banco de dados
