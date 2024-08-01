<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.1" 
   xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:cudl="http://cudl.lib.cam.ac.uk/xtf/" 
   xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
   exclude-result-prefixes="#all"
   xmlns:lambda="http://cudl.lib.cam.ac.uk/lambda/"
   xmlns="http://www.tei-c.org/ns/1.0">
   
   <xsl:key name="language-names-by-code" match="//tei:language" use="@ident"/>
   
   <xsl:variable name="language_key" select="document('lib/language-codes/ISO-639-2.xml')"/>
   
   <xsl:function name="cudl:get-language-name" as="xsd:string*">
      <xsl:param name="code"/>
      
      <xsl:variable name="result" select="key('language-names-by-code', $code, $language_key)" as="xsd:string*"/>
      
      <xsl:choose>
         <xsl:when test="$result[normalize-space(.)]">
            <xsl:sequence select="$result[normalize-space(.)]"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="$code"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>
   
</xsl:stylesheet>