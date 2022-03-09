<xsl:stylesheet version="2.0"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xtf="http://cdlib.org/xtf"
   xmlns:local="http://localhost/"
   xmlns:cudl="http://cudl.cam.ac.uk/xtf/"
   exclude-result-prefixes="#all">
   
   <xsl:output method="text" indent="yes"
      encoding="UTF-8" media-type="text/json; charset=UTF-8"
      exclude-result-prefixes="#all"
      omit-xml-declaration="yes"/>
   
   <!--function for json escaping-->
   <xsl:function name="local:escape">
      <xsl:param name="text" />
      
      <!-- In JSON, need to escape quotation mark and backward slash -->
      <xsl:value-of select="replace(replace($text, '\\', '\\\\'), '&quot;', '\\&quot;')"/>
   </xsl:function>
   
   <xsl:strip-space elements="*"/>
   
   
   <xsl:template match="/">
      
      <xsl:text>
         {</xsl:text>
      
      <!-- for each input element with match in table -->
      <xsl:for-each select="xtf-converted/xtf:meta/*[local-name()=$layout/cudl:element/@name]
         |item/*[local-name()=$layout/cudl:element/@name]">
         <xsl:variable name="thisname" select="local-name()" />
         <xsl:variable name="seq" select="cudl:get-pos($layout, $thisname)"/>
         
         
         <!-- process current input element -->
         <xsl:apply-templates select="." mode="json">
            <xsl:with-param name="cudl-element" select="$layout/cudl:element[@name=$thisname]"/>
            <xsl:with-param name="seq" select="$seq"/>
            <xsl:with-param name="cudl-parent" select="$layout"/>
            
            
            
         </xsl:apply-templates>
         
         <xsl:if test="position() != last()">,</xsl:if>
      </xsl:for-each>
      
      <xsl:text>
         }</xsl:text>
      
   </xsl:template>
   
   <xsl:function name="cudl:get-pos">
      <xsl:param name="parent" />
      <xsl:param name="childname" />
      
      <xsl:for-each select="$parent/cudl:element">
         <xsl:if test="@name=$childname">
            <xsl:value-of select="sum((count(ancestor::cudl:element), count(preceding::cudl:element)))" />
         </xsl:if>
      </xsl:for-each>
      
   </xsl:function>
   
   <xsl:template match="*" mode="json">
      <xsl:param name="cudl-element" />
      <xsl:param name="seq" />
      <xsl:param name="cudl-parent" />
      
      
      <!-- if parent not array then need JSON-label; if parent is array then no need -->
      <xsl:if test="not($cudl-parent/@jsontype='array')">
         <xsl:text>
            "</xsl:text>
         <xsl:value-of select="local-name()" />
         <xsl:text>": </xsl:text>
      </xsl:if>
      
      <!-- process according to @jsontype to construct JSON-value -->
            
      <xsl:choose>
         <xsl:when test="$cudl-element/@jsontype='array'">
            
            <xsl:call-template name="make-json-array">
               <xsl:with-param name="cudl-element" select="$cudl-element"/>
               <xsl:with-param name="seq" select="$seq" />
            </xsl:call-template>
            
         </xsl:when>
         <xsl:when test="$cudl-element/@jsontype='object'">
            
            <xsl:call-template name="make-json-object">
               <xsl:with-param name="cudl-element" select="$cudl-element"/>
               <xsl:with-param name="seq" select="$seq" />
            </xsl:call-template>
            
         </xsl:when>
         <xsl:when test="$cudl-element/@jsontype='string'">
            
            <xsl:call-template name="make-json-string">
               <xsl:with-param name="cudl-element" select="$cudl-element"/>
               <xsl:with-param name="seq" select="$seq" />
            </xsl:call-template>
            
         </xsl:when>
         <xsl:when test="$cudl-element/@jsontype='number'">
            
            <xsl:call-template name="make-json-number">
               <xsl:with-param name="cudl-element" select="$cudl-element"/>
               <xsl:with-param name="seq" select="$seq" />
            </xsl:call-template>
            
         </xsl:when>
         <xsl:when test="$cudl-element/@jsontype='boolean'">
            
            <xsl:call-template name="make-json-boolean">
               <xsl:with-param name="cudl-element" select="$cudl-element"/>
               <xsl:with-param name="seq" select="$seq" />
            </xsl:call-template>
            
         </xsl:when>
      </xsl:choose>

   </xsl:template>
   
   <xsl:template name="make-json-array">
      <xsl:param name="cudl-element" />
      <xsl:param name="seq" />
            
      <xsl:choose>
         <xsl:when test="@display">
            <!-- blow up into object with display attributes -->
            <xsl:text>
               {</xsl:text>
            <xsl:text>
               "display": </xsl:text>
            <xsl:value-of select="@display" />
            <xsl:text>, </xsl:text>
            <xsl:if test="@displayForm">
               <xsl:text>
                  "displayForm": "</xsl:text>
               <xsl:value-of select="local:escape(@displayForm)" />
               <xsl:text>", </xsl:text>             
            </xsl:if>
            
            <xsl:text>
               "seq": </xsl:text>
            <xsl:value-of select="$seq" />
            <xsl:text>, </xsl:text>             
            
            <xsl:if test="normalize-space($cudl-element/@listDisplay)">
               <xsl:text>
                  "listDisplay": "</xsl:text>
               <xsl:value-of select="normalize-space($cudl-element/@listDisplay)" />
               <xsl:text>", </xsl:text>             
            </xsl:if>
            <xsl:if test="normalize-space($cudl-element/@linktype)">
               <xsl:text>
                  "linktype": "</xsl:text>
               <xsl:value-of select="normalize-space($cudl-element/@linktype)" />
               <xsl:text>", </xsl:text>             
            </xsl:if>
            <xsl:if test="normalize-space($cudl-element/@label)">
               <xsl:text>
                  "label": "</xsl:text>
               <xsl:value-of select="normalize-space($cudl-element/@label)" />
               <xsl:text>", </xsl:text>             
            </xsl:if>
            <!-- here comes the array -->
            <xsl:text>
               "value": [
            </xsl:text>

            <!-- for each child element with match in table -->
            <xsl:for-each select="*[local-name()=$cudl-element/cudl:element/@name]">
               <xsl:variable name="thisname" select="local-name()" />
               <xsl:variable name="seq" select="cudl:get-pos($cudl-element, $thisname)"/>
               
               <!-- Process child element -->
               <xsl:apply-templates select="." mode="json">
                  <xsl:with-param name="cudl-element" select="$cudl-element/cudl:element[@name=$thisname]"/>
                  <xsl:with-param name="seq" select="$seq" />
                  <xsl:with-param name="cudl-parent" select="$cudl-element"/>
               </xsl:apply-templates>
               
               <xsl:if test="position() != last()">,</xsl:if>
            </xsl:for-each>
            <xsl:text>
               ]</xsl:text>
            <xsl:text>
               }</xsl:text>
         </xsl:when>
         <xsl:otherwise>
            <!-- just treat as array -->
            <xsl:text>
               [
            </xsl:text>

            <!-- for each child element with match in table -->
            <xsl:for-each select="*[local-name()=$cudl-element/cudl:element/@name]">
               <xsl:variable name="thisname" select="local-name()" />
               <xsl:variable name="seq" select="cudl:get-pos($cudl-element, $thisname)"/>

               <!-- Process child element -->
               <xsl:apply-templates select="." mode="json">
                  <xsl:with-param name="cudl-element" select="$cudl-element/cudl:element[@name=$thisname]"/>
                  <xsl:with-param name="seq" select="$seq" />
                  <xsl:with-param name="cudl-parent" select="$cudl-element"/>
               </xsl:apply-templates>

               <xsl:if test="position() != last()">,</xsl:if>
            </xsl:for-each>
            <xsl:text>
               ]</xsl:text>
         </xsl:otherwise>
      </xsl:choose>
   
   </xsl:template>

   <xsl:template name="make-json-object">
      <xsl:param name="cudl-element" />
      <xsl:param name="seq" />
      
      <xsl:text>
         {</xsl:text>
      <xsl:choose>
         <xsl:when test="@display">
            <!-- blow up into object with display attributes -->
            <xsl:text>
               "display": </xsl:text>
            <xsl:value-of select="@display" />
            <xsl:text>, </xsl:text>
            <xsl:if test="@displayForm">
               <xsl:text>
                  "displayForm": "</xsl:text>
               <xsl:value-of select="local:escape(@displayForm)" />
               <xsl:text>", </xsl:text>             
            </xsl:if>
            <xsl:text>
               "seq": </xsl:text>
            <xsl:value-of select="$seq" />
            <xsl:text>, </xsl:text>             
            
            <xsl:if test="normalize-space($cudl-element/@linktype)">
               <xsl:text>
                  "linktype": "</xsl:text>
               <xsl:value-of select="normalize-space($cudl-element/@linktype)" />
               <xsl:text>", </xsl:text>             
            </xsl:if>
            <xsl:if test="normalize-space($cudl-element/@label)">
               <xsl:text>
                  "label": "</xsl:text>
               <xsl:value-of select="normalize-space($cudl-element/@label)" />
               <xsl:text>", </xsl:text>             
            </xsl:if>
         </xsl:when>
         <xsl:otherwise />  <!-- no need for anything -->         
      </xsl:choose>
      
      <!-- for each child element with match in table -->
      <xsl:for-each select="*[local-name()=$cudl-element/cudl:element/@name]">
         <xsl:variable name="thisname" select="local-name()" />
         <xsl:variable name="seq" select="cudl:get-pos($cudl-element, $thisname)"/>

         <!-- Process child element -->
         <xsl:apply-templates select="." mode="json">
            <xsl:with-param name="cudl-element" select="$cudl-element/cudl:element[@name=$thisname]"/>
            <xsl:with-param name="seq" select="$seq" />
            <xsl:with-param name="cudl-parent" select="$cudl-element"/>
         </xsl:apply-templates>

         <xsl:if test="position() != last()">,</xsl:if>
      </xsl:for-each>
      <xsl:text>
         }</xsl:text>     
   
   </xsl:template>
   
   <xsl:template name="make-json-string">
      <xsl:param name="cudl-element" />
      <xsl:param name="seq" />
      
      <xsl:choose>
         <xsl:when test="@display">
            <!-- blow up into object with display attributes -->
            <xsl:text>
               {</xsl:text>
            <xsl:text>
               "display": </xsl:text>
            <xsl:value-of select="@display" />
            <xsl:text>, </xsl:text>
            <xsl:if test="@displayForm">
               <xsl:text>
                  "displayForm": "</xsl:text>
               <xsl:value-of select="local:escape(@displayForm)" />
               <xsl:text>", </xsl:text>             
            </xsl:if>

            <xsl:if test="normalize-space($cudl-element/@linktype)">
               <xsl:text>
                  "linktype": "</xsl:text>
               <xsl:value-of select="normalize-space($cudl-element/@linktype)" />
               <xsl:text>", </xsl:text>             
            </xsl:if>
            <xsl:if test="normalize-space($cudl-element/@label)">
               <xsl:text>
                  "label": "</xsl:text>
               <xsl:value-of select="normalize-space($cudl-element/@label)" />
               <xsl:text>", </xsl:text>             
            </xsl:if>
            <xsl:text>
               "seq": </xsl:text>
            <xsl:value-of select="$seq" />
            <!-- <xsl:text>, </xsl:text> -->             
            <!--
            <xsl:text>"value": </xsl:text>
            <xsl:text>"</xsl:text>            
            <xsl:value-of select="local:escape(.)" />
            <xsl:text>"</xsl:text>
            -->
            <xsl:text>
               }</xsl:text>
         </xsl:when>
         <xsl:otherwise>
            <!-- it really is just a string -->
            <xsl:text>"</xsl:text>            
            <xsl:value-of select="local:escape(.)" />
            <xsl:text>"</xsl:text>          
         </xsl:otherwise>
      </xsl:choose>
      
   </xsl:template>
   
   <xsl:template name="make-json-number">
      <xsl:param name="cudl-element" />
      <xsl:param name="seq" />
      
      <!-- numbers are never displayed so really are just numbers -->
      <xsl:value-of select="." />
   
   </xsl:template>
   
   <xsl:template name="make-json-boolean">
      <xsl:param name="cudl-element" />
      <xsl:param name="seq" />
      
      <!-- booleans are never displayed so really are just booleans -->
      <xsl:value-of select="." />
   
   </xsl:template>

   <!-- 
      
      Variable $layout is the source of the "display attributes" for the JSON data (label, linktype, seq
      
      For each input element type to be included in the JSON output, the variable $layout provides:
      - the type of the output JSON structure
      - for display elements:
        - the display label to be applied (@label)
        - the linktype to be applied (@linktype) (currently only a single search type, but that will probably expand in the future)
        - the order in which the element is to be displayed, based on order within this table. 
          (This is a bit limiting in the sense that the ordering of "child" elements is subordinate to the ordering of "parent" elements, 
          but for now, it's probably adequate.)
        
        N.B. This variable does NOT control 
        - whether an individual element is displayed or not: that comes from the input data (@display) 
   
   -->
   
   <xsl:variable name="layout">
      <!--
      <cudl:element name="itemType" jsontype="array" >
         <cudl:element name="type" jsontype="string" />         
      </cudl:element>
      -->
      <cudl:element name="itemType" jsontype="string" />         

      <cudl:element name="descriptiveMetadata" jsontype="array">
         <cudl:element name="part" jsontype="object">
            <cudl:element name="ID" jsontype="string" />
            <cudl:element name="physicalLocation" label="Physical Location" jsontype="string" />
            <cudl:element name="shelfLocator"  label="Classmark" jsontype="string" />
            <cudl:element name="altIdentifiers" label="Alternative Identifier(s)" jsontype="array">
               <cudl:element name="altIdentifier" jsontype="string" />
            </cudl:element>
            <cudl:element name="calendarnum"  label="Letter Number" jsontype="string" />
            <cudl:element name="reference"  label="Reference" jsontype="string" />
            <cudl:element name="title" label="Title" jsontype="string" />
            <cudl:element name="abstract" label="Abstract" jsontype="string" />
            <cudl:element name="relatedResources" label="Featured in" jsontype="array">
               <cudl:element name="relatedResource" jsontype="object">
                  <cudl:element name="resourceTitle" jsontype="string"/>
                  <cudl:element name="resourceUrl" jsontype="string"/>
               </cudl:element>
            </cudl:element>
            <cudl:element name="alternativeTitles" label="Alternative Title(s)" jsontype="array">
               <cudl:element name="alternativeTitle" jsontype="string" />
            </cudl:element>
            <cudl:element name="descriptiveTitles" label="Descriptive Title(s)" jsontype="array">
               <cudl:element name="descriptiveTitle" jsontype="string" />
            </cudl:element>
            <cudl:element name="uniformTitle" label="Uniform Title" jsontype="string" />
            <cudl:element name="level"  label="Level of Description" jsontype="string" />
            <cudl:element name="subjects" label="Subject(s)" jsontype="array" listDisplay="inline" >
               <cudl:element name="subject" jsontype="object" linktype="keyword search" >
                  <cudl:element name="fullForm" jsontype="string" />
                  <cudl:element name="shortForm" jsontype="string" />
                  <cudl:element name="authority" jsontype="string" />
                  <cudl:element name="authorityURI" jsontype="string" />
                  <cudl:element name="valueURI" jsontype="string" />
                  <cudl:element name="type" jsontype="string" />
                  <cudl:element name="components" jsontype="array">
                     <cudl:element name="component" jsontype="object">
                        <cudl:element name="fullForm" jsontype="string" />
                        <cudl:element name="shortForm" jsontype="string" />
                        <cudl:element name="authority" jsontype="string" />
                        <cudl:element name="authorityURI" jsontype="string" />
                        <cudl:element name="valueURI" jsontype="string" />
                        <cudl:element name="type" jsontype="string" />
                     </cudl:element>
                  </cudl:element>
               </cudl:element>         
            </cudl:element>
            <cudl:element name="authors" label="Author(s)" jsontype="array" listDisplay="unordered">
               <cudl:element name="name" linktype="keyword search"  jsontype="object">
                  <cudl:element name="fullForm" jsontype="string" />
                  <cudl:element name="shortForm" jsontype="string" />
                  <cudl:element name="authority" jsontype="string" />
                  <cudl:element name="authorityURI" jsontype="string" />
                  <cudl:element name="valueURI" jsontype="string" />
                  <cudl:element name="type" jsontype="string" />
                  <cudl:element name="role" jsontype="string" />                  
               </cudl:element>
            </cudl:element>
            <cudl:element name="scribes" label="Scribe(s)" jsontype="array" listDisplay="unordered">
               <cudl:element name="name" linktype="keyword search"  jsontype="object">
                  <cudl:element name="fullForm" jsontype="string" />
                  <cudl:element name="shortForm" jsontype="string" />
                  <cudl:element name="authority" jsontype="string" />
                  <cudl:element name="authorityURI" jsontype="string" />
                  <cudl:element name="valueURI" jsontype="string" />
                  <cudl:element name="type" jsontype="string" />
                  <cudl:element name="role" jsontype="string" />   
                  
               </cudl:element>
               
            </cudl:element>
            <cudl:element name="creators" label="Creator(s)" jsontype="array" listDisplay="unordered">
               <cudl:element name="name" linktype="keyword search"  jsontype="object">
                  <cudl:element name="fullForm" jsontype="string" />
                  <cudl:element name="shortForm" jsontype="string" />
                  <cudl:element name="authority" jsontype="string" />
                  <cudl:element name="authorityURI" jsontype="string" />
                  <cudl:element name="valueURI" jsontype="string" />
                  <cudl:element name="type" jsontype="string" />
                  <cudl:element name="role" jsontype="string" />                  
               </cudl:element>
            </cudl:element>
            <cudl:element name="creations" jsontype="array">
               <cudl:element name="event" jsontype="object">
                  <cudl:element name="type" jsontype="string" />
                  <cudl:element name="publishers" label="Publisher" jsontype="array" >
                     <cudl:element name="publisher" jsontype="string" />
                  </cudl:element>
                  <cudl:element name="places" label="Origin Place" jsontype="array" >
                     <cudl:element name="place" linktype="keyword search" jsontype="object">
                        <cudl:element name="fullForm" jsontype="string" />
                        <cudl:element name="shortForm" jsontype="string" />
                        <cudl:element name="authority" jsontype="string" />
                        <cudl:element name="authorityURI" jsontype="string" />
                        <cudl:element name="valueURI" jsontype="string" />
                     </cudl:element>                    
                  </cudl:element>
                  <cudl:element name="dateStart" jsontype="string" />
                  <cudl:element name="dateEnd" jsontype="string" />
                  <cudl:element name="dateDisplay" label="Date of Creation" jsontype="string" linktype="keyword search" />        
               </cudl:element>
            </cudl:element>
            <cudl:element name="publications" jsontype="array">
               <cudl:element name="event" jsontype="object">
                  <cudl:element name="type" jsontype="string" />
                  <cudl:element name="publishers" label="Publisher" jsontype="array" >
                     <cudl:element name="publisher" jsontype="string" />
                  </cudl:element>
                  <cudl:element name="places" label="Place of Publication" jsontype="array" >
                     <cudl:element name="place" linktype="keyword search" jsontype="object">
                        <cudl:element name="fullForm" jsontype="string" />
                        <cudl:element name="shortForm" jsontype="string" />
                        <cudl:element name="authority" jsontype="string" />
                        <cudl:element name="authorityURI" jsontype="string" />
                        <cudl:element name="valueURI" jsontype="string" />
                     </cudl:element>                    
                  </cudl:element>
                  <cudl:element name="dateStart" jsontype="string" />
                  <cudl:element name="dateEnd" jsontype="string" />
                  <cudl:element name="dateDisplay" label="Date of Publication" jsontype="string" linktype="keyword search" />
               </cudl:element>
            </cudl:element>
            
            <cudl:element name="temporalCoverage" jsontype="array">
               <cudl:element name="period" jsontype="object">
                  <cudl:element name="dateStart" jsontype="string" />
                  <cudl:element name="dateEnd" jsontype="string" />
                  <cudl:element name="dateDisplay" jsontype="string" />
               </cudl:element>
            </cudl:element>
            
            <cudl:element name="recipients" label="Recipient(s)" jsontype="array" listDisplay="unordered">
               <cudl:element name="name" linktype="keyword search"  jsontype="object">
                  <cudl:element name="fullForm" jsontype="string" />
                  <cudl:element name="shortForm" jsontype="string" />
                  <cudl:element name="authority" jsontype="string" />
                  <cudl:element name="authorityURI" jsontype="string" />
                  <cudl:element name="valueURI" jsontype="string" />
                  <cudl:element name="type" jsontype="string" />
                  <cudl:element name="role" jsontype="string" />                  
               </cudl:element>               
            </cudl:element>
            
            <cudl:element name="destinations" label="Destination" jsontype="array" >
               <cudl:element name="place" linktype="keyword search" jsontype="object">
                  <cudl:element name="fullForm" jsontype="string" />
                  <cudl:element name="shortForm" jsontype="string" />
                  <cudl:element name="authority" jsontype="string" />
                  <cudl:element name="authorityURI" jsontype="string" />
                  <cudl:element name="valueURI" jsontype="string" />
               </cudl:element>                    
            </cudl:element>
            
            <cudl:element name="filiations" label="Filiations" jsontype="string" />
            <cudl:element name="languageCodes" jsontype="array">
               <cudl:element name="languageCode" jsontype="string" />
            </cudl:element>
            <cudl:element name="languageStrings" label="Language(s)" jsontype="array">
               <cudl:element name="languageString" jsontype="string" />
            </cudl:element>
            
            <cudl:element name="donors" label="Donor(s)" jsontype="array" >
               <cudl:element name="name" linktype="keyword search"  jsontype="object">
                  <cudl:element name="fullForm" jsontype="string" />
                  <cudl:element name="shortForm" jsontype="string" />
                  <cudl:element name="authority" jsontype="string" />
                  <cudl:element name="authorityURI" jsontype="string" />
                  <cudl:element name="valueURI" jsontype="string" />
                  <cudl:element name="type" jsontype="string" />
                  <cudl:element name="role" jsontype="string" />                                   
               </cudl:element>               
            </cudl:element>
            <cudl:element name="formerOwners" label="Former Owner(s)" jsontype="array" >
               <cudl:element name="name" linktype="keyword search"  jsontype="object">
                  <cudl:element name="fullForm" jsontype="string" />
                  <cudl:element name="shortForm" jsontype="string" />
                  <cudl:element name="authority" jsontype="string" />
                  <cudl:element name="authorityURI" jsontype="string" />
                  <cudl:element name="valueURI" jsontype="string" />
                  <cudl:element name="type" jsontype="string" />
                  <cudl:element name="role" jsontype="string" />                  
               </cudl:element>
               
            </cudl:element>
            <cudl:element name="associated" label="Associated Name(s)" jsontype="array" listDisplay="unordered" >
               <cudl:element name="name" linktype="keyword search"  jsontype="object">
                  <cudl:element name="fullForm" jsontype="string" />
                  <cudl:element name="shortForm" jsontype="string" />
                  <cudl:element name="authority" jsontype="string" />
                  <cudl:element name="authorityURI" jsontype="string" />
                  <cudl:element name="valueURI" jsontype="string" />
                  <cudl:element name="type" jsontype="string" />
                  <cudl:element name="role" jsontype="string" />                  
                  
               </cudl:element>
               
            </cudl:element>
            
            <cudl:element name="associatedCorps" label="Associated Organisation(s)" jsontype="array" listDisplay="unordered" >
               <cudl:element name="name" linktype="keyword search"  jsontype="object">
                  <cudl:element name="fullForm" jsontype="string" />
                  <cudl:element name="shortForm" jsontype="string" />
                  <cudl:element name="authority" jsontype="string" />
                  <cudl:element name="authorityURI" jsontype="string" />
                  <cudl:element name="valueURI" jsontype="string" />
                  <cudl:element name="type" jsontype="string" />
                  <cudl:element name="role" jsontype="string" />                  
                  
               </cudl:element>
               
            </cudl:element>
            
            <cudl:element name="places" label="Associated Place(s)" jsontype="array" >
               <cudl:element name="place" linktype="keyword search" jsontype="object">
                  <cudl:element name="fullForm" jsontype="string" />
                  <cudl:element name="shortForm" jsontype="string" />
                  <cudl:element name="authority" jsontype="string" />
                  <cudl:element name="authorityURI" jsontype="string" />
                  <cudl:element name="valueURI" jsontype="string" />
               </cudl:element>                    
            </cudl:element>
            
            <cudl:element name="notes" label="Note(s)" jsontype="array" >
               <cudl:element name="note" jsontype="string" />                     
            </cudl:element>
            
            <cudl:element name="originals" label="Existence/location of Originals" jsontype="array" >
               <cudl:element name="origin" jsontype="string" />                     
            </cudl:element>
            
            <cudl:element name="altforms" label="Existence/location of Copies" jsontype="array" >
               <cudl:element name="altform" jsontype="string" />                     
            </cudl:element>
            
            <cudl:element name="relatedmaterials" label="Related Materials" jsontype="array" >
               <cudl:element name="relatedmaterial" jsontype="string" />                     
            </cudl:element>
            
            <cudl:element name="physdesc" label="Physical Description" jsontype="string"/>
            
            <cudl:element name="extent" label="Extent" jsontype="string"/>
            <cudl:element name="collation" label="Collation" jsontype="string" />
            <cudl:element name="supports" label="Support" jsontype="array">
               <cudl:element name="support" jsontype="string" />
            </cudl:element>
            <cudl:element name="material" label="Material" jsontype="string" />
            <cudl:element name="form" label="Format" jsontype="string" />        
            <cudl:element name="conditions" label="Condition"  jsontype="array">
               <cudl:element name="condition" jsontype="string" />               
            </cudl:element>            
            <cudl:element name="bindings" label="Binding" jsontype="array">
               <cudl:element name="binding" jsontype="string" />                                 
            </cudl:element>
            <cudl:element name="accMats" label="Accompanying Material" jsontype="array">
               <cudl:element name="accMat" jsontype="string" />                                 
            </cudl:element>
            <cudl:element name="scripts" label="Script"  jsontype="array">
               <cudl:element name="script" jsontype="string" />                                 
            </cudl:element>
            <cudl:element name="musicNotations" label="Music notation" jsontype="array">
               <cudl:element name="musicNotation" jsontype="string" />                                 
            </cudl:element>
            <cudl:element name="foliation" label="Foliation" jsontype="string" />
            <cudl:element name="layouts" label="Layout" jsontype="array">
               <cudl:element name="layout" jsontype="string" />                               
            </cudl:element>
            <cudl:element name="decorations" label="Decoration" jsontype="array">
               <cudl:element name="decoration" jsontype="string" />                  
            </cudl:element>
            <cudl:element name="additions" label="Additions"  jsontype="array">   
               <cudl:element name="addition" jsontype="string" />                  
            </cudl:element>
            <cudl:element name="provenances" label="Provenance"  jsontype="array">
               <cudl:element name="provenance" jsontype="string" />                  
            </cudl:element>
            <cudl:element name="origins" label="Origin"  jsontype="array">
               <cudl:element name="origin" jsontype="string" />                  
            </cudl:element>
            <cudl:element name="acquisitionTexts" label="Acquisition"  jsontype="array">
               <cudl:element name="acquisitionText" jsontype="string" />                  
            </cudl:element>
            <cudl:element name="acquisitions"  jsontype="array">
               <cudl:element name="event" jsontype="object">
                  <cudl:element name="type" jsontype="string" />
                  <cudl:element name="dateStart" jsontype="string" />
                  <cudl:element name="dateEnd" jsontype="string" />
                  <cudl:element name="dateDisplay" label="Date of Acquisition" jsontype="string" />
               </cudl:element>
            </cudl:element>
            <cudl:element name="fundings" label="Funding" jsontype="array">
               <cudl:element name="funding" jsontype="string" />                                 
            </cudl:element>
            <cudl:element name="dataSources" label="Data Source(s)" jsontype="array"  >
               <cudl:element name="dataSource" jsontype="string"  />
            </cudl:element>
            <cudl:element name="dataRevisions" label="Author(s) of the Record" jsontype="string" />
            <cudl:element name="excerpts" label="Excerpts" jsontype="string"/>
            <cudl:element name="bibliographies" label="Bibliography" jsontype="array">
               <cudl:element name="bibliography" jsontype="string"/>               
            </cudl:element>
            
            <!-- Non-display data: used by viewer but not displayed in metadata block -->
            <cudl:element name="thumbnailUrl" jsontype="string" />
            <cudl:element name="thumbnailOrientation" jsontype="string" />
            <cudl:element name="displayImageRights" jsontype="string" />
            <cudl:element name="downloadImageRights" jsontype="string" />
            <cudl:element name="imageReproPageURL" jsontype="string" />
            <cudl:element name="metadataRights" jsontype="string" />
            <cudl:element name="pdfRights" jsontype="string" />
            <cudl:element name="watermarkStatement" jsontype="string" />
            <cudl:element name="docAuthority" jsontype="string" />
            <cudl:element name="type" jsontype="string" />
            <cudl:element name="manuscript" jsontype="boolean" />
            <cudl:element name="itemReferences" jsontype="array" >
               <cudl:element name="item" jsontype="object">
                  <cudl:element name="ID" jsontype="string" />                  
               </cudl:element>
            </cudl:element>
            <!-- <cudl:element name="content" jsontype="string" /> -->
            
         </cudl:element>           
         
      </cudl:element>
      
      <cudl:element name="numberOfPages" jsontype="number"/>
      <cudl:element name="embeddable" jsontype="boolean"/>
      <cudl:element name="textDirection" jsontype="string"/>
      <cudl:element name="sourceData" jsontype="string"/>
      <cudl:element name="useTranscriptions" jsontype="boolean"/>
      <cudl:element name="useNormalisedTranscriptions" jsontype="boolean"/>
      <cudl:element name="useDiplomaticTranscriptions" jsontype="boolean"/>
      <cudl:element name="allTranscriptionDiplomaticURL" jsontype="string"/>
      <cudl:element name="useTranslations" jsontype="boolean"/>
      <cudl:element name="completeness" jsontype="string" />
      
      
      
      <cudl:element name="pages" jsontype="array">
         <cudl:element name="page" jsontype="object">
            <cudl:element name="label" jsontype="string" />
            <cudl:element name="physID" jsontype="string" />
            <cudl:element name="sequence" jsontype="number" />
            <cudl:element name="displayImageURL" jsontype="string" />
            <cudl:element name="downloadImageURL" jsontype="string" />
            <cudl:element name="IIIFImageURL" jsontype="string" />
            <cudl:element name="thumbnailImageURL" jsontype="string" />
            <cudl:element name="thumbnailImageOrientation" jsontype="string" />
            <cudl:element name="imageWidth" jsontype="number" />
            <cudl:element name="imageHeight" jsontype="number" />
            <cudl:element name="transcriptionNormalisedURL" jsontype="string" />
            <cudl:element name="transcriptionDiplomaticURL" jsontype="string" />
            <cudl:element name="translationURL" jsontype="string" />
            <cudl:element name="content" jsontype="string" />
            <cudl:element name="pageType" jsontype="string" />
         </cudl:element>            
      </cudl:element>
      
      <cudl:element name="listItemPages" jsontype="array">
         <cudl:element name="listItemPage" jsontype="object">
            <cudl:element name="fileID" jsontype="string" />
            <cudl:element name="dmdID" jsontype="string" />
            <cudl:element name="startPageLabel" jsontype="string" />
            <cudl:element name="startPage" jsontype="number" />
            <cudl:element name="title" jsontype="string" />
            <cudl:element name="listItemText" jsontype="string" />
         </cudl:element>
      </cudl:element>
      
      <cudl:element name="logicalStructures" jsontype="array">
         <cudl:element name="logicalStructure" jsontype="object">
            <cudl:element name="label" jsontype="string" />
            <cudl:element name="descriptiveMetadataID" jsontype="string" />
            <cudl:element name="startPageLabel" jsontype="string" />
            <cudl:element name="startPageID" jsontype="string" />
            <cudl:element name="startPagePosition" jsontype="number" />
            <cudl:element name="endPageLabel" jsontype="string" />
            <cudl:element name="endPageID" jsontype="string" />
            <cudl:element name="endPagePosition" jsontype="number" />
            <cudl:element name="children" jsontype="array">
               <cudl:element name="logicalStructure" jsontype="object">
                  <cudl:element name="label" jsontype="string" />
                  <cudl:element name="descriptiveMetadataID" jsontype="string" />
                  <cudl:element name="startPageLabel" jsontype="string" />
                  <cudl:element name="startPageID" jsontype="string" />
                  <cudl:element name="startPagePosition" jsontype="number" />
                  <cudl:element name="endPageLabel" jsontype="string" />
                  <cudl:element name="endPageID" jsontype="string" />
                  <cudl:element name="endPagePosition" jsontype="number" />
                  <cudl:element name="children" jsontype="array">
                     <cudl:element name="logicalStructure" jsontype="object">
                        <cudl:element name="label" jsontype="string" />
                        <cudl:element name="descriptiveMetadataID" jsontype="string" />
                        <cudl:element name="startPageLabel" jsontype="string" />
                        <cudl:element name="startPageID" jsontype="string" />
                        <cudl:element name="startPagePosition" jsontype="number" />
                        <cudl:element name="endPageLabel" jsontype="string" />
                        <cudl:element name="endPageID" jsontype="string" />
                        <cudl:element name="endPagePosition" jsontype="number" />
                        <cudl:element name="children" jsontype="array">
                           <cudl:element name="logicalStructure" jsontype="object">
                              <cudl:element name="label" jsontype="string" />
                              <cudl:element name="descriptiveMetadataID" jsontype="string" />
                              <cudl:element name="startPageLabel" jsontype="string" />
                              <cudl:element name="startPageID" jsontype="string" />
                              <cudl:element name="startPagePosition" jsontype="number" />
                              <cudl:element name="endPageLabel" jsontype="string" />
                              <cudl:element name="endPageID" jsontype="string" />
                              <cudl:element name="endPagePosition" jsontype="number" />
                              <cudl:element name="children" jsontype="array">
                                 <cudl:element name="logicalStructure" jsontype="object">
                                    <cudl:element name="label" jsontype="string" />
                                    <cudl:element name="descriptiveMetadataID" jsontype="string" />
                                    <cudl:element name="startPageLabel" jsontype="string" />
                                    <cudl:element name="startPageID" jsontype="string" />
                                    <cudl:element name="startPagePosition" jsontype="number" />
                                    <cudl:element name="endPageLabel" jsontype="string" />
                                    <cudl:element name="endPageID" jsontype="string" />
                                    <cudl:element name="endPagePosition" jsontype="number" />
                                    <cudl:element name="children" jsontype="array">
                                       <cudl:element name="logicalStructure" jsontype="object">
                                          <cudl:element name="label" jsontype="string" />
                                          <cudl:element name="descriptiveMetadataID" jsontype="string" />
                                          <cudl:element name="startPageLabel" jsontype="string" />
                                          <cudl:element name="startPageID" jsontype="string" />
                                          <cudl:element name="startPagePosition" jsontype="number" />
                                          <cudl:element name="endPageLabel" jsontype="string" />
                                          <cudl:element name="endPageID" jsontype="string" />
                                          <cudl:element name="endPagePosition" jsontype="number" />
                                          <cudl:element name="children" jsontype="array">
                                             
                                          </cudl:element>
                                       </cudl:element>            
                                       
                                    </cudl:element>
                                 </cudl:element>            
                                 
                              </cudl:element>
                           </cudl:element>            
                           
                        </cudl:element>
                     </cudl:element>            
                     
                  </cudl:element>
               </cudl:element>            
               
            </cudl:element>
         </cudl:element>            
      </cudl:element>
      
   </xsl:variable>
  
</xsl:stylesheet>
