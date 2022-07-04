# XSLT for item TEI -> JSON processing

This is used for processing TEI item data into JSON format for the cudl-viewer.
It is used in the cudl data processing workflow, as a layer on the lambda function that converts item data.

IT IS IMPORTANT THAT THE DIRECTORY STRUCTURE IS PRESERVED as this is referenced in the lambda code.

## Publishing the new XSLT 

To publish the version to s3 run the following script

Required: Python3.8, AWS credentials configured for use.

    python3 publish_xslt_to_s3.py

This script will zip up the xslt and uploads to s3.

Once complete you can deploy the new version by editing the configuration in
https://github.com/cambridge-collection/cudl-terraform

## Building locally using ant:

### Prereqs

Install Ant

### Link the data 

Link a local checkout of the TEI data into the 'data' folder under the root level
e.g.

    ln -s ~/projects/cudl-data-source/data/items data

### Building page extracts in dist

Page transcripts and json can be built locally using:

    ant -noclasspath -buildfile ./bin/build.xml
    
To only build transcripts use:

    ant -noclasspath -buildfile ./bin/build.xml "transcripts"

To only build json use:

    ant -noclasspath -buildfile ./bin/build.xml "json"
    
### Tests

To test that all links to transcripts resolve to an existing html page transcription and that all html page transcriptions are pointed to by links in the json use:

    ant -noclasspath -buildfile bin/test.xml
    
This command will initiate a full build of both the transcripts and json. If you have already built the transcripts and json and wish to run the tests, use:

    ant -noclasspath -buildfile bin/build.xml "json"
    
The results of the test are written to ./test.log
    
**NB:** The test will currently crash in the presence of a syntactically invalid json file. This will be rectified shortly.