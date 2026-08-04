<xsl:stylesheet version="3.0"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:cudl="http://cudl.lib.cam.ac.uk/xtf/" 
   xmlns:json="http://www.w3.org/2005/xpath-functions"
   exclude-result-prefixes="#all">
   
   <xsl:output method="text" indent="yes" encoding="UTF-8"/>
   
   <xsl:mode on-no-match="shallow-copy" />
   
   <xsl:template match="/">
      <xsl:variable name="result" as="item()">
         <xsl:apply-templates/>
      </xsl:variable>
      
      <xsl:value-of select="replace(xml-to-json($result, map{'indent': true()}), '\\/', '/')"/>
   </xsl:template>
   
   <xsl:template match="json:array[@key='collection']/json:map">
      <xsl:variable name="url-slug" select="normalize-space(json:string[@key='url-slug'][1])"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates/>
         <json:string key="type">
            <xsl:choose>
               <xsl:when test="contains($url-slug, '::')">child</xsl:when>
               <xsl:when test="../json:map/json:string[@key='url-slug'][starts-with(normalize-space(.), concat($url-slug, '::'))]">parent</xsl:when>
               <xsl:otherwise>flat</xsl:otherwise>
            </xsl:choose>
         </json:string>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="json:array[@key='collection']/json:map/json:string[@key = ('url-slug', 'name-short')]">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:value-of select="tokenize(normalize-space(.), '::')[last()]"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="json:map[@key = ('transcription_content', 'translation_content')]|
      json:boolean[@key = ('unpaginatedAdditionalPb', 'itemAppearsInMultipleCollections')]|
      json:number[@key='itemCollectionCount']|
      /json:map/json:string[@key='sourceTEI']"/>
  
</xsl:stylesheet>
