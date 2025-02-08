from pyspark.sql import SparkSession
spark=SparkSession.builder.appName("Columns").getOrCreate()
data = [("James","Smith","USA","CA"),("Michael","Rose","USA","NY"), \
    ("Robert","Williams","USA","CA"),("Maria","Jones","USA","FL") \
  ]
columns=["firstname","lastname","country","state"]
df=spark.createDataFrame(data,columns)
df.show()
print(df.collect()) 
#List format