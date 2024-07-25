#! /bin/sh

set -a
# Set defaults for env vars that are unlikely to change.
: "${SEARCH_PORT:=}"
: "${SEARCH_COLLECTION_PATH:=collections}"
: "${ANT_TARGET:=full}"
set +a

cp -r /opt/cdcp/bin /tmp/opt/cdcp 1>&2
cp -r /opt/cdcp/xslt /tmp/opt/cdcp 1>&2

mkdir -p /tmp/opt/cdcp/dist-final &&
	mkdir -p /tmp/opt/cdcp/cudl-data-source &&
	/opt/ant/bin/ant -buildfile /tmp/opt/cdcp/bin/build.xml $ANT_TARGET -Dfiles-to-process=$TEI_FILE
