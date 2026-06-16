import sys

from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.functions import col, current_date, datediff, lit, max as spark_max


def main() -> None:
    args = getResolvedOptions(
        sys.argv,
        [
            "JOB_NAME",
            "CUSTOMER_DATABASE",
            "CUSTOMER_TABLE",
            "ORDERS_DATABASE",
            "ORDERS_TABLE",
            "TARGET_PATH",
            "DATABASE_NAME",
            "TABLE_NAME",
            "DIAS_ATIVIDADE",
        ],
    )

    dias_atividade = int(args["DIAS_ATIVIDADE"])

    sc = SparkContext()
    glue_context = GlueContext(sc)
    job = Job(glue_context)
    job.init(args["JOB_NAME"], args)

    customer_df = glue_context.create_dynamic_frame.from_catalog(
        database=args["CUSTOMER_DATABASE"],
        table_name=args["CUSTOMER_TABLE"],
    ).toDF()

    orders_df = glue_context.create_dynamic_frame.from_catalog(
        database=args["ORDERS_DATABASE"],
        table_name=args["ORDERS_TABLE"],
    ).toDF()

    ultima_compra_df = orders_df.groupBy("customer_id").agg(
        spark_max("order_purchase_timestamp").alias("ultima_compra")
    )

    active_clients_df = (
        customer_df.join(ultima_compra_df, "customer_id", "inner")
        .withColumn("dias_desde_ultima_compra", datediff(current_date(), col("ultima_compra")))
        .withColumn("ativo", col("dias_desde_ultima_compra") <= lit(dias_atividade))
        .withColumn("data_referencia", current_date())
        .filter(col("ativo"))
        .select(
            "customer_id",
            "customer_unique_id",
            "customer_state",
            "ultima_compra",
            "dias_desde_ultima_compra",
            "ativo",
            "data_referencia",
        )
    )

    active_count = active_clients_df.count()
    if active_count == 0:
        raise ValueError("No active customers found for the configured activity window.")

    glue_context.purge_s3_path(args["TARGET_PATH"], {"retentionPeriod": 0})

    sink = glue_context.getSink(
        connection_type="s3",
        path=args["TARGET_PATH"],
        enableUpdateCatalog=True,
        updateBehavior="UPDATE_IN_DATABASE",
        partitionKeys=["customer_state"],
    )
    sink.setCatalogInfo(
        catalogDatabase=args["DATABASE_NAME"],
        catalogTableName=args["TABLE_NAME"],
    )
    sink.setFormat("glueparquet", compression="snappy")

    output_frame = DynamicFrame.fromDF(active_clients_df, glue_context, "clientes_ativos_v1")
    sink.writeFrame(output_frame)

    print(f"ACTIVE_CUSTOMERS={active_count}")
    print(f"DIAS_ATIVIDADE={dias_atividade}")
    job.commit()


if __name__ == "__main__":
    main()
