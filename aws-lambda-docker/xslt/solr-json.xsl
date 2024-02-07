<xsl:stylesheet version="3.0"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:cudl="http://cudl.lib.cam.ac.uk/xtf/" 
   xmlns:json="http://www.w3.org/2005/xpath-functions"
   xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
   exclude-result-prefixes="#all">
   
   <xsl:output method="text" indent="no" encoding="UTF-8"/>
   
   <xsl:key name="keys" match="json:array[@key='descriptiveMetadata']/json:map[1]//json:*[normalize-space(@key)]" use="@key"/>
   
   <xsl:mode on-no-match="shallow-copy" />
   
   <xsl:variable name="data_obj_excluded" select="('dataRevisions')"/>
   
   <xsl:template match="/">
      <xsl:variable name="result" as="item()">
         <xsl:apply-templates/>
      </xsl:variable>
      
      <xsl:value-of select="replace(xml-to-json($result, map{'indent': true()}), '\\/', '/')"/>
   </xsl:template>
   
   <xsl:template match="/json:map">
      <xsl:copy>
         <!--<xsl:variable name="nodes-to-flatten" select="key('part_metadata','DOCUMENT')[1]//json:map[normalize-space(@key)][not(descendant::json:map[normalize-space(@key)])][descendant::json:string[@key='displayForm']][not(@key=$data_obj_excluded)]" as="item()*"/>
         <xsl:message select="concat('Ignore objects ',string-join(@key, ', '))"/>-->
         <xsl:apply-templates select="json:array[@key='descriptiveMetadata']/json:map[1]//json:array[@key='century']" mode="flatten"/>
         <xsl:copy-of select="json:array[@key='descriptiveMetadata']/json:map[1]//json:string[@key=('yearStart', 'yearEnd')]"/>
         <xsl:apply-templates select="*"/>
      </xsl:copy>
   </xsl:template>
   
   <xsl:key name="logical_structure" match="json:array[@key='logicalStructures']//json:map[normalize-space(json:string[@key = 'startPageID'])]" use="json:string[@key = 'startPageID']"/>
   
   <xsl:key name="part_metadata" match="json:array[@key='descriptiveMetadata']/json:map[not(normalize-space(@key))][normalize-space(json:string[@key = 'ID'])]" use="json:string[@key = 'ID']"/>
   
   <xsl:template match="json:array[@key='pages']/json:map">
      <xsl:copy>
         <xsl:choose>
            <xsl:when test="not(json:boolean[@key='unpaginatedAdditionalPb'][. = 'false'])">
               <xsl:apply-templates select="*[not(@key = 'unpaginatedAdditionalPb')]"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:apply-templates select="*[not(@key = ('unpaginatedAdditionalPb', 'transcription_content','translation_content'))]"/>
            </xsl:otherwise>
         </xsl:choose>
         
         <!-- Get part metadata based on json:string[@key='physID'] -->
         <xsl:variable name="logical_structure" select="key('logical_structure', json:string[@key='physID'])[1]" as="item()*"/>
         <xsl:variable name="part_num" select="$logical_structure/json:string[@key='descriptiveMetadataID']"/>
         <xsl:choose>
            <xsl:when test="exists($logical_structure)">
               <xsl:variable name="part_metadata" select="key('part_metadata', $part_num)"/>
               <xsl:apply-templates select="$part_metadata[1]//json:map[normalize-space(@key)][not(descendant::json:map[normalize-space(@key)])][descendant::json:string[@key='displayForm']]" mode="flatten"/>
               
               <xsl:choose>
                  <xsl:when test="$part_metadata[1]//json:array[@key='century']">
                     <xsl:apply-templates select="$part_metadata[1]//json:array[@key='century']" mode="flatten"/>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:apply-templates select="/json:map/json:array[@key='descriptiveMetadata']/json:map[1]//json:array[@key='century']" mode="flatten"/>
                  </xsl:otherwise>
               </xsl:choose>
               
               <xsl:choose>
                  <xsl:when test="$part_metadata[1]//json:string[@key=('yearStart','yearEnd')]">
                     <xsl:copy-of select="$part_metadata[1]//json:string[@key=('yearStart','yearEnd')]"/>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:copy-of select="/json:map/json:array[@key='descriptiveMetadata']/json:map[1]//json:string[@key=('yearStart', 'yearEnd')]"/>
                  </xsl:otherwise>
               </xsl:choose>
               <xsl:if test="not($part_metadata[1]//json:map[@key='subjects'])">
                  <xsl:apply-templates select="/json:map/json:array[@key='descriptiveMetadata']/json:map[1]//json:map[@key='subjects'][descendant::json:string[@key='displayForm']]" mode="flatten"/>
               </xsl:if>
            </xsl:when>
            <xsl:otherwise>
               <xsl:apply-templates select="/json:map/json:array[@key='descriptiveMetadata']/json:map[1]//json:array[@key='century'][descendant::json:string[@key='displayForm']]" mode="flatten"/>
               <xsl:copy-of select="/json:map/json:array[@key='descriptiveMetadata']/json:map[1]/json:array[@key='descriptiveMetadata']/json:map[1]//json:string[@key=('yearStart', 'yearEnd')]"/>
            </xsl:otherwise>
         </xsl:choose>
         <!--<xsl:apply-templates select="$logical_structure/json:string[@key='label']" mode="convert_to_title"/>-->
         <xsl:apply-templates select="json:map[@key='transcription_content']/json:string[@key='surfaceID']"/>
         <!--<xsl:copy-of select="/json:map/json:array[@key='collection']"/>-->
      </xsl:copy>
   </xsl:template>
   
   <!--<xsl:template match="json:string[@key='label']" mode="convert_to_title">
      <json:string key="title">
         <xsl:apply-templates />
      </json:string>
   </xsl:template>-->
   
   <xsl:template match="json:map[@key = ('transcription_content','translation_content')]">
      <json:string key="{@key}">
         <xsl:value-of select="json:string[@key='text']"/>
      </json:string>
   </xsl:template>
   
   <xsl:template match="json:string[@key='surfaceID']">
      <json:string key="{@key}">
         <xsl:value-of select="."/>
      </json:string>
   </xsl:template>
   
   <xsl:template match="json:map[normalize-space(@key)][not(descendant::json:map[normalize-space(@key)])][descendant::json:string[@key='displayForm']]" mode="flatten">
      <xsl:variable name="key-name" as="xsd:string">
         <xsl:choose>
            <xsl:when test="ancestor::json:map[normalize-space(@key)][1]">
               <xsl:value-of select="string-join((ancestor::json:map[normalize-space(@key)][1]/@key, @key), '-')"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:value-of select="@key"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      
      <xsl:copy-of select="cudl:write-displayForm($key-name, descendant::json:string[@key='displayForm'])"/>
   </xsl:template>
   
   <xsl:template match="json:array[@key='century']" mode="flatten">
      <xsl:variable name="key-name" as="xsd:string">
         <xsl:choose>
            <xsl:when test="ancestor::json:map[normalize-space(@key)][1]">
               <xsl:value-of select="string-join((ancestor::json:map[normalize-space(@key)][1]/@key, @key), '-')"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:value-of select="@key"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      
      
         <json:array key="{$key-name}">
            <xsl:copy-of select="json:string"/>
         </json:array>
      
   </xsl:template>
   
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
