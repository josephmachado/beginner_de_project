import os

import psycopg2

from airflow.hooks.postgres_hook import PostgresHook
from airflow.hooks.S3_hook import S3Hook


def _local_to_s3(
    bucket_name: str, key: str, file_name: str, remove_local: bool = False
) -> None:
    s3 = S3Hook()
    s3.load_file(
        filename=file_name, bucket_name=bucket_name, replace=True, key=key
    )
    if remove_local:
        if os.path.isfile(file_name):
            os.remove(file_name)


def run_redshift_external_query(qry: str) -> None:
    rs_hook = PostgresHook(postgres_conn_id="redshift")
    rs_conn = rs_hook.get_conn()
    rs_conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)
    rs_cursor = rs_conn.cursor()
    rs_cursor.execute(qry)
    rs_cursor.close()
    rs_conn.commit()
