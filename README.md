# Github - Serverless Analytics on AWS
#tutorials/pluralsight/serverless-analytics-on-aws

Adapted from: [Serverless Analytics on AWS | Pluralsight](https://app.pluralsight.com/library/courses/serverless-analytics-aws/table-of-contents)

## Contents
* Creating an Aurora Database
* Creating an AWS Glue Job to Crawl an Aurora Database
* Creating an AWS Glue Job to Crawl an S3 Bucket

## Creating an Aurora Database
Overview:
```
# Clone a github repo
# Create Aurora resources using CloudFormation
# Create a MySQL environment using Docker
# Connect to Aurora instance in Docker
# Create tables and populate with data
```

Clone GitHub:
```bash
git clone https://github.com/cloudleader/ETLAnalyticsUsingGlue
```

Unzip folder:
```bash
unzip sakila-db.zip
rm sakila-db.zip
```

Get IP address:
```bash
ifconfig
```

CloudFormation setup:
```
Go to CloudFormation
	Create stack
	Create template in Designer
	Template tab (bottom of screen)
	Choose template language: YAML
	Open template: s3://mantooth-bucket-20210928/ETLAnalyticsUsingGlue/AuroraStack.yml
	Validate template (top bar click on checkbox)
	Create stack (top bar cloud icon)
	Add IP
	Create
```

CloudFormation setup using AWS CLI:
```bash
aws cloudformation create-stack \
--stack-name AuroraStack \
--template-body file://ETLAnalyticsUsingGlue/AuroraStack.yml
```

Check that it worked:
```bash
# list all stacks
aws cloudformation list-stacks

# list your stack
aws cloudformation describe-stacks --stack-name AuroraStack
```

See CloudFormation UI Output tab for Aurora connection details:
```
AuroraClusterEndPoint: aurorastack-auroracluster-dk1z4anksvp1.cluster-cahmqjfrqmzy.us-east-1.rds.amazonaws.com
AuroraClusterUserName: auradmin
AuroraClusterPassword: auradmin123
AuroraDatabaseName: sakila
```

Check stack status:
```bash
aws cloudformation describe-stacks \
--stack-name AuroraStack \
--query "Stacks[].StackStatus" \
--output text
```

Or: save CloudFormation credentials via AWS CLI:
```bash
# all credentials except for cluster endpoint are in the AuroraStack.yml file so no need to fetch those values
# use global option --query in describe-stacks to parse cluster endpoint
# see example: https://jmespath.org/
# see tutorial: https://jmespath.org/tutorial.html
export AURORA_CLUSTER_ENDPOINT=$(aws cloudformation describe-stacks \
--stack-name AuroraStack \
--query \
"Stacks[].Outputs[?OutputKey == 'AuroraClusterEndPoint'].OutputValue[] | [0]" \
--output text)
```

[Where you think an output is a single-element array and cannot index it like a normal array then likely it is a general hash. See this link on how to parse that.](https://jmespath.org/examples.html#:~:text=In%20order%20to%20get%20to%20this%20value%20from%20our%20filtered%20results%20we%20need%20to%20first%20select%20the%20general%20key.%20This%20gives%20us%20a%20list%20of%20just%20the%20values%20of%20the%20general%20hash%3A)

(Install and) Run MySQL in Docker:
```bash
docker run -d \
--name aurora \
-v $PWD:/home \
-e MYSQL_ALLOW_EMPTY_PASSWORD=true \
-e AURORA_CLUSTER_ENDPOINT=$AURORA_CLUSTER_ENDPOINT \
mysql
```

Connect to Docker container:
```bash
docker exec -it aurora bash
```

Connect to Aurora instance:
```bash
mysql \
	--host="aurorastack-auroracluster-1egukwt5bxgq5.cluster-cnjayqdtfz2g.us-east-1.rds.amazonaws.com" \
	--user=auradmin \
	--password=auradmin123 \
	--ssl-mode=DISABLED

# or if saved aurora cluster endpoint as env variable then:
mysql \
	--host=$AURORA_CLUSTER_ENDPOINT \
	--user=auradmin \
	--password=auradmin123 \
	--ssl-mode=DISABLED
```

Or: do all in one go i.e. Connect to Docker and Aurora in MySQL instance:
```bash
docker exec -it aurora \
mysql \
--host=$AURORA_CLUSTER_ENDPOINT \
--user=auradmin \
--password=auradmin123 \
--ssl-mode=DISABLED
```

Check you’re connected to the Aurora instance:
```bash
status
```

Run SQL to create schema:
```bash
source /home/sakila-db/sakila-schema.sql
```

Check database was created:
```bash
show databases;
```

Check session details:
```bash
# should return correct host, db, etc.
status;
```

Insert data:
```bash
source /home/sakila-db/sakila-data.sql
```

See full script: `create_aurora_database.sh`

## Creating an AWS Glue Job to Crawl an Aurora Database
Overview:
```
# Upload python script transformation code
# Create AWS Glue CloudFormation stack
# Use Glue crawlers
	# Crawl Aurora database and populate Glue Data Catalog
	# Crawl output Glue job's transformations
# AWS Glue ETL jobs and transformations
# AWS Glue Data Catalog
# Query parquet-formatted data with Athena
```

Add `us-east-1` entry to `GlueStack.yml`’s `Mappings:RegionMap`:
```yml
Mappings:
  RegionMap:
    us-east-1:
      scriptpath: s3://aurora-glue-etl-script-east1/sakila_etl.py
```

Set some variables:
```bash
cd ETLAnalyticsUsingGlue
BUCKET_NAME=aurora-glue-etl-script-east1
```

Create S3 bucket:
```bash
aws s3api create-bucket --bucket $BUCKET_NAME
aws s3 ls # check if bucket successfully created
```

Will be uploading the `sakila_etl.py` script to an S3 bucket:
```python
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

# Arguments passed to the glue job
args = getResolvedOptions(sys.argv, ["JOB_NAME"])

# Extract the destination bucket parameter
newparam = getResolvedOptions(sys.argv, ["destination"])

# Set the Spark Context
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)

# Initialise the job
job.init(args["JOB_NAME"], args)

# Create dynamic frames for the tables we want to join
films = glueContext.create_dynamic_frame.from_catalog(
	database="sakiladb",
	table_name="glue_sakila_film
)
film_to_cat = glueContext.create_dynamic_frame.from_catalog(
	database="sakiladb",
	table_name="glue_sakila_film_category"
)
categories = glueContext.create_dynamic_frame.from_catalog(
	database="sakiladb",
	table_name="glue_sakila_category"	
)

# Apply joins to tie together a film and its category
films_temp = Join.apply(
	frame1=films,
	frame2=film_to_cat,
	keys1=["film_id"],
	keys2=["film_id"]
)
films_to_cat = Join.apply(
	frame1=films_temp,
	frame2=categories,
	key1=["category_id"],
	key2=["category_id"]
)

# Construct the destination bucket URL
destinationbucket = "s3://" + newparam["destination"]

# Write the films_to_cat dynamic frame to desired S3 bucket in parquet format
glueContext.write_dynamic_frame.from_options(
	frame=films_to_cat,
	connection_type="s3",
	connection_options= { "path": destinationbucket },
	format="parquet"
)

job.commit()
```

Upload python script to bucket:
```bash
aws s3api put-object \
--bucket $BUCKET_NAME \
--key sakila_etl.py # if you add a path then all folders will be uploaded together with the file
```

If you need to delete an object from S3:
```bash
aws s3api delete-object \
--bucket $BUCKET_NAME \
--key sakila_etl.py
```

Check S3 bucket contents:
```bash
aws s3 ls $BUCKET_NAME
# add --recursive to see sub directories/folders and objects
```

Check object’s metadata:
```bash
# ensure ContentType is "binary/octet-stream
aws s3api head-object \
--bucket $BUCKET_NAME \
--key sakila_etl.py

# to fetch ContentType directly
aws s3api head-object \
--bucket $BUCKET_NAME \
--key sakila_etl.py \
--query "ContentType" \
--output text
```

If object’s metadata is incorrect then remove object and re-upload including metadata values ([more info](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/s3api/put-object.html)):
```bash
# not tested
aws s3api put-object \
--bucket $BUCKET_NAME \
--key sakila_etl.py \
--metadata ContentType="binary/octet-stream" # might not be correct syntax
```

Create the CloudFormation stack:
```bash
GLUE_STACK_BUCKET=mantooth-glue-stack-bucket
aws cloudformation create-stack \
--stack-name GlueStack \
--template-body file://GlueStack.yml \
--capabilities CAPABILITY_NAMED_IAM \
--parameters \
ParameterKey=S3DestinationBucketName,ParameterValue=$GLUE_STACK_BUCKET
```

Set Glue crawler name variable:
```bash
GLUE_CRAWLER=$(aws cloudformation describe-stacks \
--stack-name GlueStack \
--query \
"Stacks[].Outputs[?OutputKey=='GlueCrawlerName'].OutputValue" \
--output text)
```

Run crawler:
```bash
aws glue start-crawler --name $GLUE_CRAWLER
```

Check crawler status:
```bash
aws glue get-crawler --name $GLUE_CRAWLER
```

Check tables in our Glue Data Catalog database:
```bash
aws glue get-tables \
--database-name sakiladb \
--query "TableList[].Name"
```

Run Glue job:
```bash
aws glue start-job-run --job-name GlueStack-aurora-etljob
```

See full script: `glue_job_aurora.sh`

## Creating an AWS Glue Job to Crawl an S3 Bucket
Get IAM role for new Glue crawler:
```bash
GLUE_IAM_ROLE=$(aws cloudformation describe-stacks \
--stack-name GlueStack \
--query \
"Stacks[].Outputs[?OutputKey=='GlueIAMRole'].OutputValue" \
--output text)
```

Create new crawler:
```bash
GLUE_STACK_BUCKET=mantooth-glue-stack-bucket
GLUE_CRAWLER=mantooth-s3-film-cat-crawler

aws glue create-crawler \
--name $GLUE_CRAWLER \
--role $GLUE_IAM_ROLE \
--database-name sakiladb \
--table-prefix s3_ \
--region us-east-1 \
--targets "{\"S3Targets\": [{\"Path\": \"s3://${GLUE_STACK_BUCKET}\"}]}"
```
See [here](https://aws-glue-immersion-day.workshop.aws/lab1/create-crawler-cli.html) for more info (especially for `--targets` value.

Run crawler:
```bash
aws glue start-crawler --name $GLUE_CRAWLER
```

Check crawler status:
```bash
aws glue get-crawler \
--name $GLUE_CRAWLER \
--query "Crawler.State" \
--output text
```

Check tables:
```bash
aws glue get-tables \
--database-name sakiladb \
--query "TableList[].Name"
```

Full script: work in progress.