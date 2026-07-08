# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze: Ingest Online Retail II
# MAGIC Reads raw .xlsx from UC Volume, lands as-is (minimal transformation) into a Bronze Delta table.
# MAGIC Exam domain: Configure Environments (volume access) + Prepare & Process Data (ingestion)

# COMMAND ----------

import pandas as pd
from pyspark.sql import functions as F

CATALOG = "retail_lakehouse"
BRONZE_SCHEMA = "bronze"
VOLUME_PATH = f"/Volumes/{CATALOG}/{BRONZE_SCHEMA}/raw_files/online_retail_II.xlsx"

# COMMAND ----------

# MAGIC %md
# MAGIC ## Read both sheets via pandas, tag with source sheet name
# MAGIC Volumes are accessible as normal file paths - no extra mount/config needed.

# COMMAND ----------

sheet_names = ["Year 2009-2010", "Year 2010-2011"]
pdfs = []

for sheet in sheet_names:
    pdf = pd.read_excel(VOLUME_PATH, sheet_name=sheet)
    pdf["source_sheet"] = sheet
    pdfs.append(pdf)

raw_pdf = pd.concat(pdfs, ignore_index=True)
print(f"Rows loaded: {len(raw_pdf)}")
raw_pdf.head()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Convert to Spark, add ingestion metadata (bronze convention: keep raw, add lineage columns only)

# COMMAND ----------

# Normalize column names to snake_case (avoid special chars in Delta)
raw_pdf.columns = [c.strip().lower().replace(" ", "_") for c in raw_pdf.columns]

bronze_df = spark.createDataFrame(raw_pdf)

bronze_df = (
    bronze_df
    .withColumn("_ingested_at", F.current_timestamp())
    .withColumn("_source_file", F.lit("online_retail_II.xlsx"))
)

display(bronze_df.limit(10))

# COMMAND ----------

# MAGIC %md
# MAGIC ## Write to Bronze Delta table (managed, in our catalog/schema)

# COMMAND ----------

target_table = f"{CATALOG}.{BRONZE_SCHEMA}.orders_raw"

(
    bronze_df.write
    .format("delta")
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .saveAsTable(target_table)
)

print(f"Written to {target_table}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Quick validation

# COMMAND ----------

result = spark.sql(f"SELECT count(*) as row_count FROM {target_table}")
display(result)

spark.sql(f"DESCRIBE TABLE {target_table}").show(truncate=False)