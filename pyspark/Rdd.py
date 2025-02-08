from pyspark import SparkContext, SparkConf
# Create a Spark configuration
conf = SparkConf().setAppName("example").setMaster("local")
# Initialize the SparkContext
sc = SparkContext(conf=conf)

rdd = sc.parallelize([('apple', 1), ('banana', 2), ('apple', 3), ('banana', 1), ('orange', 2)])
rdd_agg = rdd.reduceByKey(lambda x, y: x + y)
print(rdd_agg.collect())