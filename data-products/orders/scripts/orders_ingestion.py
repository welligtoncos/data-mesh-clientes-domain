import sys

from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.types import StringType, StructField, StructType, TimestampType

REQUIRED_COLUMNS = [
    "order_id",
    "customer_id",
    "order_status",
    "order_purchase_timestamp",
]

SCHEMA = StructType(
    [
        StructField("order_id", StringType(), False),
        StructField("customer_id", StringType(), False),
        StructField("order_status", StringType(), True),
        StructField("order_purchase_timestamp", TimestampType(), True),
        StructField("order_approved_at", TimestampType(), True),
        StructField("order_delivered_carrier_date", TimestampType(), True),
        StructField("order_delivered_customer_date", TimestampType(), True),
        StructField("order_estimated_delivery_date", TimestampType(), True),
    ]
)


def main() -> None:
    args = getResolvedOptions(
        sys.argv,
        [
            "JOB_NAME",
            "SOURCE_PATH",
            "TARGET_PATH",
            "DATABASE_NAME",
            "TABLE_NAME",
        ],
    )

    sc = SparkContext()
    glue_context = GlueContext(sc)
    job = Job(glue_context)
    job.init(args["JOB_NAME"], args)

    source_df = (
        glue_context.spark_session.read.option("header", "true")
        .option("mode", "FAILFAST")
        .schema(SCHEMA)
        .csv(args["SOURCE_PATH"])
    )

    missing_columns = [column for column in REQUIRED_COLUMNS if column not in source_df.columns]
    if missing_columns:
        raise ValueError(f"Missing required columns: {missing_columns}")

    orders_df = source_df.select(*source_df.columns).dropDuplicates(["order_id"])
    source_count = orders_df.count()
    if source_count == 0:
        raise ValueError("Source CSV contains no records.")

    glue_context.purge_s3_path(args["TARGET_PATH"], {"retentionPeriod": 0})

    sink = glue_context.getSink(
        connection_type="s3",
        path=args["TARGET_PATH"],
        enableUpdateCatalog=True,
        updateBehavior="UPDATE_IN_DATABASE",
        partitionKeys=["order_status"],
    )
    sink.setCatalogInfo(
        catalogDatabase=args["DATABASE_NAME"],
        catalogTableName=args["TABLE_NAME"],
    )
    sink.setFormat("glueparquet", compression="snappy")

    dynamic_frame = DynamicFrame.fromDF(orders_df, glue_context, "orders_dynamic_frame")
    sink.writeFrame(dynamic_frame)

    print(f"INGESTION_ROW_COUNT={source_count}")
    job.commit()


if __name__ == "__main__":
    main()
