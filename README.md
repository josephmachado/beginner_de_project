
* [Beginner DE Project - Batch Edition](#beginner-de-project---batch-edition)
    * [Architecture](#architecture)
    * [Run Data Pipeline](#run-data-pipeline)
        * [Codespaces](#codespaces)
        * [Your Machine](#your-machine)

# Beginner DE Project - Batch Edition

Code for blog at [Data Engineering Project for Beginners](https://www.startdataengineering.com/post/data-engineering-project-for-beginners-batch-edition/).

## Architecture

![Data pipeline design](assets/images/arch.png)

This data engineering project, includes the following:

1. **`Airflow`**: To schedule and orchestrate DAGs.
2. **`Postgres`**: To store Airflow's details (which you can see via Airflow UI) and also has a schema to represent upstream databases.
3. **`DuckDB`**: To act as our warehouse
4. **`Quarto with Plotly`**: To convert code in `markdown` format to html files that can be embedded in your app or servered as is.
5. **`minio`**: To provide an S3 compatible open source storage system.
6. **`Apache Spark`: To process our data, specifically to run a classification algorithm.

## Run Data Pipeline

![Airflow DAG run](assets/images/dag.png)

### Codespaces

Start a code spaces, run `make up`, wait until its ready and click on the link in the Port tab to see the AirflowUI.
**Note**: Make sure to turn off your codespaces when you are done, you only have a limited amount of free codespace use.

![Codespace](assets/images/cs1.png)
![Codespace make up](assets/images/cs2.png)
![Codespace Airflow UI](assets/images/cs3.png)

### Your Machine

1. [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
2. [Docker](https://docs.docker.com/engine/install/) with at least 4GB of RAM and [Docker Compose](https://docs.docker.com/compose/install/) v1.27.0 or later

Clone the repo and run the make up command as shown here:

```bash
git clone https://github.com/josephmachado/beginner_de_project.git
cd beginner_de_project
make up
make ci # run checks and tests
# To stop your containers run make down 
```

Open Airflow at [localhost:8080](http://localhost:8080) and sign in with username and password as `airflow`. Switch on the `user_analytics_dag` and it will start running.

On completion, you can see the dashboard html rendered at[./dags/scripts/dashboard.html](./dags/scripts/dashboard.html).

Read **[this post](https://www.startdataengineering.com/post/data-engineering-projects-with-free-template/)**, for information on setting up CI/CD, IAC(terraform), "make" commands and automated testing.

