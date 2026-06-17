# ADR-DM006: Exposicao de Data Products via API REST

## Status

Aceito

## Contexto

Data Products publicados e governados (DM-003 a DM-005) precisam ser consumidos por aplicacoes sem SQL ou acesso direto ao data lake.

## Decisao

### 1. Arquitetura

```
Consumer -> API Gateway (v1) -> Lambda -> Athena -> Glue Catalog -> Data Product
```

### 2. Consulta via Athena

Lambdas nao acessam S3 de dados diretamente; apenas resultados Athena em `internal/athena-results/`.

### 3. Seguranca

- HTTPS (API Gateway regional)
- API Key + Usage Plan
- Role Lambda dedicada com LF SELECT nos produtos publicados
- IAM de menor privilegio (Athena workgroup, tabelas especificas)

### 4. Endpoints v1

| Metodo | Path | Data Product |
|--------|------|--------------|
| GET | /clientes/por-estado | clientes_por_estado_v1 |
| GET | /clientes/ativos | clientes_ativos_v1 |
| GET | /clientes/ativos?estado=UF | clientes_ativos_v1 filtrado |

### 5. Modulos Terraform

- `lambda_function` - empacotamento zip + CloudWatch
- `api_gateway` - REST API, stage, API Key
- `data_products_api.tf` - composicao no ambiente dev

## Consequencias

- Consumidores HTTP nao precisam de Athena/SQL
- Latencia depende do cold start + tempo Athena (meta < 5s em warm)
- Novos endpoints exigem nova Lambda + rota Terraform
