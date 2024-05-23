# CDCP XSLT Transforms

This `base_template` branch contains the base infrastructure necessary to perform XSLT transforms. The codebase is able to run as either as:

1. an AWS lambda, in response to an SQS notification informing of a file change to source file. The results are then output into the S3 bucket defined by `AWS_OUTPUT_BUCKET`.

or

2. a CI/CD or local build acting upon any number of items contained within the `./data` dir. The outputs are copied to `./dist`.

## Prerequisites

- Docker [https://docs.docker.com/get-docker/].

## Instructions for running the AWS Lambda Development version locally

### Prerequisites

Environment variables with the necessary AWS credentials stored in the following variables:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SECRET_ACCESS_KEY`

All other environment variables necessary for CUDL are stored in `.env`, such as the source and destination buckets.

### Running the AWS container locally

    docker compose -f docker-compose-aws-dev.yml up --build

**NB: ** This `docker-compose-aws-dev.yml` must not be used when building the container for deployment within AWS. Instead, follow the instructions below.

### Processing a file

The AWS Lambda responds to SQS messages. To transform a file, you need to submit a JSON file with the SQS structure with a `POST` request to `http://localhost:9000/2015-03-31/functions/function/invocations`:

    curl -X POST -H 'Content-Type: application/json' 'http://localhost:9000/2015-03-31/functions/function/invocations' --data-binary "@./sample/sns-tei-source-change.json"

Assuming you have the required permissions to access the resources, this container will create all the necessary outputs and, if successful, copy them to their S3 bucket destination.

**NOTE:** The lambda will attempt to download the item mentioned in the sample notification. You will consequently only be able to successfully run this lambda locally after you have successfully logged into AWS and stored your access keys (as above).

This information is coded in escaped JSON contained within the `body` property. If you search for ‘bucket’, you will find the name of the bucket (`rmm98-sandbox-cudl-data-source` at present) and the filename is stored within object key property (`items/data/tei/MS-ADD-03975/MS-ADD-03975.xml` at present). You will need to update these to buckets/items that exist and which you have access to.

## Instructions for running the local non-AWS container

### Prerequisites

Two directories at the root level of the repository:

* `data`, which contains the source data for your collection. This can be copied from the relevant S3 source bucket.
* `dist`, which will contain the finished outputs.

### Building the container and processing data

You must specify the file you want to process in the environment variable called `TEI_FILE` before you mount the container. This contains the path to the source file, relative to the root of the `./data`. This file will be processed as soon as the container is run.

To process MS-ADD-03975:

    export TEI_FILE=items/data/tei/MS-ADD-03975/MS-ADD-03975.xml
    docker compose -f docker-compose-local.yml up --build

`TEI_FILE` also accepts wildcards. The following will rebuild files for MS-ADD-04000 to MS-ADD-04009:

    export TEI_FILE=items/data/tei/**/MS-ADD-0400*.xml
    docker compose -f docker-compose-local.yml up --build

You cannot pass multiple files (with paths) to the container. It only accepts a single file or wildcards.

If the `TEI_FILE` environment variable is not set, the container will assume that you want to process all files (**/*.xml) in `./data`.
