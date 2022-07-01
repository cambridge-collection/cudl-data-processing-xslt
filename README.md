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

    ant -noclasspath -buildfile ./bin/build.xml