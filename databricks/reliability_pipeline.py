# Databricks notebook source
from functools import reduce
from pyspark.sql import functions as F

volume = "/Volumes/workspace/default/reliability_telemetry"
table = "workspace.default.reliability_events"

schema = """
    run_id STRING,
    request_number INT,
    timestamp STRING,
    http_status INT,
    app_version STRING,
    latency_ms DOUBLE,
    connection_error STRING
"""

batches = [
    spark.read.schema(schema).json(f"{volume}/{scenario}.jsonl")
    .withColumn("scenario", F.lit(scenario))
    for scenario in ("baseline", "failure", "recovery")
]

events = (
    reduce(lambda left, right: left.unionByName(right), batches)
    .withColumn("event_time", F.to_timestamp("timestamp"))
    .drop("timestamp")
    .dropDuplicates(["run_id", "request_number"])
)

events.createOrReplaceTempView("incoming_reliability_events")
events.limit(0).write.format("delta").mode("ignore").saveAsTable(table)

spark.sql(f"""
    MERGE INTO {table} AS target
    USING incoming_reliability_events AS source
    ON target.run_id = source.run_id
       AND target.request_number = source.request_number
    WHEN NOT MATCHED THEN INSERT *
""").show()

# COMMAND ----------

display(spark.sql(f"""
    SELECT
        scenario,
        COUNT(*) AS requests,
        COUNT_IF(http_status IS NULL OR http_status NOT BETWEEN 200 AND 299) AS errors,
        ROUND(
            100.0 * COUNT_IF(http_status IS NULL OR http_status NOT BETWEEN 200 AND 299)
            / COUNT(*), 2
        ) AS error_rate_pct,
        ROUND(PERCENTILE(latency_ms, 0.95), 2) AS p95_latency_ms
    FROM {table}
    GROUP BY scenario
    ORDER BY CASE scenario
        WHEN 'baseline' THEN 1
        WHEN 'failure' THEN 2
        WHEN 'recovery' THEN 3
    END
"""))