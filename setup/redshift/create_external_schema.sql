create external schema spectrum 
from data catalog 
database 'spectrumdb' 
iam_role '<your-iam-Role-ARN>'
create external database if not exists;

-- user purchase staging table with an insert_date partition
drop table if exists spectrum.user_purchase_staging;
create external table spectrum.user_purchase_staging (
    InvoiceNo varchar(10),
    StockCode varchar(20),
    detail varchar(1000),
    Quantity integer,
    InvoiceDate timestamp,
    UnitPrice decimal(8,3),
    customerid integer,
    Country varchar(20)
)
partitioned by (insert_date date)
row format delimited fields terminated by ','
stored as textfile
location 's3://<your-s3-bucket>/user_purchase/stage/'
table properties ('skip.header.line.count'='1');

-- movie review staging table
drop table if exists spectrum.movie_review_clean_stage;
CREATE EXTERNAL TABLE spectrum.movie_review_clean_stage (
   cid varchar(100),
   positive_review boolean
)
STORED AS PARQUET
LOCATION 's3://<your-s3-bucket>/movie_review/stage/';

-- user behaviour metric tabls
DROP TABLE IF EXISTS public.user_behavior_metric;
CREATE TABLE public.user_behavior_metric (
    customerid integer,
    amount_spent decimal(18, 5),
    review_score integer,
    review_count integer,
    insert_date date
);
