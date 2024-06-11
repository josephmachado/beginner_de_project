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
