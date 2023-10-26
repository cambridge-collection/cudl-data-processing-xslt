# XSLT for item TEI -> JSON processing

This is used for processing TEI item data into JSON format for the cudl-viewer.
It is used in the cudl data processing workflow, as a layer on the lambda function that converts item data.

IT IS IMPORTANT THAT THE DIRECTORY STRUCTURE IS PRESERVED as this is referenced in the lambda code.

## Publishing the new XSLT 

First ensure that you have committed and pushed any changed to git.

Then install the required modules:

    pip install -r requirements.txt

To publish the version to s3 run the following script

Required: Python3.8, AWS credentials configured for use.

    python3 publish_xslt_to_s3.py

This script will zip up the xslt and uploads to s3.

Once done remember the commit the new version with

    git add VERSION
    git commit -m "Releasing new version"
    git push

Once complete you can deploy the new version by editing the configuration in
<https://github.com/cambridge-collection/cudl-terraform>

## Building locally using Apache ant:

### Prerequisites

#### Download and install
- Java JDK
- Saxon JAR (<https://www.saxonica.com/download/download_page.xml>)
- Apache Ant (<https://ant.apache.org/>)

#### Link the data 

Link a local checkout of the TEI data into the 'data' folder under the root level,
*e.g.*

    ln -s ~/projects/cudl-data-source/data/items data

### Building page extracts in dist

Page transcripts and json can be built locally using:

    ant -buildfile ./bin/build.xml
    
To only build transcripts use:

    ant -buildfile ./bin/build.xml "transcripts"

To only build json use:

    ant -buildfile ./bin/build.xml "json"
    
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