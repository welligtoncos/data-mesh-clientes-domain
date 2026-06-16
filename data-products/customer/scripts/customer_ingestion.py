import sys

from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.types import StringType, StructField, StructType

REQUIRED_COLUMNS = [
    "customer_id",
    "customer_unique_id",
    "customer_zip_code_prefix",
    "customer_city",
    "customer_state",
]

SCHEMA = StructType(
    [
        StructField("customer_id", StringType(), False),
        StructField("customer_unique_id", StringType(), False),
        StructField("customer_zip_code_prefix", StringType(), True),
        StructField("customer_city", StringType(), True),
        StructField("customer_state", StringType(), False),
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
    spark = glue_context.spark_session
    job = Job(glue_context)
    job.init(args["JOB_NAME"], args)

    source_df = (
        spark.read.option("header", "true")
        .option("mode", "FAILFAST")
        .schema(SCHEMA)
        .csv(args["SOURCE_PATH"])
    )

    missing_columns = [column for column in REQUIRED_COLUMNS if column not in source_df.columns]
    if missing_columns:
        raise ValueError(f"Missing required columns: {missing_columns}")

    customer_df = source_df.select(*REQUIRED_COLUMNS).dropDuplicates(["customer_id"])
    source_count = customer_df.count()

    if source_count == 0:
        raise ValueError("Source CSV contains no records.")

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

    dynamic_frame = DynamicFrame.fromDF(customer_df, glue_context, "customer_dynamic_frame")
    sink.writeFrame(dynamic_frame)

    print(f"INGESTION_ROW_COUNT={source_count}")
    job.commit()


if __name__ == "__main__":
    main()
