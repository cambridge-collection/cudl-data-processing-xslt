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
   
   <xsl:template match="json:map[@key = ('transcription_content', 'translation_content')]| json:boolean[@key = 'unpaginatedAdditionalPb']"/>
  
</xsl:stylesheet>
