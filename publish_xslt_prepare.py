#!/usr/bin/env python3
import boto3
import shutil
import logging
import os
from botocore.exceptions import ClientError

lambda_arn = "arn:aws:lambda:eu-west-1:247242244017:function:AWSLambda_CUDLPackageData_TEI_to_JSON"
layer_arn = 'arn:aws:lambda:eu-west-1:247242244017:layer:cudl-transform-xslt'
s3bucket = "cudl-artefacts"
s3key = "projects/cudl-data-processing/xslt/cudl-transform-xslt.zip"


# Script creates a zip file from the xslt content, uploads to s3, creates a new layer version
# with that zip, and updates the latest version of the lambda to use that layer.
# NB: See publish_xslt_live.py to make the live version of the xslt live.
def main():
    # zip up xslt
    # zip -r cudl-transform-xslt.zip xslt
    shutil.make_archive("cudl-transform-xslt", 'zip', ".", "xslt")

    # upload to s3
    success = upload_file_s3("cudl-transform-xslt.zip", s3bucket, s3key)

    if not success:
        raise Exception('Zipping Failed, aborting.')

    # Remove local zip file.
    os.remove("cudl-transform-xslt.zip")

    # publish layer
    response = publish_layer_version(s3bucket, s3key, layer_arn)

    if response is None:
        raise Exception('Publishing layer Failed, aborting.')

    print("Created New Layer Version: " + response["LayerVersionArn"])

    # Publish new version of lambda using this layer.
    response = publish_lambda_configuration(lambda_arn, response["LayerVersionArn"])

    if response is None:
        raise Exception('Publishing layer Failed, aborting.')

    print("Created new Lambda: " + response["FunctionArn"])
    print("Version: " + response["Version"])


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


# publish layer https://docs.aws.amazon.com/cli/latest/reference/lambda/publish-layer-version.html aws lambda
# publish-layer-version --layer-name "arn:aws:lambda:eu-west-1:247242244017:layer:cudl-transform-xslt:{VERSION}"
# --description "XSLT transforms for TEI to JSON"  \  --content "S3Bucket=cudl-artefacts,
# S3Key=projects/cudl-data-processing/xslt/cudl-transform-xslt.zip" \  --compatible-runtimes "Java 11"
# --compatible-architectures "x86_64"
def publish_layer_version(bucket, object_name, layer):
    client = boto3.client('lambda')
    try:
        response = client.publish_layer_version(
            CompatibleRuntimes=[
                'java11'
            ],
            Content={
                'S3Bucket': bucket,
                'S3Key': object_name,
            },
            Description='XSLT transforms for TEI to JSON',
            LayerName=layer
        )

    except ClientError as e:
        logging.error(e)
        return None

    return response


# publish new version of lambda using new layer
# https://docs.aws.amazon.com/cli/latest/reference/lambda/update-function-configuration.html
# aws lambda update-function-configuration --function-name
# "arn:aws:lambda:eu-west-1:247242244017:function:AWSLambda_CUDLPackageData_TEI_to_JSON" --layers
# "arn:aws:lambda:eu-west-1:247242244017:layer:cudl-transform-xslt:${VERSION}"
def publish_lambda_configuration(function_name, layer):
    client = boto3.client('lambda')
    try:
        response = client.update_function_configuration(
            FunctionName=function_name,
            Layers=[
                layer,
            ]
        )

    except ClientError as e:
        logging.error(e)
        return None
    return response


main()
