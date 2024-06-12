# pyspark
import argparse

from pyspark.ml.feature import StopWordsRemover, Tokenizer
from pyspark.sql import SparkSession
from pyspark.sql.functions import array_contains, lit


def random_text_classifier(input_loc: str, output_loc: str, run_id: str) -> None:
    """
    This is a dummy function to show how to use spark, It is supposed to mock
    the following steps
        1. clean input data
        2. use a pre-trained model to make prediction
        3. write predictions to a HDFS output

    Since this is meant as an example, we are going to skip building a model,
    instead we are naively going to mark reviews having the text "good" as
    positive and the rest as negative
    """

    # read input
    df_raw = spark.read.option("header", True).csv(input_loc)
    # perform text cleaning

    # Tokenize text
    tokenizer = Tokenizer(inputCol="review_str", outputCol="review_token")
    df_tokens = tokenizer.transform(df_raw).select("cid", "review_token")

    # Remove stop words
    remover = StopWordsRemover(inputCol="review_token", outputCol="review_clean")
    df_clean = remover.transform(df_tokens).select("cid", "review_clean")

    # function to check presence of good
    df_out = df_clean.select(
        "cid",
        array_contains(df_clean.review_clean, "good").alias("positive_review"),
    )
    df_fin = df_out.withColumn("insert_date", lit(run_id))
    # parquet is a popular column storage format, we use it here
    df_fin.write.mode("overwrite").parquet(output_loc)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        type=str,
        help="HDFS input",
        default="s3a://user-analytics/raw/movie_review.csv",
    )
    parser.add_argument(
        "--output",
        type=str,
        help="HDFS output",
        default="s3a://user-analytics/clean/movie_review",
    )
    parser.add_argument("--run-id", type=str, help="run id", default="2024-05-05")
    args = parser.parse_args()
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
    random_text_classifier(
        input_loc=args.input, output_loc=args.output, run_id=args.run_id
    )
