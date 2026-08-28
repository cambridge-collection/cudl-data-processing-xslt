# Cambridge Digital Collection TEI Processing

The code in this repository is used for processing TEI item data into all the formats used by the Cambridge Digital Collections Platform, namely:

1. `core-xml` [*Optional*] contains the processed metadata (including html page files and collection information)
2. `dp-json` contains the JSON files that contain the metadata necessary for items to be processed in Cambridge University Library’s Digital Preservation pipeline.
3. `html` directory contains html files for every page transcription or translation along with associated UI resources (inline diagrams, css, javascript)
4. `items` [*Optional*] contains a copy of the original, unmodified, source TEI XML file.
5. `json` contains the JSON files required for the viewer to function
6. `page-xml` [*Optional*] contains TEI XML files for each individual page.
7. `solr-json` contains the JSON files that contain the metadata and textual content for indexing in solr.

The lambda is a python wrapper that receives S3 notifications that trigger an Apache Ant XSLT transformation build to create all the desired outputs. The python wrapper then uploads them to the destination bucket. It also removes any stale page HTML from that item when their pages are no longer part of the original source file. The lambda handles partial batch failures, distinguishes transient from permanent errors, emits structured JSON logs, and optionally attaches SHA-256 and release-status metadata to uploaded objects to skip unchanged files when copying to the destination bucket.

![Architecture diagram](docs/architecture.svg)

The application is dockerised. There are two versions:

1. One that creates the environment for running in an AWS Lambda, which relies on a wide range of AWS infrastructure to function.
2. The other version runs off locally stored data files. This is the version that’s best suited for implementation within a CI/CD system or for running local builds.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- Python 3.x (if running tests)

## Instructions for running the AWS Lambda Development version locally

### Prerequisites

Environment variables with the necessary AWS credentials stored in the following variables:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`

All other environment variables necessary for CUDL are stored in `.env`, such as the source and destination buckets.

### Running the AWS container locally

```bash
docker compose -f docker-compose-aws-dev.yml up --build
```

**NB:** This `docker-compose-aws-dev.yml` must not be used when building the container for deployment within AWS. Instead, follow the instructions below.

Set `LOG_LEVEL=DEBUG` in your `.env` file (or export it) for verbose output when debugging.

### Processing a file

The AWS Lambda responds to SQS messages. To transform a file, you need to submit a JSON file with the SQS structure with a `POST` request to `http://localhost:9000/2015-03-31/functions/function/invocations`:

```bash
curl -X POST \
  -H 'Content-Type: application/json' \
  'http://localhost:9000/2015-03-31/functions/function/invocations' \
  --data-binary "@./test/sns-tei-source-change.json"
```

Assuming you have the required permissions to access the resources, this container will create all the necessary outputs and, if successful, copy them to their S3 bucket destination.

**NOTE:** The lambda will attempt to download the item mentioned in the sample notification. You will consequently only be able to successfully run this lambda locally after you have successfully logged into AWS and stored your access keys (as above).

This information is coded in escaped JSON contained within the `body` property. If you search for ‘bucket’, you will find the name of the bucket (‘rmm98-sandbox-cudl-data-source’ at present) and the filename is stored within object key property (`items/data/tei/MS-ADD-03975/MS-ADD-03975.xml` at present). You will need to update these to buckets/items that exist and which you have access to.

## Instructions for running the local non-AWS container

### Prerequisites

Two directories at the root level of this repository:

* `data`, which contains the source data for your collection. This can be copied from the relevant S3 source bucket.
* `dist`, which will contain the finished outputs.

#### Optional: collection-membership lookups

The processor can enrich outputs with each item's collection membership by
querying a search service. This is **optional** and only happens when
`SEARCH_HOST` points at a reachable cudl-search — a remote instance, or a
local one for dev work.

To run it locally, check out the CUDL Solr and search API repositories
alongside this one (override the Solr location with `CUDL_SOLR_DIR` if your
layout differs):

```text
parent-directory/
├── cudl-data-processing-xslt/
├── cudl-solr/
└── cudl-search/
```

Then bring up the stack as described in
[Starting the local search infrastructure](#starting-the-local-search-infrastructure).

### Starting the local search infrastructure

Solr and the search API have a longer lifecycle than an individual XSLT build.
Their local Compose stack is owned by `cudl-search` and can run independently
of this processor. Start it once at the beginning of a development session:

```bash
docker compose \
  -f ../cudl-search/docker-compose-local-search.yml \
  up -d --build --wait
```

The search API is then available directly at <http://localhost>. For
example:

```bash
curl 'http://localhost/items?q=*'
```

Solr is available at <http://localhost:8983>. Its data persists in
`../cudl-solr/external-vol` when the infrastructure containers are stopped or
recreated.

The Solr image creates the CUDL cores and their configuration, but a fresh
instance does not contain collection or item-collection records. Seed the
indexes with the collections covering the items you intend to build — see the
[Search / Solr integration](#search--solr-integration) requirement on indexing
the released collection JSON before a build.

### Building the container and processing data

You must specify the file you want to process in the environment variable called `TEI_FILE` before you mount the container. This contains the path to the source file, relative to the root of the `./data`. This file will be processed as soon as the container is run.

Build the processing image the first time, and again after changing its
Dockerfile, Python code or dependencies:

```bash
docker compose -f docker-compose-local.yml build
```

The local `./aws-lambda-docker/bin` and `./aws-lambda-docker/xslt` directories are mounted into the processing
container. XSLT and Ant build-file changes therefore do not require an image
rebuild; just run a new disposable processing container.
 
To process MS-ADD-03975:

```bash
TEI_FILE=items/data/tei/MS-ADD-03975/MS-ADD-03975.xml \
  docker compose -f docker-compose-local.yml run --rm cudl-tei-processing
```

`TEI_FILE` also accepts wildcards. The following will rebuild files for MS-ADD-04000 to MS-ADD-04009:

```bash
TEI_FILE='items/data/tei/MS-ADD-0400*/MS-ADD-0400*.xml' \
  docker compose -f docker-compose-local.yml run --rm cudl-tei-processing
```

You cannot pass multiple files (with paths) to the container. It only accepts a single file or wildcards.

`TEI_FILE` is required by the local runner. To process all source XML files,
set it explicitly to `**/*.xml`.

Set `LOG_LEVEL=DEBUG` in your `.env` file (or export it) for verbose output when debugging.

Stop the search infrastructure at the end of the development session:

```bash
docker compose \
  -f ../cudl-search/docker-compose-local-search.yml \
  down
```

## Environment variables

The processing compose files inherit from `docker-compose-base.yml`, which loads a `.env` file. Variables marked **Lambda** are used when the container runs as an AWS Lambda. Variables marked **Local compose** only apply when running via `docker-compose-local.yml` or `docker-compose-aws-dev.yml`.

### AWS credentials (needed for local development work)

These are only needed when running the container locally against real AWS resources. In Lambda, the execution role provides credentials automatically.

| Variable | Default | Description |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | — | AWS access key. |
| `AWS_SECRET_ACCESS_KEY` | — | AWS secret key. |
| `AWS_SESSION_TOKEN` | — | Temporary session token (required when using SSO/assumed roles). |

### Core processing

| Variable | Default | Scope | Description |
|---|---|---|---|
| `AWS_OUTPUT_BUCKET` | `""` | Lambda | S3 bucket for processed outputs. **Required** for Lambda. |
| `ANT_TARGET` | `full` | Lambda, Local compose | Ant build target to execute. |
| `ENVIRONMENT` | — | Ant build | Set to `local` by both local compose files. Controls whether Ant copies outputs locally or to S3. |
| `TEI_FILE` | — | Local compose | Required path (relative to `./data`) of the TEI file to process. Accepts wildcards; use `**/*.xml` to process all source XML files. |
| `XSLT_FAIL_ON_ERROR` | `true` | Lambda, Local compose | Whether the XSLT transform should abort on error. Set to `false` when running bulk transformations locally. Otherwise a malformed TEI would cause the batch to fail entirely. |

### Search / Solr integration

Passed through to the XSLT stylesheets via the Ant build. These variables are used for lookups when indexing an item to determine which collection(s) it belongs to.

The lookup is optional: it only runs when `SEARCH_HOST` is set, and this applies equally to Lambda and local deployments. **When it is enabled**, the lookup reads collection records from the search index, so the released collection JSON for the collections covering an item must be indexed into Solr **before** that item is built. If the index is missing those records, the build produces no collection-membership information for the item.

| Variable | Default | Scope | Description |
|---|---|---|---|
| `SEARCH_HOST` | `""` | Lambda, Local compose | Hostname of the Solr/search service. **Required** for Lambda. Local compose defaults to `host.docker.internal`. |
| `SEARCH_PORT` | `""` | Lambda, Local compose | Port for the search service. |
| `SEARCH_COLLECTION_PATH` | `collections` | Lambda, Local compose | URL path segment for the collection endpoint. |

### Skip / feature flags

These flags disable individual processing or copy steps. They all default to options that replicate previous behaviour.

| Variable | Default (Lambda) | Default (Local compose) | Description |
|---|---|---|---|
| `SKIP_COPY_TEI_WEB_ASSETS` | `false` | `true` | Skip copying TEI web assets (CSS, fonts) to the output. |
| `SKIP_PAGE_XML_COPY` | — | `true` | Skip copying page XML files to the output destination. |
| `SKIP_CORE_XML_COPY` | — | `true` | Skip copying core XML files to the output destination. |
| `SKIP_TEI_FULL_COPY` | — | `false` | Skip copying the full original TEI files to the output. |

### Released / unreleased output partitioning

| Variable | Default | Scope | Description |
|---|---|---|---|
| `ENABLE_UNRELEASED_PARTITION` | `false` | Lambda, Local compose | Split items with `itemReleased=false` into an `unreleased/` subtree of the output, keeping released items in the top-level layout. |

**Behaviour:**

- When unset or `false` (default), partitioning is skipped and every item — released or not — is written to the released layout. This is the legacy behaviour.
- When `true`, the Ant build moves each unreleased item's artifacts (core-xml, JSONs, html, page-xml, tei-full) into `unreleased/<output-type>/...`, which the copy/sync steps carry through to `s3://<bucket>/unreleased/`. On a release-status flip, the Lambda deletes the item's outputs in the opposite location so a single copy remains.

### Per-object metadata and conditional uploads

When enabled, the Lambda attaches user-metadata to each uploaded S3 object and uses those metadata fields to skip unchanged uploads.

| Variable | Default | Scope | Description |
|---|---|---|---|
| `ENABLE_SHA_METADATA` | `false` | Lambda, Local compose | Attach `content-sha256` (hex SHA-256 of the file bytes) to each uploaded object. |
| `ENABLE_RELEASE_STATUS_METADATA` | `false` | Lambda, Local compose | Derive release status from the TEI via XPath and attach `release-status` (`released` or `draft`) to each uploaded object. |

**Behaviour:**

- When both flags are `false`, all outputs are uploaded unconditionally (original behaviour).
- If the destination object itself is missing, it is always uploaded regardless of flag state.
- When one or both flags are enabled, the Lambda compares only the enabled metadata fields against the destination object. The file is uploaded if:
  - the file is missing on the destination
  - any enabled field is missing or different on the destination
- If all enabled fields are present and match, the upload is skipped for that file.

### Embedded TEI SHA

This flag adds a top-level field (`teiSha256`) containing the TEI item's SHA-256 into the core-xml metadata file, which is then inherited by the downstream solr, viewer and digital preservation json files.

| Variable | Default | Scope | Description |
|---|---|---|---|
| `ENABLE_TEI_SHA_IN_CORE_XML` | `false` | Lambda, Local compose | Embed the hex SHA-256 of the source TEI bytes as a top-level `teiSha256` field in core-xml. The hash matches the `content-sha256` user-metadata that `ENABLE_SHA_METADATA` sets on `items/data/tei/<file>.xml` in the output bucket, so consumers can reconcile a derived JSON record against its source TEI without an extra `HEAD` call. It can also be used to track content changes in external systems consuming the data. |

**Behaviour:**

- When unset or set to `false` (default), nothing is computed and no `teiSha256` field appears in any output, preserving backwards-compatibility.
- When `true`, Ant's `<checksum>` task writes one `.sha256` sidecar per source TEI to a tmp directory. `msTeiPreFilter.xsl` reads its own file's sidecar via `unparsed-text()` during the transform and emits `teiSha256` at the top of core-xml. Sidecars are deleted once the transform completes. Per-file SHAs are emitted correctly for both single-file (Lambda; local with a concrete `TEI_FILE`) and wildcard (`TEI_FILE=items/data/tei/**/*.xml`) invocations. The flag is read directly by Ant — no Python orchestration is involved.

### Monitoring and logging

| Variable | Default | Scope | Description |
|---|---|---|---|
| `LOG_LEVEL` | `INFO` | Lambda, Local compose | Logging level for structured JSON logs (`DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`). When running locally at `INFO` level (the default), Ant's stdout is streamed directly to the terminal in real time. At other log levels, stdout is captured and processed through the structured logger. |
| `EMIT_EMF_METRICS` | `false` | Lambda | Emit [CloudWatch Embedded Metric Format](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Embedded_Metric_Format_Specification.html) metrics. |
| `LAMBDA_TIMEOUT_MARGIN_MS` | `5000` | Lambda | Milliseconds of execution time to reserve before the Lambda timeout, used to allow graceful shutdown. This will only be useful when the lambda has a batch size larger than 1. Before processing an item, the lambda checks how many ms remain until the lambda will be destroyed. If it is less than `LAMBDA_TIMEOUT_MARGIN_MS`, it will fail gracefully and return the unprocessed items as batch failures so they can be processed in a later batch. |

## Stale page HTML cleanup

When an existing TEI item is reprocessed via an `ObjectCreated` event, the Lambda reconciles page HTML in the destination bucket after uploading current outputs.

- Page HTML objects for the current item that are no longer present in the current build are deleted from the destination bucket.
- This cleanup applies only to page HTML (`html/{item-path}/{item}-*.html`) for the current item.
- Non-HTML outputs (`json`, `solr-json`, `dp-json`, `core-xml`, `page-xml`, `items`) and page HTML for other items are not affected.
- If the current build produces no page HTML for the item, all existing page HTML for that item is removed.
- If the upload step fails, stale-page reconciliation does not run.

## Building the container for the ECR

Log into AWS in your shell and have your credentials stored in `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_SESSION_TOKEN`. Then, run the commands specified by the container registry. Don't forget to add `--platform linux/amd64` when building the image itself.

## Tests

Tests use [pytest](https://docs.pytest.org/) and live in `aws-lambda-docker/tests/`.

To run the tests, you need to have python3 installed. If on OSX, I'd recommend using homebrew:

Install [Homebrew](https://brew.sh/) if you don't already have it:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Install the latest Python 3 and virtualenv:

```bash
brew update
brew install python@3
brew install virtualenv
```

Confirm the Homebrew Python is being used:

```bash
which python3
# Expected: /opt/homebrew/bin/python3.xx (Apple Silicon) or /usr/local/bin/python3.xx (Intel)
```

Where xx is the specific version number of your install of python3.

Create and activate a virtual environment:

```bash
virtualenv -p python3 venv
source venv/bin/activate
```

To run the unit tests:

```bash
cd aws-lambda-docker
pip install -e ".[dev]"
pytest
```

Integration tests (marked `integration`) require a running Docker daemon and are excluded by default. To include them:

```bash
pytest -m integration
```
