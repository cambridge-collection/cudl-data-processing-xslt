#!/usr/bin/env python3
import boto3
import shutil
import logging
import os
from botocore.exceptions import ClientError

s3bucket = "cudl-artefacts"
s3keyDir = "projects/cudl-data-processing/xslt/"


# Script creates a zip file from the xslt content, uploads to s3, creates a new layer version
# with that zip, and updates the latest version of the lambda to use that layer.
# NB: See publish_xslt_live.py to make the live version of the xslt live.
def main():

    # Get version number from file
    f = open("VERSION", "r")
    version = increment_ver(f.read())
    f.close()

    # zip up xslt
    # zip -r cudl-transform-xslt-<version_number>.zip xslt
    shutil.make_archive("cudl-transform-xslt-"+version, 'zip', ".", "xslt")
    zip_file = "cudl-transform-xslt-"+version+".zip"

    # upload to s3
    success = upload_file_s3(zip_file, s3bucket, s3keyDir+zip_file)

    if not success:
        raise Exception('Zipping Failed, aborting.')

    # update the version in file
    f = open("VERSION", "w")
    f.write(version)
    f.close()

    # Remove local zip file.
    os.remove(zip_file)

    print("Uploaded new version: "+s3bucket+"/"+s3keyDir+zip_file)


# upload to s3
# aws s3 cp cudl-transform-xslt.zip s3://cudl-artefacts/projects/cudl-data-processing/xslt/cudl-transform-xslt.zip
def upload_file_s3(file_name, bucket, object_name):
    # Upload the file
    s3_client = boto3.client('s3')
    try:
        response = s3_client.upload_file(file_name, bucket, object_name)
    except ClientError as e:
        logging.error(e)
        return False
    return True


def increment_ver(version):
    version = version.split('.')
    version[2] = str(int(version[2]) + 1)
    return '.'.join(version)


main()
