up:
	docker compose up airflow-init && docker compose up --build -d

down:
	docker compose down

sh:
	docker exec -ti webserver bash

pytest:
	docker exec -ti webserver pytest -p no:warnings -v /opt/airflow/test

format:
	docker exec -ti webserver python -m black -S --line-length 79 .

isort:
	docker exec -ti webserver isort .

type:
	docker exec -ti webserver mypy --ignore-missing-imports /opt/airflow

lint: 
	docker exec -ti webserver flake8 /opt/airflow/dags

ci: isort format type lint pytest
