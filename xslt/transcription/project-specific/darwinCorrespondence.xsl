<?xml version="1.0"?>
<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:mml="http://www.w3.org/1998/Math/MathML"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:functx="http://www.functx.com"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:teix="http://www.tei-c.org/ns/Examples"
  xmlns:cudl="http://cudl.cam.ac.uk/xtf/"
  xmlns="http://www.w3.org/1999/xhtml"
  exclude-result-prefixes="#all">
  
  <xsl:template match="tei:ab[@type =('note-content','notenumber')]" mode="#all">
    <p class="{@type}">
      <xsl:apply-templates mode="#current"/>
    </p>
  </xsl:template>
  
  <!--<xsl:template match="tei:div[@type=('cdnotes','tnotes')]" mode="#all" />-->
  
  <!-- When exporting Darwin letters, convert all internal links to resources to absolute paths -->
  
  <xsl:template match="tei:opener/tei:salute|
    tei:opener/tei:placeName|
    tei:opener/tei:persName|
    tei:opener/tei:seg|
    tei:opener/tei:date" priority="1" mode="#all">
    <!-- @priority is needed since there's a conflict with //text//date in the main xslt
         This needs to be revisted at some point but until we have more transcriptions, it's unclear
         whether this template is a general one for all correspondence or just dcp-influenced transcriptions
    -->
    <p class="{string-join((normalize-space(@rend),normalize-space(local-name()))[normalize-space(.) !=''],' ')}">
      <xsl:apply-templates mode="#current"/>
    </p>
  </xsl:template>
  
  <xsl:template match="tei:pb[$project_name=('darwin correspondence project')]" mode="#all" priority="9"/>
  
</xsl:stylesheet>