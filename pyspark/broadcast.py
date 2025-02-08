from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("example").getOrCreate()
# Example use case: Broadcasting a lookup table
product_lookup = {
    1: "Product A",
    2: "Product B",
    3: "Product C"
}

# Broadcast the lookup table
broadcast_product_lookup = spark.sparkContext.broadcast(product_lookup)

# Example RDD of transactions (product_id, quantity)
transactions = spark.sparkContext.parallelize([(1, 2), (2, 3), (3, 1)])

# Enrich transactions with product names using the broadcast variable
enriched_transactions = transactions.map(lambda x: (x[0], broadcast_product_lookup.value[x[0]], x[1])).collect()

print(enriched_transactions)
# Output: [(1, 'Product A', 2), (2, 'Product B', 3), (3, 'Product C', 1)]