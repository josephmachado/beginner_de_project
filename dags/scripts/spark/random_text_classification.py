# pyspark
import argparse

from pyspark.sql import SparkSession
from pyspark.ml.feature import Tokenizer, StopWordsRemover
from pyspark.sql.functions import array_contains


def random_text_classifier(input_loc, output_loc):
    """
    This is a dummy function to show how to use spark, It is supposed to mock
    the following steps
        1. clean input data
        2. use a pre-trained model to make prediction 
        3. write predictions to a HDFS output

    Since this is meant as an example, we are going to skip building a model,
    instead we are naively going to mark reviews having the text "good" as positive and
    the rest as negative 
    """

    # read input
    df_raw = spark.read.option("header", True).csv(input_loc)
    # perform text cleaning

    # Tokenize text
    tokenizer = Tokenizer(inputCol='review_str', outputCol='review_token')
    df_tokens = tokenizer.transform(df_raw).select('cid', 'review_token')

    # Remove stop words
    remover = StopWordsRemover(
        inputCol='review_token', outputCol='review_clean')
    df_clean = remover.transform(
        df_tokens).select('cid', 'review_clean')

    # function to check presence of good
    df_out = df_clean.select('cid', array_contains(
        df_clean.review_clean, "good").alias('positive_review'))
    # parquet is a popular column storage format, we use it here
    df_out.write.mode("overwrite").parquet(output_loc)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=str,
                        help='HDFS input', default='/movie')
    parser.add_argument('--output', type=str,
                        help='HDFS output', default='/output')
    args = parser.parse_args()
    spark = SparkSession.builder.appName(
        'Random Text Classifier').getOrCreate()
    random_text_classifier(input_loc=args.input, output_loc=args.output)
