<?xml version="1.0"?>
<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:mml="http://www.w3.org/1998/Math/MathML"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:functx="http://www.functx.com"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:teix="http://www.tei-c.org/ns/Examples"
  xmlns:cudl="http://cudl.cam.ac.uk/xtf/"
  xmlns:np="http://www.newtonproject.sussex.ac.uk/ns/nonTEI"
  xmlns="http://www.w3.org/1999/xhtml"
  exclude-result-prefixes="#all">
  
  <xsl:template match="tei:ab[$project_name='mingana lewis'][normalize-space(@n)]" priority="1" mode="#all">
    <span class="verse_number">
      <strong><xsl:value-of select="@n"/></strong>
      <xsl:text>&#160;</xsl:text>
    </span>
    
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xsl:template match="text()[$project_name='mingana lewis'][matches(.,'=')][following-sibling::node()[1][self::tei:lb]]" priority="99" mode="#all">
    <xsl:value-of select="replace(., '=', '')"/>
  </xsl:template>
  
  <xsl:template match="tei:lb[$project_name='mingana lewis']" priority="99" mode="#all">
    <br/>
    <span class="line_number">
      <xsl:choose>
        <xsl:when test="@n castable as xs:integer and (@n mod 5 = 0)">
          <xsl:value-of select="@n"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>&#160;&#160;&#160;&#160;</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </span>
  </xsl:template>
  
  <xsl:template match="tei:unclear[$project_name='mingana lewis']" priority="1" mode="#all">
    <span class="Peru">
      <xsl:apply-templates mode="#current"/>
    </span>
  </xsl:template>
  
  <xsl:template match="tei:supplied[$project_name='mingana lewis']" priority="1" mode="#all">
    <xsl:variable name="css-classes" select="string-join(('supplied', tokenize(@reason,'\s+')[normalize-space(.)]), ' ')"/>
    <xsl:variable name="title_text">
      <xsl:choose>
        <xsl:when test="@reason='illegible'">
          <xsl:text>Illegible text</xsl:text>
        </xsl:when>
        <xsl:when test="@reason='lacuna'">
          <xsl:text>Lacunose text</xsl:text>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>
    <span class="{$css-classes}" title="{$title_text}">
      <xsl:apply-templates mode="#current"/>
    </span>
  </xsl:template>
  
  <xsl:template match="tei:app[$project_name='mingana lewis']" priority="1" mode="#all">
    <xsl:text>{</xsl:text>
    <xsl:apply-templates mode="#current"/>
    <xsl:text>}</xsl:text>
  </xsl:template>
  
  <xsl:template match="tei:rdg[$project_name='mingana lewis']" priority="1" mode="#all">
    <xsl:variable name="css-subclass" as="xs:string*">
      <xsl:choose>
        <xsl:when test="normalize-space(@type)='orig'">
          <xsl:text>original</xsl:text>
        </xsl:when>
        <xsl:when test="normalize-space(@type)='corr'">
          <xsl:text>correction</xsl:text>
        </xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:variable>
    
    <xsl:variable name="css-classes" select="string-join(('rdg', $css-subclass[normalize-space(.)]), ' ')"/>
    <span class="{$css-classes}">
      <xsl:apply-templates mode="#current"/>
    </span>
  </xsl:template>
  
</xsl:stylesheet>