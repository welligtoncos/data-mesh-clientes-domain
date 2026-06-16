-- DM-003: Transformacao do Data Product clientes_por_estado_v1
-- Fonte interna: customer (acesso restrito ao dominio)
-- Destino publicado: clientes_por_estado_v1

SELECT
    customer_state,
    COUNT(*) AS total_clientes,
    CURRENT_DATE AS data_referencia
FROM ${source_database}.customer
GROUP BY customer_state
ORDER BY total_clientes DESC;
