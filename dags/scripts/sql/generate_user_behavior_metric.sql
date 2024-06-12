with up as ( select * from '/opt/airflow/temp/s3folder/raw/user
_purchase/user_purchase.csv'), mr as (select * from '/opt/airflow/t
emp/s3folder/clean/movie_review/*.parquet') select up.customer_id, 
sum(up.quantity * up.unit_price) as amount_spent, sum(case when mr.
positive_review then 1 else 0 end) as num_positive_reviews, count(m
r.cid) as num_reviews from up join mr on up.customer_id = mr.cid gr
oup by up.customer_id;
