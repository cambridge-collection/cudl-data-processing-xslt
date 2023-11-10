<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:cudl="http://cudl.lib.cam.ac.uk/xtf/" 
    xmlns:json="http://www.w3.org/2005/xpath-functions"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
    xmlns="http://www.w3.org/2005/xpath-functions"
    exclude-result-prefixes="#all">
    
    <xsl:output method="xml" encoding="UTF-8" indent="no"/>
    
    <xsl:param name="path_to_buildfile" as="xsd:string*" required="no"/>
    <xsl:param name="collection_xml_dir" as="xsd:string*" required="yes" />
    
    <xsl:variable name="clean_collection_xml_dir" select="cudl:path-to-directory($collection_xml_dir, $path_to_buildfile)"/>
    
    <xsl:variable name="fileID" select="substring-before(tokenize(document-uri(/), '/')[last()], '.xml')"/>
    
    <xsl:mode on-no-match="shallow-copy" />
    
    <xsl:template match="/json:map/json:array[@key='collection']">
        <xsl:call-template name="get-collection"/>
    </xsl:template>
    
    <xsl:template match="/json:map[not(json:array[@key='collection'])]">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates/>
            <xsl:call-template name="get-collection"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template name="get-collection">
        <xsl:message select="concat($clean_collection_xml_dir,'/', $fileID, '.xml')"/>
        
        <xsl:if test="doc-available(concat($clean_collection_xml_dir,'/', $fileID, '.xml'))">
            <xsl:apply-templates select="doc(concat($clean_collection_xml_dir,'/', $fileID, '.xml'))/*"/>
        </xsl:if>
    </xsl:template>
    
    <xsl:function name="cudl:path-to-directory" as="xsd:string">
        <xsl:param name="dir"/>
        <xsl:param name="build_dir"/>
        
        <xsl:variable name="directory" select="replace(normalize-space($dir),'/$','')"/>
        
        <xsl:choose>
            <xsl:when test="normalize-space($build_dir) !=''">
                <xsl:choose>
                    <xsl:when test="$directory != ''">
                        <xsl:choose>
                            <xsl:when test="matches($directory,'^/')">
                                <!-- directory is absolute path -->
                                <xsl:value-of select="$directory"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <!-- Directory is set in build file and relative to build file -->
                                <xsl:value-of select="replace(resolve-uri(concat(normalize-space($build_dir),'/',$directory)),'^file:','')"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$directory"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
</xsl:stylesheet>