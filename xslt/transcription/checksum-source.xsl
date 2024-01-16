<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.1" 
    xmlns:tei="http://www.tei-c.org/ns/1.0" 
    xmlns:teix="http://www.tei-c.org/ns/Examples"
    xmlns:util="http://cudl.lib.cam.ac.uk/xtf/ns/util"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" 
    exclude-result-prefixes="#all">
    
    <xsl:output method="xml" indent="no" encoding="UTF-8" />
    
    <xsl:param name="dest_dir" as="xs:string*" required="yes" /><!-- Point to the output directory -->
    <xsl:param name="data_dir" as="xs:string*" required="no" />
    <xsl:param name="path_to_buildfile" as="xs:string*" required="no"/>
    
    <xsl:variable name="repo.root" select="string-join(tokenize(replace(document-uri(doc('checksum-source.xsl')),'^file:',''),'/')[position() lt (last() - 3) ],'/')"/>
    <xsl:variable name="clean_dest_dir" select="util:path-to-directory($dest_dir,$path_to_buildfile)"/>
    <xsl:variable name="clean_data_dir" select="util:path-to-directory($data_dir,$path_to_buildfile)"/>
    
    <xsl:variable name="root_filename" select="replace(tokenize(document-uri(root(/)), '/')[position() eq last()],'\.xml$', '')" as="xs:string"/>
    <xsl:variable name="subpath" select="replace(string-join(tokenize(replace(document-uri(root(/)), concat($clean_data_dir,'/'), ''), '/')[position() lt last()],'/'), '^file:', '')"/>
    
    <xsl:template match="node() | @*" priority="-1" mode="#all">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="/">
        <xsl:result-document method="xml" encoding="UTF-8" indent="no" href="{concat($clean_dest_dir,'/', $root_filename, '/tei.xml')}">
            <xsl:apply-templates select="*"/>
        </xsl:result-document>
        
        <xsl:result-document method="xml" encoding="UTF-8" indent="no" href="{concat($clean_dest_dir,'/', $root_filename, '/text.xml')}">
            <xsl:apply-templates select="*" mode="text_only"/>
        </xsl:result-document>
    </xsl:template>
    
    <xsl:template match="/tei:TEI" mode="text_only">
        <xsl:apply-templates select="tei:text" mode="text_only"/>
    </xsl:template>
    
    <xsl:template match="/tei:teiCorpus">
        <xsl:message select="concat('ERROR: teiCorpus not suppored (', $root_filename, ')')"/>
    </xsl:template>
    
    <xsl:template match="comment()" priority="2" mode="#all">
        <xsl:comment>
            <xsl:value-of select="replace(.,'\s+', ' ')"/>
        </xsl:comment>
    </xsl:template>
    
    <xsl:template match="text()" priority="2" mode="#all">
        <xsl:choose>
            <xsl:when test="ancestor::*[@xml:space][1]/@xml:space='preserve'">
                <xsl:value-of select="."/>
            </xsl:when>
            <xsl:otherwise>
                <!-- Retain one leading space if node isn't first, has
	     non-space content, and has leading space.-->
                <xsl:if test="position()!=1 and matches(.,'^\s') and normalize-space()!=''">
                    <xsl:text> </xsl:text>
                </xsl:if>
                <xsl:value-of select="normalize-space(.)"/>
                <xsl:choose>
                    <!-- node is an only child, and has content but it's all space -->
                    <xsl:when test="last()=1 and string-length()!=0 and normalize-space()=''">
                        <xsl:text> </xsl:text>
                    </xsl:when>
                    <!-- node isn't last, isn't first, and has trailing space -->
                    <xsl:when test="position()!=1 and position()!=last() and matches(.,'\s$')">
                        <xsl:text> </xsl:text>
                    </xsl:when>
                    <!-- node isn't last, is first, has trailing space, and has non-space content   -->
                    <xsl:when test="position()=1 and matches(.,'\s$') and normalize-space()!=''">
                        <xsl:text> </xsl:text>
                    </xsl:when>
                </xsl:choose>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:function name="util:path-to-directory" as="xs:string">
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