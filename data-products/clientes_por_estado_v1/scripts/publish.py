import sys

from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.functions import col, count, current_date


def main() -> None:
    args = getResolvedOptions(
        sys.argv,
        [
            "JOB_NAME",
            "SOURCE_DATABASE",
            "SOURCE_TABLE",
            "TARGET_PATH",
            "DATABASE_NAME",
            "TABLE_NAME",
        ],
    )

    sc = SparkContext()
    glue_context = GlueContext(sc)
    job = Job(glue_context)
    job.init(args["JOB_NAME"], args)

    source_frame = glue_context.create_dynamic_frame.from_catalog(
        database=args["SOURCE_DATABASE"],
        table_name=args["SOURCE_TABLE"],
    )
    source_df = source_frame.toDF()

    aggregated_df = (
        source_df.groupBy(col("customer_state"))
        .agg(count("*").alias("total_clientes"))
        .withColumn("data_referencia", current_date())
        .select("customer_state", "total_clientes", "data_referencia")
    )

    aggregated_count = aggregated_df.count()
    total_clientes = aggregated_df.agg({"total_clientes": "sum"}).collect()[0][0]

    if aggregated_count == 0:
        raise ValueError("Aggregation produced no rows.")

    # Idempotencia: remove dados anteriores antes de publicar nova versao
    glue_context.purge_s3_path(
        args["TARGET_PATH"],
        {"retentionPeriod": 0},
    )

    sink = glue_context.getSink(
        connection_type="s3",
        path=args["TARGET_PATH"],
        enableUpdateCatalog=True,
        updateBehavior="UPDATE_IN_DATABASE",
    )
    sink.setCatalogInfo(
        catalogDatabase=args["DATABASE_NAME"],
        catalogTableName=args["TABLE_NAME"],
    )
    sink.setFormat("glueparquet", compression="snappy")

    output_frame = DynamicFrame.fromDF(aggregated_df, glue_context, "clientes_por_estado_v1")
    sink.writeFrame(output_frame)

    print(f"AGGREGATED_STATES={aggregated_count}")
    print(f"TOTAL_CLIENTES={total_clientes}")
    job.commit()


if __name__ == "__main__":
    main()
