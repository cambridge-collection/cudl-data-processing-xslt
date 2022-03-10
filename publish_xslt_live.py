#!/usr/bin/env python3
import logging

import boto3
from botocore.exceptions import ClientError

lambda_arn = "arn:aws:lambda:eu-west-1:247242244017:function:AWSLambda_CUDLPackageData_TEI_to_JSON"
live_alias = "LIVE"


# IMPORTANT: YOU MUST RUN publish_xslt_prepare FIRST.
# This makes the $LATEST version of he specified function $LIVE
# so that is the current version used for processing.
def main():
    # Create a new version of the function (using the new layer)
    response = lambda_publish_version()

    if response is None:
        raise Exception('Versioning Function Failed, aborting.')

    print("Created version of function: "+lambda_arn+" version: "+response["Version"])
    # Update alias to $LIVE
    update_alias(response["Version"])

    print("Version is now LIVE")


# update the alias for the lambda function so that $LIVE points at the $LATEST version.
def update_alias(version):
    client = boto3.client('lambda')
    try:
        response = client.update_alias(
            FunctionName=lambda_arn,
            Name=live_alias,
            FunctionVersion=version
        )
    except ClientError as e:
        logging.error(e)
        return None
    return response


def lambda_publish_version():
    client = boto3.client('lambda')
    try:
        response = client.publish_version(
            FunctionName=lambda_arn
        )
    except ClientError as e:
        logging.error(e)
        return None
    return response


main()
