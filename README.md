# XSLT for item TEI -> JSON processing

The code in this repository is used for processing TEI item data into all the formats used by the Cambridge Digital Collections Platform, namely:

1. The `www` directory contains html files for every page transcription or translation along with associated UI resources (inline diagrams, css, javascript)
1. `collection-xml` contains collection information grouped by classmark
1. `core-xml` contains the processed metadata (including html page files and collection information)
1. `json-viewer` contains the JSON files required for the viewer to function
1. `json-solr` contains the JSON files that contain the metadata and textual content for indexing in solr.
1. `json-dp` contains the JSON files that contain the metadata necessary for items to be processed in Cambridge University Library’s Digital Preservation pipeline.

The application is dockerised. There are two versions:

1. One that creates the development environment for testing the AWS Lambda implementation. This relies on a wide range of AWS infrastructure to function.
2. The other version runs off locally stored data files. This is the version that’s best suited for implementation within a CI/CD system or for running local builds.

## Prerequisites

- Docker [https://docs.docker.com/get-docker/].

## Instructions for running the AWS Lambda Development version locally

### Prerequisites

Environment variables with the necessary AWS credentials stored in the following variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_SECRET_ACCESS_KEY`.

All other environment variables necessary for CUDL are stored in `.env`.

### Building and running the container

`docker compose -f docker-compose-aws-dev.yml up --build`

**NB: ** This `docker-compose-aws-dev.yml` must not be used when building the container for deployment within AWS. Instead, follow the instructions below.

### Processing a file

The AWS Lambda responds to SNS messages. To transform a file, you need to submit a JSON file with the SNS structure with a `POST` request to `http://localhost:9000/2015-03-31/functions/function/invocations`:

`curl -X POST -H 'Content-Type: application/json' 'http://localhost:9000/2015-03-31/functions/function/invocations' --data-binary "@./sample/sns-tei-source-change.json"`

Assuming you have the required permissions to access the resources, this container will create all the necessary outputs and, if successful, copy them to their S3 bucket destinations.

## Instructions for running the non-AWS container

### Prerequisites

Two directories at the root level of the repository:

* `staging-cudl-data-source`, which contains the source data for your collection. This can be copied from the relevant S3 source bucket.
* `dist`, which will contain the finished outputs.

### Building the container and processing data

The non-AWS version automatically processes the requested file(s) when the container is mounted.

You must first specify the file you want to process in the environment variable called `TEI_FILE`. This contains the path to the source file, relative to the root of the `staging-cudl-data-source`. 

To process MS-ADD-03975:

```
export TEI_FILE=items/data/tei/MS-ADD-03975/MS-ADD-03975.xml
docker compose -f docker-compose-local.yml up --build
```

`TEI_FILE` also accepts wildcards. If the environment variable is not set, it will assume that you want to process all files (**/*.xml) in `staging-cudl-data-source`. The following will rebuild files for MS-ADD-04000 to MS-ADD-04009:

```
export TEI_FILE=items/data/tei/**/MS-ADD-0400*.xml
docker compose -f docker-compose-local.yml up --build
```

**NB: ** You cannot pass multiple files (with paths) to the container. It only accepts a single file or wildcards.

## Building the container for the ECR.

1. Log into AWS in your shell
2. `cd aws-lambda-docker`
3. Run the following commands

```
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 563181399728.dkr.ecr.eu-west-1.amazonaws.com
docker build -t cudl-tei-processing --platform linux/amd64 .
docker tag cudl-tei-processing:latest 563181399728.dkr.ecr.eu-west-1.amazonaws.com/cudl-tei-processing:latest
docker push 563181399728.dkr.ecr.eu-west-1.amazonaws.com/cudl-tei-processing:latest
```

## Ant Targets

If you run ant without specifying a target, it will build all the relevant resources in the output directory, namely: `collection-xml`, `www`, `core-xml`, `json-viewer`, `json-solr`, and `json-dp`.

It is possible to call each phase of the process, which, in order, are:

1. `collection-update` builds `collection-xml` into `./dist/collection-xml`
1. `transcripts` builds html page transcriptions/translations and associated resources into `./dist/www`
1. `metadata` builds the core-xml metadata files into `./dist/core-xml` (**NB:** requires the results of collection-update and transcripts)
1. `metadata-and-transcripts` builds the core-xml metadata files and transcripts into `./dist/core-xml` and `./dist/www`, respectively.
1. `viewer` builds the viewer json into `./dist/json-viewer` (**NB:** requires core-xml)
1. `solr` builds the solr json into `./dist/json-solr` (**NB:** requires core-xml)
1. `dp` builds the DP json into `./dist/json-dp` (**NB:** requires core-xml)
1. `json` builds all json outputs into `./dist/json-viewer`, `./dist/json-solr` and `./dist/json-dp` (**NB:** requires core-xml)

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