<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0" xmlns:local="local" xmlns:saxon="http://saxon.sf.net/" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="#all">
    <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
    
    <xsl:variable name="current_dir" select="concat(string-join(tokenize(document-uri(root(/)),'/')[position() lt last()],'/'),'/')" />
    <xsl:variable name="json_dir" select="'../../json/tei/'"/>
    
    <xsl:template match="/">
        <list>
            <xsl:for-each select="uri-collection('../../json/tei/?select=*.json;recurse=yes')" saxon:threads="9">
                <xsl:for-each select="local:convert-json-to-xml(.)//*:string[@key = ('transcriptionDiplomaticURL','translationURL') or @type='invalid']">
                    <xsl:choose>
                        <xsl:when test="@key">
                            <xsl:variable name="item" select="local:get-item-uri(.)"/>
                            <xsl:if test="$item[normalize-space(.)]">
                                <item n="{normalize-space(.)}">
                                    <xsl:sequence select="$item"/>
                                </item>
                            </xsl:if>
                        </xsl:when>
                        <xsl:otherwise>
                            <item type="invalid">
                                <xsl:value-of select="normalize-space(.)"/>
                            </item>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
            </xsl:for-each>
        </list>
        
    </xsl:template>
    
    
    <xsl:function name="local:convert-json-to-xml" as="item()*">
        <xsl:param name="file" />
        
        <xsl:try select="json-to-xml(replace(unparsed-text($file), '^[^\{]+', ''))" >
            <xsl:catch>
                <xsl:message>CRITICAL: <xsl:value-of select="$file"/> is invalid JSON</xsl:message>
                <xsl:variable name="full_path_to_json" select="resolve-uri($json_dir, $current_dir)"/>
                <error>
                    <string type="invalid">
                        <xsl:value-of select="replace(normalize-space($file), $full_path_to_json, '')"/>
                    </string>
                </error>
            </xsl:catch>
        </xsl:try>
        
    </xsl:function>
    
    <xsl:function name="local:get-item-uri" as="xs:string*">
        <xsl:param name="string"/>
        
        <xsl:if test="matches($string, '^(/v1/transcription/tei/diplomatic/internal/|/v1/translation/tei/[^/]+/)')">
            <xsl:variable name="type" as="xs:string*">
                <xsl:choose>
                    <xsl:when test="matches($string,'/v1/translation/tei/[^/]+/')">
                        <xsl:value-of select="'translation'"/>
                    </xsl:when>
                    <xsl:otherwise/>
                </xsl:choose>
            </xsl:variable>
            
            <xsl:variable name="classmark" select="tokenize(replace($string,'^(/v1/transcription/tei/diplomatic/internal/|/v1/translation/tei/[^/]+/)', ''),'/')[1]"/>
            <xsl:variable name="image_tokens" select="tokenize($string,'/')[position() gt index-of(tokenize($string,'/'), $classmark)]"/>
            <xsl:sequence select="concat(string-join(($classmark,string-join(($classmark, $image_tokens, $type)[normalize-space(.)],'-'))[normalize-space(.)],'/'),'.html')"/>
        </xsl:if>
    </xsl:function>
</xsl:stylesheet>