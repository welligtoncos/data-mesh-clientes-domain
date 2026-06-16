# ADR-DM003: Publicacao do Data Product clientes_por_estado_v1

## Status

Aceito

## Contexto

Apos ingestao da tabela interna `customer` (DM-002), o dominio Clientes deve publicar seu primeiro Data Product oficial para consumo federado.

## Decisao

### 1. Separacao interno vs publicado

| Camada | Tabela | Acesso |
|--------|--------|--------|
| Interna | customer | ETL e admin do dominio |
| Publicada | clientes_por_estado_v1 | Consumidores autorizados |

### 2. Publicacao via Glue Job

Agregacao SQL equivalente:

```sql
SELECT customer_state, COUNT(*) AS total_clientes, CURRENT_DATE AS data_referencia
FROM customer GROUP BY customer_state
```

### 3. Governanca Lake Formation

Permissoes em nivel de tabela:
- Consumer: SELECT + DESCRIBE apenas em `clientes_por_estado_v1`
- ETL: ALL na tabela publicada, SELECT na tabela interna

### 4. IAM consumer restrito

Removido acesso do consumer a `customer/` e tabelas internas via wildcard.

### 5. SLA

Trigger `cron(0 6 * * ? *)` + alarme CloudWatch em `glue.error.ALL`.

## Consequencias

- Consumidores nao acessam dados internos do dominio
- Contrato de dados versionado em `contract/schema.json`
- Metadados publicados para descoberta federada
