<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
   xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:xs="http://www.w3.org/2001/XMLSchema"
   xmlns="http://www.w3.org/1999/xhtml"
   exclude-result-prefixes="#all">
   
   <xsl:output method="html" indent="no" encoding="UTF-8" doctype-system="about:legacy-compat" omit-xml-declaration="yes"/>
   
   <xsl:template match="/*">
      <html>
         <xsl:apply-templates />
      </html>
   </xsl:template>
   
   <xsl:template match="tei:teiHeader">
      <head>
         <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
         <xsl:apply-templates select="tei:fileDesc/tei:titleStmt/tei:title"/>
      </head>
   </xsl:template>
   
   <xsl:template match="tei:fileDesc/tei:titleStmt/tei:title">
      <title>
         <xsl:apply-templates/>
      </title>
   </xsl:template>
   
   <xsl:template match="tei:text/tei:body">
      <body>
         <xsl:apply-templates/>
      </body>
   </xsl:template>
   
   <xsl:template match="tei:text//tei:div">
      <div>
         <xsl:apply-templates/>
      </div>
   </xsl:template>
   
   <xsl:template match="tei:text//tei:p">
      <p>
         <xsl:apply-templates/>
      </p>
   </xsl:template>
   
</xsl:stylesheet>
