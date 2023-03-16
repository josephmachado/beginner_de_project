# E-commerce Data Batch Processing pipeline
* extended from https://github.com/josephmachado/beginner_de_project


- [E-commerce Data Batch Processing pipeline](#e-commerce-data-batch-processing-pipeline)
  - [Design](#design)
  - [Adding Extra Airflow Steps](#adding-extra-airflow-steps)
  - [Serving](#serving)

## Design

We will be using Airflow to orchestrate

1. Classifying movie reviews with Apache Spark.
2. Loading the classified movie reviews into the data warehouse.
3. Extract user purchase data from an OLTP database and load it into the data warehouse.
4. Joining the classified movie review data and user purchase data to get `user behavior metric` data.

![Data pipeline design](assets/images/de_proj_design.png)

## Adding Extra Airflow Steps
1. Install ElasticSearch on EC2
2. Calculate recommendataion embedding of products using AWS EMR and save to S3
   * TODO: is there a way that EMR can save results to OpenSearch directly
3. Load recommendataion embedding from S3 to EC2 ElasticSearch

## Serving 
* Build a real-time recommendation api using fastapi and elasticsearch