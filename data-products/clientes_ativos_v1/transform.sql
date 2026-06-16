-- DM-004: clientes_ativos_v1
-- Fontes: clientes_domain.customer + pedidos_domain.orders

WITH ultima_compra AS (
    SELECT
        customer_id,
        MAX(order_purchase_timestamp) AS ultima_compra
    FROM pedidos_domain.orders
    GROUP BY customer_id
)
SELECT
    c.customer_id,
    c.customer_unique_id,
    c.customer_state,
    u.ultima_compra,
    DATE_DIFF('day', CAST(u.ultima_compra AS date), CURRENT_DATE) AS dias_desde_ultima_compra,
    TRUE AS ativo,
    CURRENT_DATE AS data_referencia
FROM clientes_domain.customer c
INNER JOIN ultima_compra u ON c.customer_id = u.customer_id
WHERE DATE_DIFF('day', CAST(u.ultima_compra AS date), CURRENT_DATE) <= 90;
