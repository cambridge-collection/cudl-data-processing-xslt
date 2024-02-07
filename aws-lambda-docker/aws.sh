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
   TEI_FILE=$(echo "$1"|jq -r '.body')
   aws s3 cp s3://cudlnew-data-source/${TEI_FILE} /tmp/opt/cdcp/cudl-data-source/${TEI_FILE} 1>&2
   (/opt/ant/bin/ant -buildfile /tmp/opt/cdcp/bin/build.xml $ANT_TARGET -Dfiles-to-process=$TEI_FILE) 1>&2 \
     && echo "OK"
    }