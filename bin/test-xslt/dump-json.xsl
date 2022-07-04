<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0" xmlns:local="local" xmlns:saxon="http://saxon.sf.net/" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="#all">
    <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
    
    <xsl:template match="/">
        
        <list>
            <xsl:for-each select="uri-collection('../../json/tei/?select=*.json;recurse=yes')!unparsed-text(.)" saxon:threads="9">
                <xsl:for-each select="local:convert-json-to-xml(.)//*:string[@key = ('transcriptionDiplomaticURL','translationURL')]">
                    <xsl:variable name="item" select="local:get-item-uri(.)"/>
                    <xsl:if test="$item[normalize-space(.)]">
                        <item n="{normalize-space(.)}">
                            <xsl:sequence select="$item"/>
                        </item>
                    </xsl:if>
                </xsl:for-each>
            </xsl:for-each>
        </list>
        
    </xsl:template>
    
    
    <xsl:function name="local:convert-json-to-xml" as="item()*">
        <xsl:param name="text" />
        
        <xsl:copy-of select="json-to-xml(replace($text, '^[^\{]+', ''))" />
        
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