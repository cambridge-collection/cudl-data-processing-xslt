#! /bin/sh

# The lambda cannot write to /opt/cdcp without changing user permissions and, possibly ownership
# The buildfile is currently configured to work out paths for resources relative to the buildfile's
# position within the repository. Unfortunately, the lambda cannot write to /opt/cdcp - perhaps irrespective of
# permission/owner changes. Instead, we have to work out of tmp
# Instead of going that route, copy the bin and xslt dirs into tmp and run that buildfile

function clean_source_workspace() {
	echo "$1" 1>&2 &&
		rm -rf "/tmp/opt/cdcp/cudl-data-source" 1>&2 &&
		mkdir -p "/tmp/opt/cdcp/cudl-data-source" 1>&2 &&
		echo "$1 finished" 1>&2
}

echo "Populating working dir with essentials" 1>&2
cp -r /opt/cdcp/bin /tmp/opt/cdcp 1>&2
cp -r /opt/cdcp/xslt /tmp/opt/cdcp 1>&2

function handler() {
	set -a
	# Set defaults for env vars that are unlikely to change.
	: "${SEARCH_PORT:=}"
	: "${SEARCH_COLLECTION_PATH:=collections}"
	: "${ANT_TARGET:=full}"
	set +a

	echo "Parsing event notification" 1>&2
	echo "$1" 1>&2

	EVENTNAME=$(echo "$1" | jq -r '.Records[].body' | jq -r '.Records[].eventName') 1>&2
	S3_BUCKET=$(echo "$1" | jq -r '.Records[].body' | jq -r '.Records[].s3.bucket.name') 1>&2
	TEI_FILE=$(echo "$1" | jq -r '.Records[].body' | jq -r '.Records[].s3.object.key') 1>&2

	if [[ -n "${AWS_OUTPUT_BUCKET-}" && -n "${SEARCH_HOST-}" && -n "$S3_BUCKET" && -n "$TEI_FILE" ]]; then
		if [[ "$EVENTNAME" =~ ^ObjectCreated ]]; then

			echo "Requested file: s3://${S3_BUCKET}/${TEI_FILE}" 1>&2
			clean_source_workspace "Removing previous builds from workspace" &&
				echo "Downloading s3://${S3_BUCKET}/${TEI_FILE}" 1>&2
			aws s3 cp --quiet s3://${S3_BUCKET}/${TEI_FILE} /tmp/opt/cdcp/cudl-data-source/${TEI_FILE} 1>&2 &&
				echo "Processing ${TEI_FILE}" 1>&2
			(/opt/ant/bin/ant -buildfile /tmp/opt/cdcp/bin/build.xml $ANT_TARGET -Dfiles-to-process=$TEI_FILE) 1>&2 &&
				clean_source_workspace "Cleaning temporary workspace" &&
				echo "Processing of s3://${S3_BUCKET}/${TEI_FILE} finished" 1>&2
		elif [[ "$EVENTNAME" =~ ^ObjectRemoved ]]; then
			echo "Removing all outputs for: s3://${S3_BUCKET}/${TEI_FILE} on s3://${AWS_OUTPUT_BUCKET}" 1>&2
			FILENAME=$(basename $TEI_FILE ".xml")
			CONTAINING_DIR=$(dirname "$TEI_FILE")
			HTML_INNER_PATH=$(echo $CONTAINING_DIR | sed -E 's/^items\///g')
			aws s3 rm s3://${AWS_OUTPUT_BUCKET} --recursive --exclude "*" --include "**/${FILENAME}.json" --include "html/${HTML_INNER_PATH}/${FILENAME}-*.html" --include "page-xml/${CONTAINING_DIR}/${FILENAME}-*.xml" --include "core-xml/${TEI_FILE}" --include "${TEI_FILE}" 1>&2 &&
				echo "All outputs of s3://${S3_BUCKET}/${TEI_FILE} removed from s3://${AWS_OUTPUT_BUCKET}" 1>&2
		else
			echo "ERROR: Unsupported event: ${EVENTNAME}" 1>&2
			return 1
		fi
	else
		if [[ ! -v "AWS_OUTPUT_BUCKET" ]]; then echo "ERROR: AWS_OUTPUT_BUCKET environment var not set or empty" 1>&2; fi
		if [[ ! -v "SEARCH_HOST" ]]; then echo "ERROR: SEARCH_HOST environment var not set or empty" 1>&2; fi
		if [[ ! -v "SEARCH_PORT" ]]; then echo "ERROR: SEARCH_PORT environment var not set or empty" 1>&2; fi
		if [[ ! -v "SEARCH_COLLECTION_PATH" ]]; then echo "ERROR: SEARCH_COLLECTION_PATH environment var not set or empty" 1>&2; fi
		if [[ ! -v "ANT_TARGET" ]]; then echo "ERROR: ANT_TARGET environment var not set or empty" 1>&2; fi
		if [[ -z "$S3_BUCKET" ]]; then echo "ERROR: Problem parsing event json for S3 Bucket or empty" 1>&2; fi
		if [[ -z "$TEI_FILE" ]]; then echo "ERROR: Problem parsing event json for TEI filename or empty" 1>&2; fi
		return 1
	fi
}
