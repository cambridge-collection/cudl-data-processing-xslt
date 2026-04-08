# XSLT for item TEI -> JSON processing

The code in this repository is used for processing TEI item data into all the formats used by the Cambridge Digital Collections Platform, namely:

1. `core-xml` contains the processed metadata (including html page files and collection information)
1. `json-dp` contains the JSON files that contain the metadata necessary for items to be processed in Cambridge University Library’s Digital Preservation pipeline.
1. `json-solr` contains the JSON files that contain the metadata and textual content for indexing in solr.
1. `json-viewer` contains the JSON files required for the viewer to function
1. `page-xml` contains TEI XML files for each individual page.
1. 1. The `www` directory contains html files for every page transcription or translation along with associated UI resources (inline diagrams, css, javascript)

The lambda additionally places a copy of the original, unmodified, source TEI XML file into `items`.

The application is dockerised. There are two versions:

1. One that creates the environment for running in an AWS Lambda. which relies on a wide range of AWS infrastructure to function.
2. The other version runs off locally stored data files. This is the version that’s best suited for implementation within a CI/CD system or for running local builds.

## Prerequisites

- Docker [https://docs.docker.com/get-docker/].

## Instructions for running the AWS Lambda Development version locally

### Prerequisites

Environment variables with the necessary AWS credentials stored in the following variables:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`

All other environment variables necessary for CUDL are stored in `.env`, such as the source and destination buckets.

### Running the AWS container locally

    docker compose -f docker-compose-aws-dev.yml up --build

**NB: ** This `docker-compose-aws-dev.yml` must not be used when building the container for deployment within AWS. Instead, follow the instructions below.

### Processing a file

The AWS Lambda responds to SQS messages. To transform a file, you need to submit a JSON file with the SQS structure with a `POST` request to `http://localhost:9000/2015-03-31/functions/function/invocations`:

    curl -X POST -H 'Content-Type: application/json' 'http://localhost:9000/2015-03-31/functions/function/invocations' --data-binary "@./sample/sns-tei-source-change.json"

Assuming you have the required permissions to access the resources, this container will create all the necessary outputs and, if successful, copy them to their S3 bucket destination.

**NOTE:** The lambda will attempt to download the item mentioned in the sample notification. You will consequently only be able to successfully run this lambda locally after you have successfully logged into AWS and stored your access keys (as above).

This information is coded in escaped JSON contained within the `body` property. If you search for ‘bucket’, you will find the name of the bucket (‘rmm98-sandbox-cudl-data-source’ at present) and the filename is stored within object key property (items/data/tei/MS-ADD-03975/MS-ADD-03975.xml` at present). You will need to update these to buckets/items that exist and which you have access to.

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

## Per-object metadata and conditional uploads

When enabled, the Lambda attaches user-metadata to each uploaded output object and uses those metadata fields to skip unchanged uploads.

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `ENABLE_SHA_METADATA` | `false` | Attach `content-sha256` (hex SHA-256 of the file bytes) to each uploaded object. |
| `ENABLE_RELEASE_STATUS_METADATA` | `false` | Derive release status from the TEI via XPath and attach `release-status` (`released` or `draft`) to each uploaded object. |

### Behaviour

- When both flags are `false`, all outputs are uploaded unconditionally (original behaviour).
- In all cases, if the destination object itself is missing, it is uploaded regardless of flag state.
- When one or both flags are enabled, the Lambda compares only the enabled metadata fields against the destination object:
  - If any enabled field is missing or different on the destination, the file is uploaded with the new metadata.
  - If all enabled fields are present and match, the upload is skipped for that file.
- Disabled metadata fields are never generated, read, or compared.
- Release status is derived from the TEI in Python using Saxon XPath evaluation (`exists(/tei:TEI/tei:teiHeader/tei:revisionDesc/tei:change[@status='released'])`). It is only evaluated when `ENABLE_RELEASE_STATUS_METADATA=true`.

## Stale page HTML cleanup

When an existing TEI item is reprocessed via an `ObjectCreated` event, the Lambda reconciles page HTML in the destination bucket after uploading current outputs.

- Page HTML objects for the current item that are no longer present in the current build are deleted from the destination bucket.
- This cleanup applies only to page HTML (`html/{item-path}/{item}-*.html`) for the current item.
- Non-HTML outputs (`json`, `solr-json`, `dp-json`, `core-xml`, `page-xml`, `items`) and page HTML for other items are not affected.
- If the current build produces no page HTML for the item, all existing page HTML for that item is removed.
- If the upload step fails, stale-page reconciliation does not run.

## Building the container for the ECR.

Log into AWS in your shell and have your credentials stored in `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_SESSION_TOKEN`. Then, run the following commands:

    $ cd aws-lambda-docker
    $ aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 563181399728.dkr.ecr.eu-west-1.amazonaws.com
    $ docker build -t cudl-tei-processing --platform linux/amd64 .
    $ docker tag cudl-tei-processing:latest 563181399728.dkr.ecr.eu-west-1.amazonaws.com/cudl-tei-processing:latest
    $ docker push 563181399728.dkr.ecr.eu-west-1.amazonaws.com/cudl-tei-processing:latest

## Tests

The test suite checks that:

- each JSON file is syntactically valid
- links to transcripts within the JSON resolve to an existing html file 
- each html file is pointed to by links within the JSON

Run the tests locally using:

    ant -buildfile bin/test.xml
    
This command initiates a full build of the transcripts and json before running the tests. If you have already built the transcripts and json and wish only to run the tests, use:

    ant -buildfile bin/build.xml "tests-only"
    
The results of the test are written to ./test.log
