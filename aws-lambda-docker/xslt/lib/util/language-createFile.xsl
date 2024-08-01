<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.1" 
   xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:cudl="http://cudl.lib.cam.ac.uk/xtf/" 
   xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
   exclude-result-prefixes="#all"
   xmlns:lambda="http://cudl.lib.cam.ac.uk/lambda/"
   xmlns="http://www.tei-c.org/ns/1.0">
   
   <xsl:output method="xml" encoding="UTF-8" indent="yes"></xsl:output>
   
   <xsl:variable name="language_details" as="item()*">
      <langUsage>
         <xsl:variable name="lang_csv" select="unparsed-text('../lib/language-codes/ISO-639-2_utf-8.txt')"/>
         <xsl:for-each select="tokenize($lang_csv,'\n')">
            <xsl:variable name="tmp" select="tokenize(.,'\|')"/>
            <xsl:variable name="lang_codes" select="$tmp[position() ge 1 and position() le 3][normalize-space(.)]"/>
            <xsl:for-each select="$lang_codes">
               <language ident="{.}">
                  <xsl:value-of select="$tmp[position() eq 4]"/>
               </language>
            </xsl:for-each>
         </xsl:for-each>
      </langUsage>
   </xsl:variable>
   
   <xsl:key name="language_names" match="//*:language" use="tokenize(normalize-space(@code), '\s+')"/>
   
   <xsl:template match="/*">
      <langUsage>
         <xsl:copy-of select="$language_details"/>
      </langUsage>
   </xsl:template>
   
</xsl:stylesheet>