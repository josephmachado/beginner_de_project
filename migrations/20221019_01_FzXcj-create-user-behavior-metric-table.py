"""
Create user_behavior_metric table
"""

from yoyo import step

steps = [
    step(
        "CREATE TABLE public.user_behavior_metric ( customerid INTEGER, amount_spent DECIMAL(18, 5), review_score INTEGER, review_count INTEGER, insert_date DATE )",
        "DROP TABLE public.user_behavior_metric",
    )
]
