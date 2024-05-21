#! /bin/sh

# The lambda cannot write to /opt/cdcp without changing user permissions and, possibly ownership
# The buildfile is currently configured to work out paths for resources relative to the buildfile's
# position within the repository. Unfortunately, the lambda cannot write to /opt/cdcp - perhaps irrespective of
# permission/owner changes. Instead, we have to work out of tmp
# Instead of going that route, copy the bin and xslt dirs into tmp and run that buildfile

echo "Populating working dir with essentials" 1>&2
cp -r /opt/cdcp/bin /tmp/opt/cdcp 1>&2
cp -r /opt/cdcp/xslt /tmp/opt/cdcp 1>&2

function handler() {
	echo "Parsing event notification" 1>&2
	echo "$1" 1>&2

	CORE_XML_S3_DEST="${AWS_DIST_BUCKET}/core-xml"
	PAGE_XML_S3_DEST="${AWS_DIST_BUCKET}/page-xml"
	COLLECTION_XML_S3_SOURCE="${AWS_DIST_BUCKET}/collection-xml"

	S3_BUCKET=$(echo "$1" | jq -r '.Records[].body' | jq -r '.Records[].s3.bucket.name') 1>&2
	TEI_FILE=$(echo "$1" | jq -r '.Records[].body' | jq -r '.Records[].s3.object.key') 1>&2

	if [[ -v "AWS_DIST_BUCKET" && -v "SEARCH_HOST" && -v "SEARCH_PORT" && -v "SEARCH_COLLECTION_PATH" && -n "$S3_BUCKET" && -n "$TEI_FILE" ]]; then
		echo "Requested file: s3://${S3_BUCKET}/${TEI_FILE}" 1>&2
		FILENAME=$(basename "${TEI_FILE}")
		CONTAINING_DIR=$(dirname "${TEI_FILE}")

		# Download core-xml if regenerating downstream views
		[[ 'json solr dp viewer' =~ (^|[[:space:]])$ANT_TARGET($|[[:space:]]) ]] &&
			echo "Downloading core_xml for ${TEI_FILE}" 1>&2 &&
			aws s3 cp --quiet --recursive s3://${CORE_XML_S3_DEST}/${CONTAINING_DIR} ${CORE_XML_SOURCE}/${CONTAINING_DIR} 1>&2

		# Download page-xml if regenerating html
		[[ $ANT_TARGET = "html" ]] &&
			echo "Downloading page_xml for${TEI_FILE}" &&
			PAGE_XML_SUBDIR=$(dirname "${TEI_FILE}") &&
			aws s3 cp --quiet --recursive s3://${PAGE_XML_S3_DEST}/${CONTAINING_DIR} ${PAGE_XML_SOURCE}/${CONTAINING_DIR} 1>&2

		# Process requested file
		echo "Downloading s3://${S3_BUCKET}/${TEI_FILE}" 1>&2
		aws s3 cp --quiet s3://${S3_BUCKET}/${TEI_FILE} /tmp/opt/cdcp/cudl-data-source/${TEI_FILE} 1>&2 &&
			echo "Processing ${TEI_FILE}" 1>&2
		(/opt/ant/bin/ant -buildfile /tmp/opt/cdcp/bin/build.xml $ANT_TARGET -Dfiles-to-process=$TEI_FILE) 1>&2 &&
			echo "OK"
	else
		if [[ ! -v "AWS_DIST_BUCKET" ]]; then echo "ERROR: AWS_DIST_BUCKET environment var not set" 1>&2; fi
		if [[ ! -v "SEARCH_HOST" ]]; then echo "ERROR: SEARCH_HOST environment var not set" 1>&2; fi
		if [[ ! -v "SEARCH_PORT" ]]; then echo "ERROR: SEARCH_PORT environment var not set" 1>&2; fi
		if [[ ! -v "SEARCH_COLLECTION_PATH" ]]; then echo "ERROR: SEARCH_COLLECTION_PATH environment var not set" 1>&2; fi
		if [[ -z "$S3_BUCKET" ]]; then echo "ERROR: Problem parsing event json for S3 Bucket" 1>&2; fi
		if [[ -z "$TEI_FILE" ]]; then echo "ERROR: Problem parsing event json for TEI filename" 1>&2; fi
		return 1
	fi
}
