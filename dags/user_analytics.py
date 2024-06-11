from datetime import datetime, timedelta

from airflow import DAG
from airflow.decorators import task
from airflow.providers.amazon.aws.operators.s3 import S3CreateBucketOperator
from airflow.providers.amazon.aws.transfers.local_to_s3 import \
    LocalFilesystemToS3Operator

with DAG(
    "user_analytics_dag",
    description="A DAG to Pull user data and movie review data \
        to analyze their behaviour",
    schedule_interval=timedelta(days=1),
    start_date=datetime(2023, 1, 1),
    catchup=False,
) as dag:
    user_analytics_bucket = "user-analytics"

    # Copy data from local ./data to bucket under raw

    # Run Spark job to pull data from the above location
    # process it and write to clean

    # DuckDB to pull data from clean and create a table
    create_s3_bucket = S3CreateBucketOperator(
        task_id="create_s3_bucket", bucket_name=user_analytics_bucket
    )
    create_local_to_s3_job = LocalFilesystemToS3Operator(
        task_id="create_local_to_s3_job",
        filename="/opt/airflow/data/movie_review.csv",
        dest_key="movie_review.csv",
        dest_bucket=user_analytics_bucket,
        replace=True,
    )
    create_s3_bucket >> create_local_to_s3_job
