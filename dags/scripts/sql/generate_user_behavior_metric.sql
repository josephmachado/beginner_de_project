DELETE FROM public.user_behavior_metric
WHERE insert_date = '{{ ds }}';
INSERT INTO public.user_behavior_metric (
        customerid,
        amount_spent,
        review_score,
        review_count,
        insert_date
    )
SELECT ups.customerid,
    CAST(
        SUM(ups.Quantity * ups.UnitPrice) AS DECIMAL(18, 5)
    ) AS amount_spent,
    SUM(mrcs.positive_review) AS review_score,
    count(mrcs.cid) AS review_count,
    '{{ ds }}'
FROM spectrum.user_purchase_staging ups
    JOIN (
        SELECT cid,
            CASE
                WHEN positive_review IS True THEN 1
                ELSE 0
            END AS positive_review
        FROM spectrum.classified_movie_review
        WHERE insert_date = '{{ ds }}'
    ) mrcs ON ups.customerid = mrcs.cid
WHERE ups.insert_date = '{{ ds }}'
GROUP BY ups.customerid;
