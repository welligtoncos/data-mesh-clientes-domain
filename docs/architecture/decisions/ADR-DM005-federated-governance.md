# ADR-DM005: Governanca Federada com AWS Lake Formation

## Status

Aceito

## Contexto

Apos publicacao dos Data Products `clientes_por_estado_v1` e `clientes_ativos_v1`, a plataforma precisa de governanca federada que separe ownership do dominio produtor e acesso controlado por dominio consumidor.

## Decisao

### 1. Consumidores federados por dominio de negocio

Roles IAM dedicadas:

| Role | Dominio | Permissoes |
|------|---------|------------|
| `clientes-domain-dev-admin` | Clientes (owner) | ALL via Lake Formation |
| `clientes-domain-dev-marketing-consumer` | Marketing | SELECT, DESCRIBE |
| `clientes-domain-dev-analytics-consumer` | Analytics | SELECT, DESCRIBE |
| `clientes-domain-dev-datascience-consumer` | Data Science | SELECT, DESCRIBE |
| `clientes-domain-dev-crm-consumer` | CRM | SELECT, DESCRIBE |

### 2. Mapeamento produto x consumidor

| Data Product | Consumidores |
|--------------|--------------|
| clientes_por_estado_v1 | marketing, analytics, datascience |
| clientes_ativos_v1 | marketing, crm, analytics |

### 3. Modulos Terraform

```
terraform/modules/
  iam/roles/federated_consumer/
  lakeformation/admins/
  lakeformation/permissions/consumer/
  lakeformation/data-products/
```

### 4. Politicas 100% Terraform

- Catalogo de politicas em `data-products/governance/federated-policy.json`
- Nenhuma permissao manual no console
- `create_data_lake_settings = false` (restricao da conta); grants explicitos por principal

### 5. Consumidor legado

Role `*-consumer` mantida sem grants LF nem IAM em produtos publicados quando governanca federada esta ativa.

## Consequencias

- Novos dominios consumidores adicionados via `federated_consumer` for_each
- Novos produtos mapeados em `governed_data_products` locals
- Testes DM-005 validam allow/deny por role
