<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0" xmlns:local="local" xmlns:saxon="http://saxon.sf.net/" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="#all">
    <xsl:output method="text" encoding="UTF-8"/>
    
    <xsl:key name="item" match="//tei:item" use="normalize-space(.)"/>
    
    <xsl:template match="/">
        <xsl:variable name="json_links" select="doc('../../tmp/json-dump.xml')/tei:list" as="item()*"/>
        <xsl:variable name="page_files" select="doc('../../tmp/html-dump.xml')/tei:list" as="item()*"/>
        <xsl:text>PASSED: </xsl:text>
        <xsl:value-of select="local:commafy(count(distinct-values(($json_links//tei:item[@n][key('item', normalize-space(.), $page_files)]))))"/>
        <xsl:text>&#10;</xsl:text>
        <xsl:variable name="json_invalid_errors" select="distinct-values(($json_links//tei:item[@type='invalid']))"/>
        <xsl:variable name="json_link_errors" select="distinct-values(($json_links//tei:item[@n][not(key('item', normalize-space(.), $page_files))]))"/>
        <xsl:variable name="html_errors" select="distinct-values(($page_files//tei:item[not(key('item', normalize-space(.), $json_links))]))"/>
        <xsl:if test="count($json_link_errors) + count($html_errors) ne 0">
            <xsl:text>FAILED: </xsl:text>
            <xsl:value-of select="local:commafy(count($json_invalid_errors) + count($json_link_errors) + count($html_errors))"/>
            <xsl:text>&#10;</xsl:text>
            <xsl:call-template name="write_error_message">
                <xsl:with-param name="title" select="'Invalid JSON:'"/>
                <xsl:with-param name="error_items" select="$json_invalid_errors"/>
            </xsl:call-template>
            
            <xsl:call-template name="write_error_message">
                <xsl:with-param name="title" select="'HTML File mentioned in JSON missing:'"/>
                <xsl:with-param name="error_items" select="$json_link_errors"/>
            </xsl:call-template>
            
            <xsl:call-template name="write_error_message">
                <xsl:with-param name="title" select="'Link to HTML missing in JSON:'"/>
                <xsl:with-param name="error_items" select="$html_errors"/>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>
    
    <xsl:template name="write_error_message">
        <xsl:param name="title"/>
        <xsl:param name="error_items"/>
        
        <xsl:if test="count($error_items) gt 0">
            <xsl:text>&#10;</xsl:text>
            <xsl:value-of select="concat($title, ' ', local:commafy(count($error_items)))"/>
            <xsl:text>&#10;---------------------------------&#10;</xsl:text>
            <xsl:for-each select="$error_items">
                <xsl:sort select="."/>
                <xsl:value-of select="."/>
                <xsl:if test="position() ne last()">
                    <xsl:text>&#10;</xsl:text>
                </xsl:if>
            </xsl:for-each>
            <xsl:text>&#10;&#10;</xsl:text>
        </xsl:if>
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
    
    <xsl:function name="local:commafy" as="xs:string*">
        <xsl:param name="number"/>
        
        <xsl:value-of select="format-number($number,'###,###,###')"/>
    </xsl:function>
</xsl:stylesheet>