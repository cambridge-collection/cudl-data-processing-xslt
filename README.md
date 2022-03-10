# XSLT for item TEI -> JSON processing

This is used for processing TEI item data into JSON format for the cudl-viewer.
It is used in the cudl data processing workflow, as a layer on the lambda function that converts item data.

IT IS IMPORTANT THAT THE DIRECTORY STRUCTURE IS PRESERVED as this is referenced in the lambda code.

## Publishing the new XSLT 

There are two scripts provided that allow you to upload the new version of the XSLT to 
s3, and update the lambda processing functions to use these new conversions.

Required: Python3.8, AWS credentials configured for use.

    python3 publish_xslt_prepare.py

This script will zip up the xslt, upload to s3, create a new lambda layer from this code
and update the $LATEST version of AWSLambda_CUDLPackageData_TEI_to_JSON lambda function to use
this layer.  This means that the latest version of this function can be tested with the new 
code.

Once tested and ready to make live you can run the separate script:

    python3 publish_xslt_live.py

This script creates a new version of the AWSLambda_CUDLPackageData_TEI_to_JSON lambda function
and points the $LIVE alias at this version, so that it can be used by the live cudl
data processing.

