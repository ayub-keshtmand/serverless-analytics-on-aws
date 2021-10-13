#!/bin/bash
# needs refining

# Clone github repo
rm README.md &&
git clone https://github.com/cloudleader/ETLAnalyticsUsingGlue

# Go to repo directory
cd ETLAnalyticsUsingGlue

# Unzip compressed folder
rm README.md &&
unzip sakila-db.zip &&
rm sakila-db.zip

# Create Aurora stack via CloudFormation
aws cloudformation create-stack \
--stack-name AuroraStack \
--template-body file://AuroraStack.yml

# Save Aurora cluster endpoint url to a variable
export AURORA_CLUSTER_ENDPOINT=$(aws cloudformation describe-stacks \
--stack-name AuroraStack \
--query \
"Stacks[].Outputs[?OutputKey == 'AuroraClusterEndPoint'].OutputValue" \
--output text)

# Run MySQL via Docker
#-v /home/ec2-user/environment/ETLAnalyticsUsingGlue:/home \
docker run -d \
--name aurora \
-v $PWD:/home \
-e MYSQL_ALLOW_EMPTY_PASSWORD=true \
-e AURORA_CLUSTER_ENDPOINT=$AURORA_CLUSTER_ENDPOINT \
mysql

# Connect to Aurora instance via Docker
docker exec -it aurora \
mysql \
--host=$AURORA_CLUSTER_ENDPOINT \
--user=auradmin \
--password=auradmin123 \
--ssl-mode=DISABLED

# Create schema and insert data
source /home/sakila-db/sakila-schema.sql
source /home/sakila-db/sakila-data.sql

# Check tables are populated
SELECT COUNT(1) FROM actor \
UNION ALL \
SELECT COUNT(1) FROM film \
UNION ALL \
SELECT COUNT(1) FROM store ;