from datetime import datetime, timedelta

from airflow import DAG
from airflow.decorators import task
from airflow.operators.bash_operator import BashOperator
from airflow.providers.amazon.aws.operators.s3 import S3CreateBucketOperator
from airflow.providers.amazon.aws.transfers.local_to_s3 import \
    LocalFilesystemToS3Operator
from airflow.providers.amazon.aws.transfers.sql_to_s3 import SqlToS3Operator
from airflow.providers.apache.spark.operators.spark_submit import \
    SparkSubmitOperator

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
    movie_review_to_s3 = LocalFilesystemToS3Operator(
        task_id="create_local_to_s3_job",
        filename="/opt/airflow/data/movie_review.csv",
        dest_key="raw/movie_review.csv",
        dest_bucket=user_analytics_bucket,
        replace=True,
    )

    user_purchase_to_s3 = SqlToS3Operator(
        task_id="database_to_s3",
        sql_conn_id="postgres_default",
        query="select * from retail.user_purchase",
        s3_bucket=user_analytics_bucket,
        s3_key="raw/user_purchase",
        replace=True,
    )

    # movie_classifier = SparkSubmitOperator(
    #     task_id="python_job",
    #     conn_id="spark-conn",
    #     application="./dags/scripts/spark/random_text_classification.py",
    # )

    movie_classifier = BashOperator(
        task_id="pyspark",
        bash_command="python $AIRFLOW_HOME/dags/scripts/spark/random_text_classification.py",
    )

    create_s3_bucket >> [movie_review_to_s3, user_purchase_to_s3] >> movie_classifier
