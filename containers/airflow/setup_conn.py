import subprocess

# Define connection details
conn_id = "aws_default"
conn_type = "aws"
access_key = "minio"
secret_key = "minio123"
region_name = "us-east-1"
endpoint_url = "http://minio:9000"
# Construct the extra JSON
extra = {
    "aws_access_key_id": access_key,
    "aws_secret_access_key": secret_key,
    "region_name": region_name,
    "host": endpoint_url,
}
# Convert to JSON string
extra_json = str(extra).replace("'", '"')
# Define the CLI command
command = [
    "airflow",
    "connections",
    "add",
    conn_id,
    "--conn-type",
    conn_type,
    "--conn-extra",
    extra_json,
]
# Execute the command
subprocess.run(command)


def add_airflow_connection():
    connection_id = "spark_default"
    connection_type = "spark"
    host = "spark://spark-master:7077"
    extra = '{"queue": "default"}'

    cmd = [
        "airflow",
        "connections",
        "add",
        connection_id,
        "--conn-type",
        connection_type,
        "--conn-host",
        host,
        "--conn-extra",
        extra,
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        print(f"Successfully added {connection_id} connection")
    else:
        print(f"Failed to add {connection_id} connection: {result.stderr}")


add_airflow_connection()
