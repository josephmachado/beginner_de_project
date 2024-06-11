import pprint

from pyspark.sql import SparkSession


def run_code(spark):
    print("============================================")
    print("PRINT SPARKSESSION RESOURCE CONFIGS")
    print("============================================")
    # Get the SparkConf object
    conf = spark.sparkContext.getConf()

    # Print the resource configurations
    print("Resource Configurations:")
    pp = pprint.PrettyPrinter(indent=4)
    pp.pprint(dict(conf.getAll()))


if __name__ == "__main__":
    spark = (
        SparkSession.builder.appName("efficient-data-processing-spark")
        .config(
            "spark.jars.packages",
            "io.delta:delta-core_2.12:2.3.0,org.apache.hadoop:hadoop-aws:3.3.2,org.postgresql:postgresql:42.7.3",
        )
        .config("spark.hadoop.fs.s3a.access.key", "minio")
        .config("spark.hadoop.fs.s3a.secret.key", "minio123")
        .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000")
        .config("spark.hadoop.fs.s3a.region", "us-east-1")
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .getOrCreate()
    )
    run_code(spark=spark)
    spark.stop()
