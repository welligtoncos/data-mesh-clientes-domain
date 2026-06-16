# Data Product: clientes_ativos_v1

Behavioral Data Product com clientes que compraram nos ultimos 90 dias.

```mermaid
flowchart LR
    Customer["clientes_domain.customer"] --> Job["Glue Job publish"]
    Orders["pedidos_domain.orders"] --> Job
    Job --> S3["data-products/clientes_ativos_v1/data/"]
    Job --> Catalog["Glue Catalog"]
    Catalog --> LF["Lake Formation"]
    Catalog --> Athena["Athena"]
```

## Contrato

| Campo | Tipo |
|-------|------|
| customer_id | string |
| customer_unique_id | string |
| customer_state | string |
| ultima_compra | timestamp |
| dias_desde_ultima_compra | int |
| ativo | boolean |
| data_referencia | date |

Particionamento: `customer_state`
