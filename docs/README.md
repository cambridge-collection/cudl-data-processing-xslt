# CDCP XSLT Transforms

The docker containers in `./sample-implementation` contain implementations of the basic XSLT transformation engine for [CDL's TEI Processing](https://cambridge-collection.github.io/tei-data-processing-overview). 

At present, there is only one container: `render-only`. This provides an MVP implementation that transforms a TEI file into HTML. The XSLT is not meant to be used for production as it only deals with the half dozen or so elements required to output a valid HTML document. However, it can be used as the basis for [rolling out your own implementations](#rolling-your-own-implementation).

The codebase for all containers can be run as either:

* an AWS lambda that responds to an SQS notification informing it of a file change to source file. The results are output into the S3 bucket defined by the `AWS_OUTPUT_BUCKET` environment variable. 
* a CI/CD or local build acting upon any number of items contained within the `sample-implementation/render-only/source` dir. The outputs are copied to `sample-implementation/render-only/out`.

## Prerequisites

- Docker [https://docs.docker.com/get-docker/].

## Instructions for running the AWS Lambda Development version locally

### Prerequisites

Environment variables with the necessary AWS credentials stored in the following variables:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SECRET_ACCESS_KEY`

You will also need to set an environment variable for `AWS_OUTPUT_BUCKET` in `.env`.

### Running the AWS container locally

All commands assume that you are in the root directory of your container, _e.g_: `./sample-implementation/render-only`.

    docker compose -f docker-sample-data.yml up --force-recreate --build cdcp-aws-dev


**DO NOT USE `docker-sample-data.yml` to build the container for deployment within AWS.** Instead, follow the instructions for [building the lambda for deployment in AWS](#building-the-lambda-for-deployment-in-aws).

### Processing a file

The AWS Lambda responds to SQS messages. To transform a file, you need to submit a JSON file with the SQS structure with a `POST` request to `http://localhost:9000/2015-03-31/functions/function/invocations`:

    curl -X POST -H 'Content-Type: application/json' 'http://localhost:9000/2015-03-31/functions/function/invocations' --data-binary "@./sample/tei-source-change.json"


**NOTE:** The lambda will attempt to download the item mentioned in the sample notification. You will consequently only be able to successfully run this lambda locally after you have successfully logged into AWS and stored your access keys (as above).

### Test Messages

There are test events for the removal of a resource (`sample-implementation/render-only/test/tei-source-removed.json`) as well as a testEvent (` sample-implementation/render-only/test/tei-source-testEvent.json`) that confirms it is able to respond appropriately to unsupported event types.

For these tests to run, you will need:

1. Source and destinations buckets that your shell has appropriate access to with your AWS credentials stored in env variables (as per above). The name of the destination bucket must be set in `AWS_OUTPUT_BUCKET`.
1. The source bucket should contain at least one TEI file.
1. Modify the test events so that they refer to those buckets and your TEI file. Replace `my-most-awesome-source-b5cf96c0-e114` with your source bucket's name. Replace `my_awesome_tei/sample.xml` with the `full/path/to/your/teifile.xml`.

## Instructions for running the local non-AWS container

### Prerequisites

All commands assume that you are in the root directory of your container, _e.g_: `./sample-implementation/render-only`.

Two directories at the same level as `./docker`  in the ./sample-implementation` directory:

* `source`, which contains the source data for your collection. The directory structure can be as flat or nested as you desire.
* `out`, which will contain the finished outputs.

### Building the container and processing data

You must specify the file you want to process in the environment variable called `TEI_FILE` before you mount the container. This contains the path to the source file, relative to the root of the `./source`. This file will be processed as soon as the container is run.

To process `my_awesome_tei/sample.xml`, you would run the following:

    export TEI_FILE=my_awesome_tei/sample.xml
    docker compose -f docker-sample-data.yml up --force-recreate --build cdcp-local


`TEI_FILE` also accepts wildcards. The following will transform both sample files:

    export TEI_FILE=**/*.xml
    docker compose -f docker-sample-data.yml up --force-recreate --build cdcp-local

You cannot pass multiple files (with paths) to the container. It only accepts a single file or wildcards.

If the `TEI_FILE` environment variable is not set, the container will assume that you want to process all files (**/*.xml) in `./data`.

## Building the lambda for deployment in AWS

_Instructions forthcoming._

## Rolling your own implementation

_Instructions forthcoming._
