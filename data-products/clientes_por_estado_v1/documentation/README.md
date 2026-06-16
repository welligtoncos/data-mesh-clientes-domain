# Data Product: clientes_por_estado_v1

## Visao Geral

Produto analitico que consolida a quantidade de clientes por estado brasileiro.

| Atributo | Valor |
|----------|-------|
| Dominio | Clientes |
| Owner | Time Clientes |
| Versao | v1 |
| SLA | Diario ate 06:00 UTC |
| Formato | Parquet (Snappy) |

## Casos de Uso

- Campanhas regionais (Marketing)
- Dashboards executivos (Analytics)
- Receita por estado (Financeiro)

## Consulta Athena

```sql
SELECT customer_state, total_clientes, data_referencia
FROM clientes_domain.clientes_por_estado_v1
ORDER BY total_clientes DESC;
```

## Governanca

Consumidores externos acessam **apenas** esta tabela via Lake Formation.
Tabelas internas (`customer`) nao sao expostas a consumidores.
