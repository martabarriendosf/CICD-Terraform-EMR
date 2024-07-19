import argparse
from pyspark.sql import SparkSession
from pyspark.sql.functions import col

def transform_data(data_source: str, output_uri: str) -> None:
    #Create or recover the Spark Session "My First App"
    with SparkSession.builder.appName("My firs App").getOrCreate() as spark:
        #Load CSV file, read it and use the first file (header)
        df = spark.read.option("header", "true").csv(data_source)

        #Rename columns without spaces, it returns you the dataframe df with the 2 specified columns
        df = df.select(
            col("Name").alias("name"),
            col("Violation Type").alias("violation_type"),
        )

        #Create an in-memory DataFrame with the name restaurant_violations to execute
        #SQL queries against it
        df.createOrReplaceTempView("restaurant_violations")
        
        #Consult SQL query
        GROUP_BY_QUERY = """
            SELECT name, count(*) AS total_red_violations
            FROM restaurant_violations
            WHERE violation_type="RED"
            GROUP BY name
        """

        #Execute the SQL query against the dataframe and returns a new dataframe transformed-df
        #with as many rows as total violations
        transformed_df=spark.sql(GROUP_BY_QUERY)

        #Log into EMR stdout
        print(f"Number of rows in SQL query: {transformed_df.count()}")

        #Write our results as parquet files in output_uri that will be an S3 bucket, is the optimal way
        # to store data structured in columns, we will overwrite the file if it already exists in that path
        transformed_df.write.mode("overwrite").parquet(output_uri)

#We verify that we are in the main file to run the above code
if __name__ == "__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument('--data_source')
    parser.add_argument('--output_uri')
    args=parser.parse_args()

    transform_data(args.data_source,args.output_uri)