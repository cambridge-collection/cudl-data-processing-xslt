#! /bin/sh

# The lambda cannot write to /opt/cdcp without changing user permissions and, possibly ownership
# The buildfile is currently configured to work out paths for resources relative to the buildfile's
# position within the repository. Unfortunately, the lambda cannot write to /opt/cdcp - perhaps irrespective of
# permission/owner changes. Instead, we have to work out of tmp
# Instead of going that route, copy the bin and xslt dirs into tmp and run that buildfile

echo "Populating working dir with essentials" 1>&2
cp -r /opt/cdcp/bin /tmp/opt/cdcp 1>&2
cp -r /opt/cdcp/xslt /tmp/opt/cdcp 1>&2

function handler () {
   #echo "$1" 1>&2
   TEI_FILE=$(echo "$1" | jq -r '.Records[].body'| jq -r '.Records[].s3.object.key') 1>&2
   echo "Requested file: ${TEI_FILE}" 1>&2

   FILENAME=$(basename "${TEI_FILE}");
   echo "Downloading collection info for ${FILENAME}" 1>&2;
   aws s3 cp --quiet s3://${COLLECTION_XML_S3_SOURCE}/${FILENAME} ${COLLECTION_XML_SOURCE}/${FILENAME} 1>&2

   CONTAINING_DIR=$(dirname "${TEI_FILE}")

   # Download core-xml if regenerating downstream views
   [[ 'json solr dp viewer' =~ (^|[[:space:]])$ANT_TARGET($|[[:space:]]) ]] \
   && echo "Downloading core_xml for ${TEI_FILE}" 1>&2 \
   && aws s3 cp --quiet --recursive s3://${CORE_XML_S3_DEST}/${CONTAINING_DIR} ${CORE_XML_SOURCE}/${CONTAINING_DIR} 1>&2 \

   # Download page-xml if regenerating html
   [[ $ANT_TARGET = "html" ]] \
   && echo "Downloading page_xml for${TEI_FILE}" \
   && PAGE_XML_SUBDIR=$(dirname "${TEI_FILE}") \
   && aws s3 cp --quiet --recursive s3://${PAGE_XML_S3_DEST}/${CONTAINING_DIR} ${PAGE_XML_SOURCE}/${CONTAINING_DIR} 1>&2

   echo "Downloading ${TEI_FILE}" 1>&2
   aws s3 cp --quiet s3://${AWS_DATA_SOURCE_BUCKET}/${TEI_FILE} /tmp/opt/cdcp/cudl-data-source/${TEI_FILE} 1>&2 \
    && echo "Processing ${TEI_FILE}" 1>&2
   (/opt/ant/bin/ant -buildfile /tmp/opt/cdcp/bin/build.xml $ANT_TARGET -Dfiles-to-process=$TEI_FILE) 1>&2 \
     && echo "OK"
    }