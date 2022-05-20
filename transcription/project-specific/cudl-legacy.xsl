<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
   xmlns:date="http://exslt.org/dates-and-times"
   xmlns:parse="http://cdlib.org/xtf/parse"
   xmlns:xtf="http://cdlib.org/xtf"
   xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:cudl="http://cudl.cam.ac.uk/xtf/"
   xmlns:xs="http://www.w3.org/2001/XMLSchema"
   xmlns="http://www.w3.org/1999/xhtml"
   extension-element-prefixes="date"
   exclude-result-prefixes="#all"
   xmlns:teix="http://www.tei-c.org/ns/Examples"
   xmlns:functx="http://www.functx.com"
   xmlns:mml="http://www.w3.org/1998/Math/MathML">
   
   <xsl:template match="tei:g" mode="#all">
      <!-- TODO: Figure out how to support old and support new fuller coding
                 with charDecls with a deprecated display version
      -->
      <xsl:choose>
         <xsl:when test=".='%'">
            <xsl:text>&#x25CE;</xsl:text>
         </xsl:when>
         <xsl:when test=".='@'">
            <xsl:text>&#x2748;</xsl:text>
         </xsl:when>
         <xsl:when test=".='$'">
            <xsl:text>&#x2240;</xsl:text>
         </xsl:when>
         <xsl:when test=".='bhale'">
            <xsl:text>&#x2114;</xsl:text>
         </xsl:when>
         <xsl:when test=".='ba'">
            <xsl:text>&#x00A7;</xsl:text>
         </xsl:when>
         <xsl:when test=".='&#x00A7;'">
            <xsl:text>&#x30FB;</xsl:text>
         </xsl:when>
         <xsl:otherwise>
            <i>
               <xsl:apply-templates mode="#current" />
            </i>
         </xsl:otherwise>
      </xsl:choose>
      
   </xsl:template>
   
   <!-- This old code for cb is a kludge to get small pseudo-tables to
       align a little better in MS-RGO-00014, 00005-00008
       It could probably be changed either to <space/> or if it were simple the entire
       construct could be changed to tables in the original
       By checking for the absence of elements, this template should ONLY fire
       for those deprecated uses.
-  -->
   <xsl:template match="tei:cb[not(@*)]" mode="#all">
      <span>
         <xsl:text disable-output-escaping="yes">&#160;&#160;&#160;&#160;&#160;</xsl:text>
         <xsl:apply-templates mode="#current" />
      </span>
   </xsl:template>
   
  <xsl:template  match="text()[$use_legacy_display eq true()]" mode="#all">
    <xsl:analyze-string select="." regex="(&#x00A7;|\^{{2,}}|_ _ _)">
      <xsl:matching-substring>
        <xsl:choose>
          <xsl:when test="matches(.,'&#x00A7;')">
            <xsl:text>&#x30FB;</xsl:text>
          </xsl:when>
          <xsl:when test="matches(.,'\^{2,}')">
            <xsl:text>&#160;&#160;&#160;</xsl:text>
          </xsl:when>
          <xsl:when test="matches(.,'_ _ _')">
            <xsl:text>&#x2014;&#x2014;&#x2014;</xsl:text>
          </xsl:when>
        </xsl:choose>
      </xsl:matching-substring>
      
      <xsl:non-matching-substring>
        <xsl:value-of select="."/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:template>
  
</xsl:stylesheet>