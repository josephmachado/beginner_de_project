####################################################################################################################
# Setup containers to run Airflow
get-data:
	rm -rf ./data && rm -rf data.zip* && wget https://start-data-engg.s3.amazonaws.com/data.zip && unzip -o data.zip && chmod -R u=rwx,g=rwx,o=rwx data

docker-spin-up:
	docker compose  --env-file env up airflow-init && docker compose --env-file env up --build -d

perms:
	mkdir logs plugins temp && sudo chmod -R u=rwx,g=rwx,o=rwx logs plugins temp

up: get-data docker-spin-up

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
infra-up:
	terraform -chdir=./terraform apply --auto-approve

infra-down:
	terraform -chdir=./terraform destroy --auto-approve

####################################################################################################################
# Create tables in Warehouse
spectrum-create-tables:
	./spectrum_migrate.sh

redshift-create-tables:
	docker exec -ti webserver yoyo apply --no-config-file --database redshift://$$(terraform -chdir=./terraform output -raw redshift_user):$$(terraform -chdir=./terraform output -raw redshift_password)@$$(terraform -chdir=./terraform output -raw redshift_dns_name):5439/dev ./migrations

redshift-drop-tables:
	docker exec -ti webserver yoyo rollback --no-config-file --database redshift://$$(terraform -chdir=./terraform output -raw redshift_user):$$(terraform -chdir=./terraform output -raw redshift_password)@$$(terraform -chdir=./terraform output -raw redshift_dns_name):5439/dev ./migrations
