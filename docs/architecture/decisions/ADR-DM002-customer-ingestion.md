# ADR-DM002: Ingestao do Data Product customer

## Status

Aceito

## Contexto

O dominio Clientes precisa ingerir o arquivo `customers.csv` do dataset Olist como fonte oficial para futuros Data Products (`clientes_por_estado_v1`, etc.).

A DM-001 ja provisionou bucket, catalogo Glue, IAM e Lake Formation.

## Decisao

### 1. Zonas de dados no bucket

| Zona | Prefixo S3 | Proposito |
|------|------------|-----------|
| Raw | `internal/raw/customers/` | CSV fonte (landing) |
| Curated | `customer/` | Data Product em Parquet |
| Scripts | `internal/glue-scripts/` | Scripts Glue versionados |

**Justificativa:** Separa dados internos (raw) de Data Products publicaveis (`customer/`), alinhado ao principio de dados como produto.

### 2. Glue Job como motor de ingestao

- Runtime Glue 4.0 (PySpark 3.3)
- Leitura CSV com schema explicito (5 colunas)
- Escrita via `getSink` com `enableUpdateCatalog=true`
- Formato `glueparquet` com compressao Snappy
- Particionamento por `customer_state`

**Justificativa:** O Job garante transformacao controlada, registro no catalogo e particionamento otimo para consultas Athena por estado.

### 3. Glue Crawler como reconciliacao

O Crawler executa apos o Job para:

- Descobrir novas particoes
- Validar schema no catalogo
- Atender criterio de aceite de catalogacao

**Justificativa:** Crawler complementa o Job em cenarios de reprocessamento e novas particoes.

### 4. IAM segregado

| Role | Uso |
|------|-----|
| `clientes-domain-dev-etl` | Glue Job |
| `clientes-domain-dev-crawler` | Glue Crawler |
| `clientes-domain-dev-consumer` | Leitura do Data Product |

### 5. Execucao do pipeline

Por padrao `run_customer_ingestion_on_apply = false` para evitar execucoes longas em todo `terraform apply`. Testes e CI usam `-RunIngestion` explicitamente.

### 6. Athena Workgroup

Workgroup dedicado `clientes-domain-dev` com resultados em `internal/athena-results/`.

## Consequencias

- Positivas: pipeline reproduzivel, testavel, modular para outros dominios
- Negativas: primeira execucao do Job requer trigger manual ou flag explicita
- Lake Formation: permissoes de tabela criadas em runtime; bucket ja registrado na DM-001

## Alternativas consideradas

1. **Apenas Crawler no CSV** - Rejeitado: nao converte para Parquet nem aplica particionamento
2. **Lambda para conversao** - Rejeitado: dataset pode crescer; Glue escala melhor
3. **Bronze/Silver/Gold centralizado** - Rejeitado: contrario aos principios Data Mesh
