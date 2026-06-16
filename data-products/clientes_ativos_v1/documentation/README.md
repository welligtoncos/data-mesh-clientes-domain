# Data Product: clientes_ativos_v1

## Definicao

Cliente ativo = compra nos ultimos **90 dias** (parametrizavel via `dias_atividade`).

## Fontes cross-domain

| Dominio | Tabela |
|---------|--------|
| Clientes | customer |
| Pedidos | pedidos_domain.orders |

## Consulta

```sql
SELECT * FROM clientes_domain.clientes_ativos_v1
WHERE customer_state = 'SP';
```
