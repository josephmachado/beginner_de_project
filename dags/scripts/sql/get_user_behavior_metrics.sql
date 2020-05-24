INSERT INTO public.user_behavior_metric (customerid, amount_spent, review_score, review_count, insert_date) 
SELECT ups.customerid, cast(sum( ups.Quantity * ups.UnitPrice) as decimal(18, 5)) as amount_spent, 
sum(mrcs.positive_review) as review_score, count(mrcs.cid) as review_count, '{{ ds }}'
FROM spectrum.user_purchase_staging ups  
JOIN (select cid, case when positive_review is True then 1 else 0 end as positive_review from spectrum.movie_review_clean_stage) mrcs  
ON ups.customerid = mrcs.cid WHERE ups.insert_date = '{{ ds }}' GROUP BY ups.customerid;
