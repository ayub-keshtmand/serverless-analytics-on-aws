#!/bin/bash
# needs refining
# Add `us-east-1` entry to `GlueStack.yml`’s `Mappings:RegionMap`

# Go to directory
cd ETLAnalyticsUsingGlue

# Create bucket that will store python script
SCRIPT_BUCKET=mantooth-script-bucket
aws s3api create-bucket \
--bucket $SCRIPT_BUCKET \
--region us-east-1

# Upload python script to bucket
aws s3api put-object \
--bucket $SCRIPT_BUCKET \
--key sakila_etl.py \
--body sakila_etl.py

# Create Glue stack
GLUE_STACK_BUCKET=mantooth-glue-stack-bucket

aws cloudformation create-stack \
--stack-name GlueStack \
--template-body file://GlueStack.yml \
--capabilities CAPABILITY_NAMED_IAM \
--parameters \
ParameterKey=S3DestinationBucketName,ParameterValue=$GLUE_STACK_BUCKET

# Set Glue crawler name variable
GLUE_CRAWLER=$(aws cloudformation describe-stacks \
--stack-name GlueStack \
--query \
"Stacks[].Outputs[?OutputKey=='GlueCrawlerName'].OutputValue" \
--output text)

# Run Glue crawler
aws glue start-crawler --name $GLUE_CRAWLER

# Check Glue crawler status
aws glue get-crawler \
--name $GLUE_CRAWLER \
--query "Crawler.State" \
--output text

# Check tables created in Glue Data Catalog
aws glue get-tables \
--database-name sakiladb \
--query "TableList[].Name"

# Run Glue job
GLUE_JOB=GlueStack-aurora-etljob
aws glue start-job-run \
--job-name $GLUE_JOB \
--region us-east-1

# Check Glue job status
aws glue get-job-runs \
--job-name $GLUE_JOB \
--query "JobRuns[].JobRunState" \
--output text