# ADR-DM004: Publicacao do Data Product clientes_ativos_v1

## Status

Aceito

## Contexto

Apos DM-003 (`clientes_por_estado_v1`), o dominio Clientes deve publicar um produto comportamental que identifica clientes ativos com base em compras recentes, consumindo dados do dominio Pedidos via contrato cross-domain.

## Decisao

### 1. Definicao de cliente ativo

Cliente ativo = pelo menos uma compra nos ultimos N dias (padrao `dias_atividade = 90`), parametrizavel via `--DIAS_ATIVIDADE` no Glue Job.

### 2. Fontes e isolamento

| Camada | Tabela | Acesso consumidor |
|--------|--------|-------------------|
| Interna Clientes | customer | Negado |
| Cross-domain Pedidos | pedidos_domain.orders | Negado (apenas ETL) |
| Publicada | clientes_ativos_v1 | Permitido |

### 3. Ingestao orders no dominio Clientes

Orders ingerido em `internal/cross-domain/pedidos/orders/` com database Glue `pedidos_domain`, demonstrando consumo federado sem expor tabelas internas de Pedidos aos consumidores finais.

### 4. Publicacao

Glue Job com join customer + orders, filtro de atividade, Parquet particionado por `customer_state`, purge S3 antes de re-publicar.

### 5. Governanca

Lake Formation em nivel de tabela para `clientes_ativos_v1`; consumer IAM restrito aos Data Products publicados.

### 6. SLA

Trigger `cron(0 6 * * ? *)` alinhado aos demais produtos do dominio.

## Consequencias

- Marketing, CRM e Analytics consultam apenas `clientes_ativos_v1`
- Regra de atividade centralizada e versionavel
- Dependencia operacional da ingestao de orders antes da publicacao
