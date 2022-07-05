<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0" xmlns:local="local" xmlns:saxon="http://saxon.sf.net/" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="#all">
    <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
    
    <xsl:template match="/">
        <list>
            <xsl:for-each select="uri-collection('../../dist/tei/?select=*.html;recurse=yes')">
                <item>
                    <xsl:sequence select="replace(.,'^.*/dist/tei/','')"/>
                </item>
            </xsl:for-each>
        </list>
    </xsl:template>
    
</xsl:stylesheet>