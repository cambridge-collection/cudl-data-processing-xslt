# XSLT for item TEI -> JSON processing

The code in this repository is used for processing TEI item data into all the formats used by the Cambridge Digital Collections Platform, namely:

1. The `www` directory contains html files for every page transcription or translation along with associated UI resources (inline diagrams, css, javascript)
1. `collection-xml` contains collection information grouped by classmark
1. `core-xml` version of processed metadata (including html page files and collection information)
1. `json-viewer` contains the JSON files required for the viewer to function
1. `json-solr` contains the JSON files that contain the metadata and textual content for indexing in solr.

It's recommended that you use the Dockerised version to build the data, but it can be done locally or even within a CI system if you install the required prerequisites.

### Prerequisites

#### [ALL]: Add cudl-data-source and cudl-data-releases

Place the relevant environment's versions of cudl-data-source and cudl-data-releases at the root level of this repository.

**N.B:** If you are building using the Dockerised version, you **cannot** use symlinks for these items.

#### [LOCAL] Local Install Download and install
- Java JDK
- Saxon JAR (<https://www.saxonica.com/download/download_page.xml>)
- Apache Ant (<https://ant.apache.org/>)

#### [DOCKER]
- Docker [https://docs.docker.com/get-docker/]

### Building the data

#### Docker

`docker run -d  -v ./staging-cudl-data-releases:/opt/cdcp/cudl-data-releases -v ./staging-cudl-data-source:/opt/cdcp/cudl-data-source -v ./dist:/opt/cdcp/dist cdcp-data-build ant -buildfile /opt/cdcp/bin/build.xml`

**NB:** Whatever the releases, source and dist directories are called locally, it's **vital** that they map to `/opt/cdcp/cudl-data-releases` and `/opt/cdcp/cudl-data-source` and `/opt/cdcp/dist`a within the container.

#### Locally

Place Saxon's JAR on your CLASSPATH (*e.g.* `export CLASSPATH=/path/to/saxon-he-12.3.jar`)

`ant -buildfile bin/build.xml -Ddata.dir=$(pwd)/staging-cudl-data-source -Dcollection.json.dir=$(pwd)/staging-cudl-data-releases/collections -Ddist.dir=${pwd}/dist`

**N.B:** Absolute paths to these directories are required. Relative paths will not work.

### Ant Targets

If you run ant without specifying a target, it will build all the relevant resources in the output directory, namely: `collection-xml`, `www`, `core-xml`, `json-viewer`, `json-solr`

It is possible to call each discrete phase of the process, which, in order, are:

1. `collection-update` builds `collection-xml` into `./dist/collection-xml`
1. `transcripts` builds html page transcriptions/translations and associated resources into `./dist/www`
1. `core-xml` builds the core-xml metadata files into `./dist/core-xml` (**NB:** requires the results of collection-update and transcripts)
1. `viewer-json` builds the viewer json into `./dist/json-viewer` (**NB:** requires core-xml)
1. `solr-json` builds the solr json into `./dist/json-solr` (**NB:** requires json-solr)

Each phase requires the previous ones to have been completed successfully. However, these dependencies are not hard-coded into the build file so that they can be call independantly (say in an AWS Step function).

By default, ant will create all outputs for all the XML files contained within the source directory. You can, however, pass a file glob (or individual filename) to ant using `-Dfiles-to-process` so that only they are processed. For example, 

`ant -buildfile bin/build.xml -Ddata.dir=$(pwd)/staging-cudl-data-source -Dcollection.json.dir=$(pwd)/staging-cudl-data-releases/collections -Ddist.dir=${pwd}/dist -Dfiles-to-process=MS-ADD-04004.xml` will only process Newton’s Waste Book (Ms Add 4004).

`ant -buildfile bin/build.xml -Ddata.dir=$(pwd)/staging-cudl-data-source -Dcollection.json.dir=$(pwd)/staging-cudl-data-releases/collections -Ddist.dir=${pwd}/dist -Dfiles-to-process=MS-DAR*.xml` will only process Darwin manuscripts.
    
### Tests

The test suite checks that:

- each JSON file is syntactically valid
- links to transcripts within the JSON resolve to an existing html file 
- each html file is pointed to by links within the JSON

Run the tests locally using:

    ant -buildfile bin/test.xml
    
This command initiates a full build of the transcripts and json before running the tests. If you have already built the transcripts and json and wish only to run the tests, use:

    ant -buildfile bin/build.xml "tests-only"
    
The results of the test are written to ./test.log