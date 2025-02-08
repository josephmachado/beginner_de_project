from pyspark.sql import SparkSession
spark=SparkSession.builder.appName("Vaidya").getOrCreate()
data = [("Alice", 1), ("Bob", 2)]
df=spark.createDataFrame(data,['name','age'])
df.show()