####################################################################################################################
# Setup containers to run Airflow
get-data:
	rm -rf ./data && rm -rf data.zip* && wget https://start-data-engg.s3.amazonaws.com/data.zip && unzip -o data.zip && chmod -R u=rwx,g=rwx,o=rwx data

docker-spin-up:
	docker compose  --env-file env up airflow-init && docker compose --env-file env up --build -d

perms:
	mkdir -p logs plugins temp && sudo chmod -R u=rwx,g=rwx,o=rwx logs plugins temp dags tests migrations spectrum_tables

up: get-data perms docker-spin-up

down:
	docker compose down

sh:
	docker exec -ti webserver bash

####################################################################################################################
# Testing, auto formatting, type checks, & Lint checks
pytest:
	docker exec webserver pytest -p no:warnings -v /opt/airflow/tests

format:
	docker exec webserver python -m black -S --line-length 79 .

isort:
	docker exec webserver isort .

type:
	docker exec webserver mypy --ignore-missing-imports /opt/airflow

lint: 
	docker exec webserver flake8 /opt/airflow/dags

ci: isort format type lint pytest

####################################################################################################################
# Set up cloud infrastructure
tf-init:
	terraform -chdir=./terraform init

infra-up:
	terraform -chdir=./terraform apply

infra-down:
	terraform -chdir=./terraform destroy

infra-config:
	terraform -chdir=./terraform output

####################################################################################################################
# Create tables in Warehouse
spectrum-migration:
	./spectrum_migrate.sh

db-migration:
	@read -p "Enter migration name:" migration_name; docker exec webserver yoyo new ./migrations -m "$$migration_name"

redshift-migration:
	docker exec -ti webserver yoyo apply --no-config-file --database redshift://$$(terraform -chdir=./terraform output -raw redshift_user):$$(terraform -chdir=./terraform output -raw redshift_password)@$$(terraform -chdir=./terraform output -raw redshift_dns_name):5439/dev ./migrations

redshift-rollback:
	docker exec -ti webserver yoyo rollback --no-config-file --database redshift://$$(terraform -chdir=./terraform output -raw redshift_user):$$(terraform -chdir=./terraform output -raw redshift_password)@$$(terraform -chdir=./terraform output -raw redshift_dns_name):5439/dev ./migrations

warehouse-data-migration: spectrum-migration redshift-migration

####################################################################################################################
# Port forwarding to local machine

cloud-metabase:
	terraform -chdir=./terraform output -raw private_key > private_key.pem && chmod 600 private_key.pem && ssh -o "IdentitiesOnly yes" -i private_key.pem ubuntu@$$(terraform -chdir=./terraform output -raw ec2_public_dns) -N -f -L 3000:$$(terraform -chdir=./terraform output -raw ec2_public_dns):3000 && open http://localhost:3000 && rm private_key.pem

cloud-airflow:
	terraform -chdir=./terraform output -raw private_key > private_key.pem && chmod 600 private_key.pem && ssh -o "IdentitiesOnly yes" -i private_key.pem ubuntu@$$(terraform -chdir=./terraform output -raw ec2_public_dns) -N -f -L 8080:$$(terraform -chdir=./terraform output -raw ec2_public_dns):8080 && open http://localhost:8080 && rm private_key.pem

####################################################################################################################
# Helpers

ssh-ec2:
	terraform -chdir=./terraform output -raw private_key > private_key.pem && chmod 600 private_key.pem && ssh -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i private_key.pem ubuntu@$$(terraform -chdir=./terraform output -raw ec2_public_dns) && rm private_key.pem