from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.dummy_operator import DummyOperator
from airflow.operators.postgres_operator import PostgresOperator
from airflow.hooks.S3_hook import S3Hook
from airflow.operators import PythonOperator

# config
# local
unload_user_purchase ='./scripts/sql/filter_unload_user_purchase.sql'
temp_filtered_user_purchase = '/temp/temp_filtered_user_purchase.csv'

# remote config
BUCKET_NAME = '<your-bucket-name>'
temp_filtered_user_purchase_key= 'user_purchase/stage/{{ ds }}/temp_filtered_user_purchase.csv'

# helper function(s)
def _local_to_s3(filename, key, bucket_name=BUCKET_NAME):
    s3 = S3Hook()
    s3.load_file(filename=filename, bucket_name=bucket_name,
                 replace=True, key=key)

# Ideally I'd have configs in a different file or set them as docker env variables, 
# but due to this being a simple example I'll keep them with the DAG script.

default_args = {
    "owner": "airflow",
    "depends_on_past": True,
    'wait_for_downstream': True,
    "start_date": datetime(2010, 12, 1), # we start at this date to be consistent with the dataset we have and airflow will catchup
    "email": ["airflow@airflow.com"],
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5)
}

dag = DAG("user_behaviour", default_args=default_args,
          schedule_interval="0 0 * * *", max_active_runs=1)

end_of_data_pipeline = DummyOperator(task_id='end_of_data_pipeline', dag=dag)

pg_unload = PostgresOperator(
    dag=dag,
    task_id='pg_unload',
    sql=unload_user_purchase,
    postgres_conn_id='postgres_default',
    params={'temp_filtered_user_purchase': temp_filtered_user_purchase},
    depends_on_past=True,
    wait_for_downstream=True
)

user_purchase_to_s3_stage = PythonOperator(
    dag=dag,
    task_id='user_purchase_to_s3_stage',
    python_callable=_local_to_s3,
    op_kwargs={
        'filename': temp_filtered_user_purchase,
        'key': temp_filtered_user_purchase_key,
    },
)

pg_unload >> user_purchase_to_s3_stage >> end_of_data_pipeline