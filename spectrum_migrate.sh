#!/bin/bash
rm -rf spectrum_query_to_run
mkdir spectrum_query_to_run

# todo loop through all queries in ./spectrum_tables

echo 'Generating query to be run from 0001-create-stage-tables.sql'
cat ./spectrum_tables/0001-create-stage-tables.sql | sed s/data-lake-bucket/$(terraform -chdir=./terraform output -raw bucket_name)/ > ./spectrum_query_to_run/0001-create-stage-tables-run.sql

echo 'Running query ./spectrum_query_to_run/0001-create-stage-tables-run.sql'
psql -f ./spectrum_query_to_run/0001-create-stage-tables-run.sql postgres://$(terraform -chdir=./terraform output -raw redshift_user):$(terraform -chdir=./terraform output -raw redshift_password)@$(terraform -chdir=./terraform output -raw redshift_dns_name):5439/dev

rm -rf spectrum_query_to_run
