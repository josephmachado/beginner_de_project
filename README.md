# Beginner DE Project - Batch Edition

Code for blog at [Data Engineering Project for Beginners](https://www.startdataengineering.com/post/data-engineering-project-for-beginners-batch-edition/).

## Architecture

![Data pipeline design](assets/images/arch.png)

We will be using Airflow to orchestrate
1. Classifying movie reviews with Apache Spark.
2. Loading the classified movie reviews into the data warehouse.
3. Extract user purchase data from an OLTP database and load it into the data warehouse.
4. Joining the classified movie review data and user purchase data to get `user behavior metric` data.

## Run Data Pipeline

### Codespaces

add: images

### Your Machine

1. [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
2. [Docker](https://docs.docker.com/engine/install/) with at least 4GB of RAM and [Docker Compose](https://docs.docker.com/compose/install/) v1.27.0 or later

### See detailed explanation at [Data engineering project: Batch edition](https://www.startdataengineering.com/post/data-engineering-project-for-beginners-batch-edition)

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

