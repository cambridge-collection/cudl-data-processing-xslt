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
    <xsl:param name="dest_dir" as="xsd:string*" required="yes" /><!-- Point to the output directory -->
    <xsl:param name="data_dir" as="xsd:string*" required="yes" />
    
    <xsl:variable name="clean_dest_dir" select="cudl:path-to-directory($dest_dir,$path_to_buildfile)"/>
    
    <xsl:key name="filenames" match="json:map" use="json:string[@key='@id']"/>
    
    <xsl:template match="/*">
        <xsl:variable name="collection_information" as="document-node()">
            <xsl:document>
                <array xmlns="http://www.w3.org/2005/xpath-functions">
                <xsl:for-each select="uri-collection(concat($data_dir,'?select=*.json'))!unparsed-text(.)">
                    <xsl:copy-of select="json-to-xml(.)"/>
                </xsl:for-each>
            </array>
            </xsl:document>
        </xsl:variable>
        
        <xsl:for-each-group select="$collection_information/json:array/json:map" group-by="json:array[@key='items']/json:map/json:string[@key='@id']">
            <xsl:variable name="filename" select="replace(tokenize(current-grouping-key(),'/')[last()], '\.json$', '')"/>
            <xsl:result-document href="{concat($clean_dest_dir, '/', $filename, '.xml')}">
                <map>
                    <array key="collection">
                        <xsl:for-each select="current-group()/json:map[@key='name']">
                            <string>
                                <xsl:value-of select="cudl:get-collection-name(.)"/>
                            </string>
                        </xsl:for-each>
                    </array>
                    <xsl:for-each select="current-group()">
                        <xsl:variable name="count" select="key('filenames', current-grouping-key(), json:array[@key='items'])/count(preceding-sibling::*) + 1" />
                        <xsl:variable name="collection_name" select="cudl:get-collection-name(json:map[@key='name'])"/>
                        <json:string key="{replace($collection_name,'\s','_')}_sort">
                            <xsl:value-of select="format-number($count, '0000')"/>
                        </json:string>
                    </xsl:for-each>
                </map>
            </xsl:result-document>
        </xsl:for-each-group>
    </xsl:template>
    
    <xsl:function name="cudl:get-collection-name" as="xsd:string*">
        <xsl:param name="context"/>
        
        <xsl:value-of select="$context/(json:string[@key='full'], json:string[@key='short'])[normalize-space(.)][1]"/>
    </xsl:function>
    
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