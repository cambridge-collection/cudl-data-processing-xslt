<xsl:stylesheet version="3.0"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:cudl="http://cudl.lib.cam.ac.uk/xtf/" 
   xmlns:json="http://www.w3.org/2005/xpath-functions"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" 
   exclude-result-prefixes="#all">
   
   <xsl:output method="text" indent="yes" encoding="UTF-8"/>
   
   <xsl:mode on-no-match="shallow-copy" />
   
   <xsl:template match="/json:map">
      <xsl:variable name="result" as="item()">
         <xsl:copy>
            <xsl:apply-templates select="json:array[@key='descriptiveMetadata']/json:map[1]"/>
         </xsl:copy>
      </xsl:variable>
      
      <xsl:value-of select="replace(xml-to-json($result, map{'indent': true()}), '\\/', '/')"/>
   </xsl:template>
   
   <xsl:template match="/json:map/json:array[@key='descriptiveMetadata']/json:map[1]">
      
      <json:string key="cam:restriction">
         <xsl:text>access_closed</xsl:text>
      </json:string>
      
      <json:string key="filename">
         <xsl:value-of select="replace(tokenize(document-uri(/), '/')[last()], '\.xml', '', 'i')"/>
      </json:string>
      
      <xsl:apply-templates select="json:map[@key='abstract']"/>
      <xsl:apply-templates select="json:map[@key='shelfLocator']"/>
      <xsl:apply-templates select="json:map[@key='publications']"/>
      <xsl:apply-templates select="json:map[@key='title']"/>
      <xsl:apply-templates select="json:map[@key='authors']"/>
      <xsl:apply-templates select="json:map[@key='subjects']"/>
      <xsl:call-template name="get_rights"/>
      <xsl:call-template name="get_license"/>
      
      <json:string key="Source">
         <xsl:text>Cambridge University Digital Library</xsl:text>
      </json:string>
      
      <json:string key="collectionDirectorate">
         <xsl:text>Digital Initiatives</xsl:text>
      </json:string>
      
      <json:string key="collectionName">
         <xsl:text>Research Outputs</xsl:text>
      </json:string>
      
      <json:string key="type">
         <xsl:text>TEI XML</xsl:text>
      </json:string>
      
      <json:string key="collectionType">
         <xsl:text>CUDL Item</xsl:text>
      </json:string>
      
      <json:string key="collectingArea">
         <xsl:text>Cambridge University Digital Library</xsl:text>
      </json:string>
      
      <json:string key="researchProject">
         <xsl:text/>
      </json:string>
      
      <json:string key="collectingSource">
         <xsl:text>Cambridge University Digital Library</xsl:text>
      </json:string>
      
      <json:string key="collectingBody">
         <xsl:text>Cambridge University Library</xsl:text>
      </json:string>
      
         <json:boolean key="CopyToPreservation">
         <xsl:value-of select="true()"/>
      </json:boolean>     
      
   </xsl:template>
   
   <xsl:variable name="target_keys" select="('abstract', 'title', 'shelfLocator', 'publishers', 'subjects', 'authors')"/>
   <!-- Keys that currently are always maps containing a single string:
      abstract
      shelfLocator
      title
   -->
   
   <!-- Does the target just contain a single displayForm string? -->
   <xsl:template match="json:map[@key=$target_keys][not(json:array[@key='value'])][json:string[@key='displayForm']]">
      <json:string key="{cudl:get-key-name(@key)}">
         <xsl:value-of select="normalize-space(json:string[@key='displayForm'])"/>
      </json:string>
   </xsl:template>
   
   <!-- Does the target contain a value array of maps with displayForm strings? -->
   <xsl:template match="json:map[@key=$target_keys][json:array[@key='value'][json:map[json:string[@key='displayForm'][normalize-space(.)]]]]">
      <json:array key="{cudl:get-key-name(@key)}">
         <xsl:apply-templates select="json:array[@key='value']"/>
      </json:array>
   </xsl:template>
   
   <!-- Does the target contain an empty value array -->
   <xsl:template match="json:map[@key=$target_keys][json:array[@key='value'][not(json:map[json:string[@key='displayForm'][normalize-space(.)]])]]"/>
   
   <xsl:template match="json:map[@key='publications']">
      <xsl:apply-templates select="json:array[@key='value']/json:map/json:map[@key='publishers']"/>
   </xsl:template>
   
   <xsl:template match="json:map[@key='publisher']">
      <json:array key="{cudl:get-key-name(@key)}">
         <xsl:apply-templates select="json:array[@key='value']/json:map"/>
      </json:array>
   </xsl:template>
   
   <xsl:template match="json:array[@key='value'][json:map[json:string[@key='displayForm']]]">
      <xsl:for-each select="json:map">
         <xsl:apply-templates select="json:string[@key='displayForm']"/>
      </xsl:for-each>
   </xsl:template>
   
   <xsl:template match="json:array[@key='value'][json:string[@key='displayForm']]">
      <xsl:for-each select="json:string[@key='displayForm']">
         <xsl:value-of select="normalize-space(.)"/>
      </xsl:for-each>
   </xsl:template>
   
   <xsl:template match="json:string[@key='displayForm']">
      <json:string>
         <xsl:value-of select="normalize-space(.)"/>
      </json:string>
   </xsl:template>
   
   <xsl:template name="get_rights">
      <!-- What do if none? -->
      <json:string key="rights">
         <xsl:value-of select="normalize-space(string-join(json:string[@key = ('metadataRights','transcriptionRights')][normalize-space(.)], ' '))"/>
      </json:string>
   </xsl:template>
   
   <xsl:template name="get_license">
      <!-- What do if none? -->
      <json:string key="license">
         <xsl:value-of select="normalize-space(string-join(json:string[@key = ('metadataRights','transcriptionRights')][normalize-space(.)], ' '))"/>
      </json:string>
   </xsl:template>
   
   <xsl:function name="cudl:get-key-name" as="xs:string">
      <xsl:param name="key" as="xs:string"/>
      
      <xsl:variable name="result" as="xs:string">
         <xsl:choose>
            <xsl:when test="$key = 'authors'">
               <xsl:sequence select="'creator'"/>
            </xsl:when>
            <xsl:when test="$key = 'shelfLocator'">
               <xsl:sequence select="'identifier'"/>
            </xsl:when>
            <xsl:when test="$key = 'publishers'">
               <xsl:sequence select="'publisher'"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:sequence select="$key"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      
      <xsl:value-of select="normalize-space($result)"/>
   </xsl:function>
   
   <xsl:function name="cudl:write-displayForm" as="item()*">
      <xsl:param name="key-name"/>
      <xsl:param name="nodes"/>
      
      <xsl:choose>
         <xsl:when test="count($nodes) gt 1">
            <json:array key="{$key-name}">
               <xsl:for-each select="$nodes">
                  <json:string>
                     <xsl:value-of select="."/>
                  </json:string>
               </xsl:for-each>
            </json:array>
         </xsl:when>
         <xsl:otherwise>
            <xsl:for-each select="$nodes">
               <json:string key="{$key-name}">
                  <xsl:value-of select="."/>
               </json:string>
            </xsl:for-each>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>
</xsl:stylesheet>