<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
   xmlns:date="http://exslt.org/dates-and-times" xmlns:parse="http://cdlib.org/xtf/parse"
   xmlns:xtf="http://cdlib.org/xtf" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:cudl="http://cudl.lib.cam.ac.uk/xtf/" xmlns:xsd="http://www.w3.org/2001/XMLSchema"
   xmlns:sim="http://cudl.lib.cam.ac.uk/xtf/ns/similarity"
   extension-element-prefixes="date" exclude-result-prefixes="#all"
   xmlns:lambda="http://cudl.lib.cam.ac.uk/lambda/">



   <!--
      Copyright (c) 2008, Regents of the University of California
      All rights reserved.
      
      Redistribution and use in source and binary forms, with or without 
      modification, are permitted provided that the following conditions are 
      met:
      
      - Redistributions of source code must retain the above copyright notice, 
      this list of conditions and the following disclaimer.
      - Redistributions in binary form must reproduce the above copyright 
      notice, this list of conditions and the following disclaimer in the 
      documentation and/or other materials provided with the distribution.
      - Neither the name of the University of California nor the names of its
      contributors may be used to endorse or promote products derived from 
      this software without specific prior written permission.
      
      THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
      AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
      IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
      ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
      LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
      CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
      SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
      INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
      CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
      ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
      POSSIBILITY OF SUCH DAMAGE.
   -->

   <!--All TEI gets sent here from docSelector.xsl. Transforms TEI into local xml format and passes it on to docFormatter for conversion into json-->

   
   <!-- ====================================================================== -->
   <!-- Variables                                                              -->
   <!-- ====================================================================== -->
   
   <xsl:variable name="pathToConf" select="'../../../conf/local.conf'"/>
   
   
   <!-- ====================================================================== -->
   <!-- Services URI and api key                                    -->
   <!-- ====================================================================== -->
   
   <xsl:variable name="servicesURI" select="document($pathToConf)//services/@path"/>
   
   <xsl:variable name="apiKey" select="document($pathToConf)//services/@key"/>
   
   
   <!-- ====================================================================== -->
   <!-- File ID                                       -->
   <!-- ====================================================================== -->
   
   <xsl:variable name="fileID"
      select="substring-before(tokenize(document-uri(/), '/')[last()], '.xml')"/>
   
   <!-- ====================================================================== -->
   <!-- Languages and writing direction                                       -->
   <!-- ====================================================================== -->
   
   <!--default is left to right, so only list those which are not-->
   
   <xsl:variable name="languages-direction">
      
      <languages>
         <!--<language>
            <code>heb</code><direction>R</direction>
         </language>
         <language>
            <code>ara</code><direction>R</direction>
         </language>
         <language>
            <code>arc</code><direction>R</direction>
         </language>
         <language>
            <code>per</code><direction>R</direction>
         </language>-->
      </languages>
      
   </xsl:variable>
   
    <xsl:variable name="current_filename" select="replace(normalize-space(tokenize(document-uri(root(/)), '/')[last()]),'\..*$','')"/>
   
   <!-- ====================================================================== -->
   <!-- Root Template                                                          -->
   <!-- ====================================================================== -->
   
   <!-- Root template: This is the entry point of the preFilter transforms.
     It calls the get-meta template which is defined in each of our prefilter
     types (ead, msTei etc) -->
   <xsl:template match="/">
      <xsl:variable name="tree">
         <!--the whole output document is always wrapped up in xtf-converted-->
         <xtf-converted>
            <xsl:namespace name="xtf" select="'http://cdlib.org/xtf'"/>
            <!--and then we get all the fields!-->
            <xsl:call-template name="get-meta"/>
         </xtf-converted>
      </xsl:variable>
      
      <!-- Post-process the built metadata/index tree to add fields for
        similarity search. -->
      <!--<xsl:variable name="tree-with-similarity">
         <xsl:apply-templates select="$tree" mode="similarity"/>
      </xsl:variable>-->
      
      <xsl:variable name="tree-with-deduplication">
         <xsl:apply-templates select="$tree" mode="deduplication"/>
      </xsl:variable>
      
      <!-- Return the post-processed tree. -->
      <xsl:copy-of select="$tree-with-deduplication"/>
   </xsl:template>
   
   <!-- De-duplication -->
   <xsl:template match="/xtf-converted/xtf:meta/descriptiveMetadata/part/associated" mode="deduplication">
      <associated display="true">
         <xsl:for-each-group select="name" group-by="@displayForm">
            <xsl:apply-templates select="current-group()[1]" mode="deduplication"/>
         </xsl:for-each-group>
      </associated>
   </xsl:template>
   
   <xsl:template match="/xtf-converted/xtf:meta/descriptiveMetadata/part/formerOwners" mode="deduplication">
      <formerOwners display="true">
         <xsl:for-each-group select="name" group-by="@displayForm">
            <xsl:apply-templates select="current-group()[1]" mode="deduplication"/>
         </xsl:for-each-group>
      </formerOwners>
   </xsl:template>
   
   <xsl:template match="@*|node()" mode="deduplication">
      <xsl:copy>
         <xsl:apply-templates select="@*|node()" mode="deduplication"/>
      </xsl:copy>
   </xsl:template>
   
   
   
   <!-- ====================================================================== -->
   <!-- Templates                                                              -->
   <!-- ====================================================================== -->
   
   <!--called by document-specific preFilters-->
   <xsl:template name="add-fields">
      <xsl:param name="meta"/>
      <xsl:param name="display"/>
      
      <xtf:meta>
         
         
         <!-- Add a field to record the document kind -->
         <display xtf:meta="true" xtf:tokenize="no">
            <xsl:value-of select="$display"/>
         </display>
         
         <xsl:apply-templates select="$meta/*" mode="meta"/>
         
      </xtf:meta>
   </xsl:template>
   
   <!--default to copy everything-->
   <xsl:template match="@*|node()" mode="meta">
      <xsl:copy>
         <xsl:apply-templates select="@*|node()" mode="meta"/>
      </xsl:copy>
   </xsl:template>
   
   
   
   <!-- ====================================================================== -->
   <!-- Functions                                                              -->
   <!-- ====================================================================== -->
   
   <!--used in document-specific prefilters-->
   
   <!--processes transcription uri for indexing-->
   <xsl:function name="cudl:transcription-uri">
      
      <xsl:param name="uri"/>
      
      <xsl:variable name="uriReplaced"
         select="replace($uri, 'http://services.cudl.lib.cam.ac.uk/', $servicesURI)"/>
      <xsl:value-of select="concat($uriReplaced, '?apikey=', $apiKey)"/>
      
   </xsl:function>
   
   
   
   <!-- Provide page for reproduction requests, based on repository. Temporary hack: this really neeeds to come from data -->
   
   <xsl:function name="cudl:get-imageReproPageURL">
      <xsl:param name="repository"/>
      <xsl:param name="shelflocator"/>
      
      <xsl:choose>
         <xsl:when test="$repository='National Maritime Museum'">
            <xsl:text>http://images.rmg.co.uk/en/page/show_home_page.html</xsl:text>
         </xsl:when>
         <xsl:when test="$repository='Cambridge University Collection of Aerial Photography'">
            <xsl:text>https://www.cambridgeairphotos.com/</xsl:text>
         </xsl:when>
         <xsl:when test="$repository='Bodleian Library'">
            <xsl:text>https://www.bodleian.ox.ac.uk/using/imaging_services</xsl:text>
         </xsl:when>
         <xsl:when test="$repository='British School at Athens'">
            <xsl:text>https://digital.bsa.ac.uk/permissions.php</xsl:text>
         </xsl:when>
         <xsl:when test="$repository='British Library'">
            <xsl:text>https://forms.bl.uk/permissions/</xsl:text>
         </xsl:when>
         
         <xsl:when test="$repository='The John Rylands Library'">
            <xsl:text>https://www.library.manchester.ac.uk/search-resources/manchester-digital-collections/digitisation-services/copyright-and-licensing/</xsl:text>
         </xsl:when>
         
         <xsl:when test="$repository='Cavendish Laboratory'">
            
            <xsl:variable name="shelflocator_short">
               
               <xsl:choose>
                  <xsl:when test="contains($shelflocator, ' ')">
                     <xsl:value-of select="substring-before($shelflocator, ' ')"/>
                     
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:value-of select="$shelflocator"/>
                  </xsl:otherwise>
                  
                  
               </xsl:choose>
               
               
               
            </xsl:variable>
            
            <xsl:variable name="urltext" select="concat('https://www.phy.cam.ac.uk/about/image-licensing-form?id=',$shelflocator_short)"/>
            <xsl:value-of select="$urltext"></xsl:value-of>
            <!--<xsl:text>https://www.phy.cam.ac.uk/about/image-licensing-form</xsl:text>-->
         </xsl:when>
         
         <!--default is Cambridge-->
         <xsl:otherwise>
            <xsl:text>https://imagingservices.lib.cam.ac.uk/</xsl:text>
         </xsl:otherwise>
      </xsl:choose>
      
   </xsl:function>
   
   <!--Capitalises first letter of text-->
   <xsl:function name="cudl:first-upper-case">
      <xsl:param name="text" />
      
      <xsl:value-of select="concat(upper-case(substring($text,1,1)),substring($text, 2))" />
   </xsl:function>
   
   
   <!--Gets text direction from language-->
   <xsl:function name="cudl:get-language-direction">
      <xsl:param name="languageCode" />
      
      <xsl:choose>
         <xsl:when test="normalize-space($languages-direction/languages/language[code=$languageCode]/direction)">
            <xsl:value-of select="normalize-space($languages-direction/languages/language[code=$languageCode]/direction)"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:text>L</xsl:text>
         </xsl:otherwise>
      </xsl:choose>
      
   </xsl:function>




   <!-- ====================================================================== -->
   <!-- Output parameters                                                      -->
   <!-- ====================================================================== -->

   <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
   <xsl:strip-space elements="*"/>

   <xsl:key name="surfaceIDs" match="//tei:surface" use="(@xml:id, concat('#',@xml:id))"/>
   <xsl:key name="surfaceNs" match="//tei:surface" use="normalize-space(@n)"/>

   <!-- ====================================================================== -->
   <!-- Metadata Indexing                                                      -->
   <!-- ====================================================================== -->

   <xsl:template name="get-meta">

      <!-- extract metadata from the TEI and put it in a variable -->
      <xsl:variable name="meta">

         <!--descriptive information about the item-->
         <descriptiveMetadata>


            <xsl:apply-templates select="*:TEI/*:teiHeader/*:fileDesc/*:sourceDesc/*:msDesc"/>


         </descriptiveMetadata>

         <!--top level fields concerning the document as a whole-->
         <!--how many pages does it have-->
         <xsl:call-template name="get-numberOfPages"/>
         <!--is it embeddable-->
         <xsl:call-template name="get-embeddable"/>
         <!--text direction-->
         <xsl:call-template name="get-text-direction"/>


         <!--flags to govern whether transcription/translation exist - used to create tabs-->
         <xsl:call-template name="get-transcription-flags"/>

         <!--where is the source metadata available-->
         <xsl:call-template name="get-sourceData"/>

         <!--is this a complete representation of the item-->
         <!--QUERY - deprecate?-->
         <xsl:if test=".//*:note[@type='completeness']">
            <xsl:apply-templates select=".//*:note[@type='completeness']"/>
         </xsl:if>

         <!--structural information about the item-->
         <xsl:call-template name="make-pages"/>
         <xsl:call-template name="make-logical-structure"/>

         <!--a special case where items in a list with a locus are indexed against that locus-->
         <!--QUERY - can we index straight from the content?-->
         <xsl:if test="//*:list/*:item[*:locus]">
            <xsl:call-template name="make-list-item-pages"/>
         </xsl:if>

      </xsl:variable>

      <!-- Add doc kind and sort fields to the data, and output the result. -->
      <xsl:call-template name="add-fields">
         <xsl:with-param name="display" select="'dynaxml'"/>
         <xsl:with-param name="meta" select="$meta"/>
      </xsl:call-template>
   </xsl:template>

   <!--*************************************FLAGS*****************************************-->
   <!--These are all set at the top level, before we go into descriptive metadata-->


   <!--*********************************** number of pages -->
   <xsl:template name="get-numberOfPages">
      <numberOfPages>
         <xsl:choose>
            <xsl:when test="//*:facsimile/*:surface">

               <xsl:value-of select="count(//*:facsimile/*:surface)"/>

            </xsl:when>

            <xsl:otherwise>
               <xsl:text>1</xsl:text>
            </xsl:otherwise>
         </xsl:choose>
      </numberOfPages>
   </xsl:template>


   <!-- ********************************* embeddable -->
   <xsl:template name="get-embeddable">
      
      <xsl:if test="count(//*:facsimile) gt 1">
         <xsl:message select="concat('WARN: More than one facsimile block in ', tokenize(document-uri(/), '/')[last()])"/>
      </xsl:if>
      
      <xsl:variable name="downloadImageRights"
         select="normalize-space(//*:publicationStmt/*:availability[@xml:id='downloadImageRights'])"/>
      <xsl:variable name="images"
         select="normalize-space((//*:facsimile/*:surface[1]/*:graphic[1])[1]/@url)"/>



      <embeddable>
         <xsl:choose>

            <xsl:when test="normalize-space($images)">

               <xsl:text>true</xsl:text>


            </xsl:when>

            <xsl:otherwise>false</xsl:otherwise>
         </xsl:choose>
      </embeddable>

   </xsl:template>


   <!-- ********************************* text direction -->
   <xsl:template name="get-text-direction">


      <xsl:variable name="languageCode">

         <xsl:choose>
            <xsl:when test="//*:sourceDesc/*:msDesc/*:msContents/*:textLang/@mainLang">

               <xsl:value-of select="//*:sourceDesc/*:msDesc/*:msContents/*:textLang/@mainLang"/>

            </xsl:when>


            <xsl:when
               test="count(//*:sourceDesc/*:msDesc/*:msContents/*:msItem) = 1 and //*:sourceDesc/*:msDesc/*:msContents/*:msItem[1]/*:textLang/@mainLang">

               <xsl:value-of
                  select="//*:sourceDesc/*:msDesc/*:msContents/*:msItem[1]/*:textLang/@mainLang"/>

            </xsl:when>
            <xsl:when
               test="(/tei:*/tei:teiHeader//tei:langUsage/tei:language/@ident)[normalize-space(.)][1]">
               <xsl:value-of
                  select="(/tei:*/tei:teiHeader//tei:langUsage/tei:language/@ident)[normalize-space(.)][1]"
               />
            </xsl:when>

            <xsl:otherwise>

               <xsl:text>none</xsl:text>

            </xsl:otherwise>


         </xsl:choose>


      </xsl:variable>


      <xsl:variable name="textDirection">
         <xsl:value-of select="cudl:get-language-direction($languageCode)"/>
      </xsl:variable>



      <textDirection>
         <xsl:value-of select="$textDirection"/>
      </textDirection>


   </xsl:template>


   <!-- ****************************sourceData -->
   <!--path to source data for download - mainly hard coded-->
   <xsl:template name="get-sourceData">

      <sourceData>
         <xsl:value-of select="lambda:write-tei-services-link(root(.)/*,'metadata')"/>
      </sourceData>

   </xsl:template>

   <!--transcription flags-->
   <xsl:template name="get-transcription-flags">


      <!--rework this system of flags in favour of automatic tab creation at page level?-->
      <xsl:choose>
         <xsl:when test="//*:surface/*:media[contains(@mimeType,'transcription')]">
            <useTranscriptions>true</useTranscriptions>

            <xsl:if test="//*:surface/*:media[@mimeType='transcription_diplomatic']">

               <useDiplomaticTranscriptions>true</useDiplomaticTranscriptions>

            </xsl:if>

            <xsl:if test="//*:surface/*:media[@mimeType='transcription_normalised']">

               <useNormalisedTranscriptions>true</useNormalisedTranscriptions>

            </xsl:if>


         </xsl:when>

         <xsl:when test="//*:text/*:body/*:div[not(@type)]/*[not(local-name()='pb')]">

            <useTranscriptions>true</useTranscriptions>
            <useDiplomaticTranscriptions>true</useDiplomaticTranscriptions>

         </xsl:when>


      </xsl:choose>

      <xsl:if test="//*:surface/*:media[@mimeType='translation']">

         <useTranslations>true</useTranslations>

      </xsl:if>


      <xsl:if test="//*:text/*:body/*:div[@type='translation']/*[not(local-name()='pb')]">

         <useTranslations>true</useTranslations>

      </xsl:if>

   </xsl:template>


   <!--*******************Descriptive metadata************************************************************************************-->

   <!--This lays out descriptive metadata parts in the right hierarchy-->

   <!--Descriptive metadata is organised into 'parts' - these are not nesting - hierarchy is organised by ids (like METS)-->


   <xsl:template match="*:msDesc">

      <part>

         <!--if this is the top level, we need to pick up some general information-->
         <!--TODO - these should all really be moved to the top level-->

         <xsl:call-template name="get-doc-thumbnail"/>
         <xsl:call-template name="get-doc-image-rights"/>
         <xsl:call-template name="get-doc-metadata-rights"/>
         <xsl:call-template name="get-doc-pdf-rights"/>
         <xsl:call-template name="get-doc-watermark-statement"/>
         <xsl:call-template name="get-doc-authority"/>
         <xsl:call-template name="get-doc-funding"/>
         <xsl:call-template name="get-doc-subjects"/>
         <xsl:call-template name="get-doc-places"/>
         <xsl:call-template name="get-doc-metadata"/>


         <xsl:call-template name="get-doc-dmdID"/>
         <xsl:call-template name="get-calendarnum"/>


         <xsl:choose>
            <!-- if there is just one top-level msItem, merge into the document level -->
            <xsl:when test="count(*:msContents/*:msItem) = 1">

               <xsl:call-template name="get-doc-abstract"/>
               <xsl:call-template name="get-doc-and-item-names"/>
               <xsl:call-template name="get-doc-events"/>
               <xsl:call-template name="get-doc-physloc"/>
               <xsl:call-template name="get-doc-alt-ids"/>
               <xsl:call-template name="get-doc-physdesc"/>
               <xsl:call-template name="get-doc-history"/>
               <xsl:call-template name="get-doc-and-item-biblio"/>

               <!--not sure why this is called with a for-each - the above means that there will only ever be one msItem here-->
               <xsl:for-each select="*:msContents/*:msItem[1]">
                  <!--<xsl:call-template name="get-item-dmdID"/>-->
                  <xsl:call-template name="get-item-title">
                     <xsl:with-param name="display" select="'false'"/>
                  </xsl:call-template>
                  <xsl:call-template name="get-item-alt-titles"/>
                  <xsl:call-template name="get-item-desc-titles"/>
                  <xsl:call-template name="get-item-uniform-title"/>
                  <xsl:call-template name="get-item-languages"/>
                  <xsl:call-template name="get-item-excerpts"/>
                  <xsl:call-template name="get-item-notes"/>
                  <xsl:call-template name="get-item-filiation"/>
               </xsl:for-each>





            </xsl:when>
            <xsl:otherwise>

               <!-- Sequence of top-level msItems, so need to introduce additional top-level to represent item as a whole-->

               <!--<xsl:call-template name="get-doc-dmdID"/>-->
               <xsl:call-template name="get-doc-title"/>
               <xsl:call-template name="get-doc-alt-titles"/>
               <xsl:call-template name="get-doc-desc-titles"/>
               <xsl:call-template name="get-doc-uniform-title"/>
               <xsl:call-template name="get-doc-abstract"/>
               <xsl:call-template name="get-doc-languages"/>
               <!--<xsl:call-template name="get-doc-notes"/>-->
               <xsl:call-template name="get-doc-names"/>
               <xsl:call-template name="get-doc-events"/>
               <xsl:call-template name="get-doc-physloc"/>
               <xsl:call-template name="get-doc-alt-ids"/>
               <xsl:call-template name="get-doc-physdesc"/>
               <xsl:call-template name="get-doc-history"/>
               <xsl:call-template name="get-doc-biblio"/>

               <!-- Now process top-level msItems -->
               <!--<xsl:apply-templates select="*:msContents/*:msItem"/>-->

            </xsl:otherwise>
         </xsl:choose>




      </part>

      <!--process the rest of the msItems in this part-->
      <xsl:choose>
         <xsl:when test="count(*:msContents/*:msItem) = 1">
            <xsl:apply-templates select="*:msContents/*:msItem/*:msItem"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates select="*:msContents/*:msItem"/>
         </xsl:otherwise>
      </xsl:choose>
      <!--and then process the msParts-->
      <xsl:apply-templates select="*:msPart"/>

   </xsl:template>


   <xsl:template match="*:msPart">

      <part>



         <xsl:call-template name="get-msPart-dmdID"/>
         <xsl:call-template name="get-calendarnum"/>


         <xsl:choose>
            <!-- if there is just one top-level msItem, merge into the document level -->
            <xsl:when test="count(*:msContents/*:msItem) = 1">



               <xsl:call-template name="get-part-abstract"/>
               <xsl:call-template name="get-doc-and-item-names"/>
               <xsl:call-template name="get-doc-events"/>
               <xsl:call-template name="get-doc-physloc"/>
               <xsl:call-template name="get-doc-alt-ids"/>
               <xsl:call-template name="get-doc-physdesc"/>
               <xsl:call-template name="get-doc-history"/>
               <xsl:call-template name="get-doc-and-item-biblio"/>
               <xsl:call-template name="get-part-subjects"/>
               <xsl:call-template name="get-part-places"/>

               <!--not sure why this is called with a for-each - the above means that there will only ever be one msItem here-->
               <xsl:for-each select="*:msContents/*:msItem[1]">
                  <!--<xsl:call-template name="get-item-dmdID"/>-->
                  <xsl:call-template name="get-item-title">
                     <xsl:with-param name="display" select="'true'"/>
                  </xsl:call-template>
                  <xsl:call-template name="get-item-alt-titles"/>
                  <xsl:call-template name="get-item-desc-titles"/>
                  <xsl:call-template name="get-item-uniform-title"/>
                  <xsl:call-template name="get-item-languages"/>
                  <xsl:call-template name="get-item-excerpts"/>
                  <xsl:call-template name="get-item-notes"/>
                  <xsl:call-template name="get-item-filiation"/>
               </xsl:for-each>

            </xsl:when>
            <xsl:otherwise>

               <!-- Sequence of top-level msItems, so need to introduce additional top-level to represent item as a whole-->

               <!--<xsl:call-template name="get-doc-dmdID"/>-->
               <xsl:call-template name="get-doc-title"/>
               <xsl:call-template name="get-doc-alt-titles"/>
               <xsl:call-template name="get-doc-desc-titles"/>
               <xsl:call-template name="get-doc-uniform-title"/>
               <xsl:call-template name="get-part-abstract"/>
               <xsl:call-template name="get-doc-languages"/>
               <!--<xsl:call-template name="get-doc-notes"/>-->
               <xsl:call-template name="get-doc-names"/>
               <xsl:call-template name="get-doc-events"/>
               <!--<xsl:call-template name="get-doc-physloc"/>-->
               <xsl:call-template name="get-doc-alt-ids"/>
               <xsl:call-template name="get-doc-physdesc"/>
               <xsl:call-template name="get-doc-history"/>
               <xsl:call-template name="get-doc-biblio"/>
               <xsl:call-template name="get-part-subjects"/>
               <xsl:call-template name="get-part-places"/>
               <!-- Now process top-level msItems -->
               <!--<xsl:apply-templates select="*:msContents/*:msItem"/>-->

            </xsl:otherwise>
         </xsl:choose>


      </part>

      <!--process the rest of the msItems in this part-->
      <xsl:choose>
         <xsl:when test="count(*:msContents/*:msItem) = 1">
            <xsl:apply-templates select="*:msContents/*:msItem/*:msItem"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates select="*:msContents/*:msItem"/>
         </xsl:otherwise>
      </xsl:choose>

      <!--process the msParts in this part-->
      <xsl:apply-templates select="*:msPart"/>

   </xsl:template>



   <!--each msItem is also a part-->
   <xsl:template match="*:msItem">

      <part>

         <xsl:call-template name="get-item-dmdID"/>
         <xsl:call-template name="get-calendarnum"/>
         <xsl:call-template name="get-item-title">
            <xsl:with-param name="display" select="'true'"/>
         </xsl:call-template>

         <xsl:call-template name="get-item-alt-titles"/>
         <xsl:call-template name="get-item-desc-titles"/>
         <xsl:call-template name="get-item-uniform-title"/>
         <xsl:call-template name="get-item-names"/>
         <xsl:call-template name="get-item-languages"/>

         <xsl:call-template name="get-item-excerpts"/>
         <xsl:call-template name="get-item-notes"/>

         <xsl:call-template name="get-item-filiation"/>

         <xsl:call-template name="get-item-biblio"/>

      </part>

      <!-- Any child items of this item -->
      <xsl:apply-templates select="*:msContents/*:msItem|*:msItem"/>

   </xsl:template>



   <!--*************************and these are the templates which fill in descriptive metadata fields-->

   <!--DMDIDs-->

   <!--for the whole document-->
   <xsl:template name="get-doc-dmdID">

      <ID>
         <xsl:value-of select="'DOCUMENT'"/>
      </ID>

      <fileID>
         <xsl:value-of select="$fileID"/>
      </fileID>

      <startPage>1</startPage>
      <!--documents always start on page 1!-->
      <startPageLabel>

         <xsl:choose>
            <xsl:when test="//*:facsimile/*:surface[1][normalize-space(@n)]">
               <xsl:value-of select="//*:facsimile/*:surface[1]/@n"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:text>1</xsl:text>
            </xsl:otherwise>
         </xsl:choose>

      </startPageLabel>

   </xsl:template>


   <!--for msParts-->
   <xsl:template name="get-msPart-dmdID">

      <!--incrementing number to give a unique id-->
      <xsl:variable name="n-tree">
         <xsl:value-of
            select="sum((count(ancestor-or-self::*[local-name()='msPart']), count(preceding::*[local-name()='msPart'])))"
         />
      </xsl:variable>


      <ID>
         <xsl:value-of select="concat('PART-', normalize-space($n-tree))"/>
      </ID>

      <fileID>
         <xsl:value-of select="$fileID"/>
      </fileID>

      <xsl:variable name="startPageLabel">
         <!--should always be a locus attached to an msItem - but defaults to first page if none present-->
         <xsl:choose>
            <xsl:when test="*:msContents/*:msItem[1]/*:locus[1]/@from">
               <xsl:value-of select="*:msContents/*:msItem[1]/*:locus[1]/normalize-space(@from)"/>

            </xsl:when>
            <xsl:when test="//*:facsimile/*:surface[1]/@n">
               <xsl:value-of select="//*:facsimile/*:surface[1]/normalize-space(@n)"/>

            </xsl:when>
            <xsl:otherwise>
               <xsl:text>cover</xsl:text>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>



      <startPageLabel>
         <xsl:value-of select="$startPageLabel"/>

      </startPageLabel>

      <xsl:variable name="startPage">

         <xsl:choose>
             <xsl:when test="key('surfaceNs', $startPageLabel)">
                <xsl:apply-templates select="key('surfaceNs', $startPageLabel)" mode="count"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:text>cover</xsl:text>
            </xsl:otherwise>
         </xsl:choose>

      </xsl:variable>

      <startPage>
         <xsl:value-of select="$startPage"/>
      </startPage>

   </xsl:template>



   <!--for individual items-->
   <xsl:template name="get-item-dmdID">

      <!--incrementing number to give a unique id-->
      <xsl:variable name="n-tree">

         <xsl:value-of
            select="sum((count(ancestor-or-self::*[local-name()='msItem']), count(preceding::*[local-name()='msItem'])))"
         />
      </xsl:variable>

      <ID>
         <xsl:value-of select="concat('ITEM-', normalize-space($n-tree))"/>
      </ID>

      <fileID>
         <xsl:value-of select="$fileID"/>
      </fileID>

      <xsl:variable name="startPageLabel">
         <!--should always be a locus attached to an msItem - but defaults to first page if none present-->
         <xsl:choose>
            <xsl:when test="*:locus/@from">
               <xsl:value-of select="normalize-space(*:locus/@from)"/>

            </xsl:when>
            <xsl:when test="//*:facsimile/*:surface[1]/@n">
               <xsl:value-of select="normalize-space(//*:facsimile/*:surface[1]/@n)"/>

            </xsl:when>
            <xsl:otherwise>
               <xsl:text>cover</xsl:text>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <startPageLabel>
         <xsl:value-of select="$startPageLabel"/>

      </startPageLabel>

      <xsl:variable name="startPage">

         <xsl:choose>
             <xsl:when test="key('surfaceNs', $startPageLabel)">
                <xsl:apply-templates select="key('surfaceNs', $startPageLabel)" mode="count"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:text>cover</xsl:text>
            </xsl:otherwise>
         </xsl:choose>

      </xsl:variable>

      <startPage>
         <xsl:value-of select="$startPage"/>
      </startPage>

   </xsl:template>


   <!--TITLES-->

   <!--main titles-->
   <!--whole document titles where there are multiple msItems are found in the summary - if not present, defaults to classmark-->


   <xsl:template name="get-doc-title">
      <title>
         <xsl:variable name="title">

            <xsl:choose>

               <xsl:when test="*:head">
                  <xsl:value-of select="normalize-space(*:head)"/>
               </xsl:when>
               <xsl:when test="*:msIdentifier/*:msName">
                  <xsl:value-of select="normalize-space(*:msIdentifier/*:msName)"/>
               </xsl:when>
               <xsl:when test="*:msContents/*:summary//*:title[not(@type)]">
                  <xsl:for-each-group select="*:msContents/*:summary//*:title[not(@type)]"
                     group-by="normalize-space(.)">
                     <xsl:value-of select="normalize-space(.)"/>
                     <xsl:if test="not(position()=last())">
                        <xsl:text>, </xsl:text>
                     </xsl:if>
                  </xsl:for-each-group>
               </xsl:when>
               <xsl:when test="*:msIdentifier/*:idno">
                  <xsl:for-each-group select="*:msIdentifier/*:idno" group-by="normalize-space(.)">
                     <xsl:value-of select="normalize-space(.)"/>
                     <xsl:if test="not(position()=last())">
                        <xsl:text>, </xsl:text>
                     </xsl:if>
                  </xsl:for-each-group>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:text>Untitled Document</xsl:text>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>



         <xsl:choose>
            <xsl:when test="name() eq 'msDesc'">
               <xsl:attribute name="display" select="'false'"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:attribute name="display" select="'true'"/>
            </xsl:otherwise>
         </xsl:choose>



         <xsl:attribute name="displayForm" select="$title"/>

         <xsl:value-of select="$title"/>

      </title>
   </xsl:template>


   <!--item titles-->
   <xsl:template name="get-item-title">
      <xsl:param name="display" select="'true'"/>



      <title>


         <xsl:variable name="title">
            <xsl:choose>
               <xsl:when test="normalize-space(*:title[not(@type)][1])">
                  <xsl:value-of select="normalize-space(*:title[not(@type)][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(*:title[@type='general'][1])">
                  <xsl:value-of select="normalize-space(*:title[@type='general'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(*:title[@type='desc'][1])">
                  <xsl:value-of select="normalize-space(*:title[@type='desc'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(*:title[@type='standard'][1])">
                  <xsl:value-of select="normalize-space(*:title[@type='standard'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(*:title[@type='supplied'][1])">
                  <xsl:value-of select="normalize-space(*:title[@type='supplied'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(*:rubric[1])">
                  <xsl:variable name="rubric_title">

                     <xsl:apply-templates select="*:rubric[1]" mode="title"/>

                  </xsl:variable>

                  <xsl:value-of select="normalize-space($rubric_title)"/>
               </xsl:when>

               <xsl:when test="normalize-space(*:incipit[1])">
                  <xsl:variable name="incipit_title">

                     <xsl:apply-templates select="*:incipit[1]" mode="title"/>

                  </xsl:variable>

                  <xsl:value-of select="normalize-space($incipit_title)"/>
               </xsl:when>


               <xsl:otherwise>
                  <xsl:text>Untitled Item</xsl:text>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>

         <xsl:attribute name="display" select="$display"/>

         <xsl:attribute name="displayForm" select="$title"/>

         <xsl:value-of select="$title"/>

      </title>
   </xsl:template>


   <!--alternative titles-->
   <xsl:template name="get-doc-alt-titles">

      <xsl:if test="*:msContents/*:summary/*:title[@type='alt']">

         <alternativeTitles>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:for-each select="*:msContents/*:summary/*:title[@type='alt']">

               <!-- <xsl:if test="not(normalize-space(.) = '')"> -->

               <xsl:if test="normalize-space(.)">

                  <alternativeTitle>

                     <xsl:attribute name="display" select="'true'"/>

                     <xsl:attribute name="displayForm" select="normalize-space(.)"/>

                     <xsl:value-of select="normalize-space(.)"/>
                  </alternativeTitle>

               </xsl:if>

            </xsl:for-each>

         </alternativeTitles>

      </xsl:if>

   </xsl:template>


   <xsl:template name="get-item-alt-titles">

      <xsl:if test="*:title[@type='alt']">

         <alternativeTitles>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:for-each select="*:title[@type='alt']">

               <xsl:if test="normalize-space(.)">

                  <alternativeTitle>

                     <xsl:attribute name="display" select="'true'"/>

                     <xsl:attribute name="displayForm" select="normalize-space(.)"/>

                     <xsl:value-of select="normalize-space(.)"/>
                  </alternativeTitle>

               </xsl:if>

            </xsl:for-each>
         </alternativeTitles>

      </xsl:if>

   </xsl:template>

   <!--descriptive titles-->
   <xsl:template name="get-doc-desc-titles">

      <xsl:if test="*:msContents/*:summary/*:title[@type='desc']">

         <descriptiveTitles>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:for-each select="*:msContents/*:summary/*:title[@type='desc']">

               <!-- <xsl:if test="not(normalize-space(.) = '')"> -->

               <xsl:if test="normalize-space(.)">

                  <descriptiveTitle>

                     <xsl:attribute name="display" select="'true'"/>

                     <xsl:attribute name="displayForm" select="normalize-space(.)"/>

                     <xsl:value-of select="normalize-space(.)"/>
                  </descriptiveTitle>

               </xsl:if>

            </xsl:for-each>

         </descriptiveTitles>

      </xsl:if>

   </xsl:template>

   <xsl:template name="get-item-desc-titles">

      <xsl:if test="*:title[@type='desc']">

         <descriptiveTitles>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:for-each select="*:title[@type='desc']">

               <xsl:if test="normalize-space(.)">

                  <descriptiveTitle>

                     <xsl:attribute name="display" select="'true'"/>

                     <xsl:attribute name="displayForm" select="normalize-space(.)"/>

                     <xsl:value-of select="normalize-space(.)"/>
                  </descriptiveTitle>

               </xsl:if>

            </xsl:for-each>
         </descriptiveTitles>

      </xsl:if>

   </xsl:template>


   <!--uniform title-->
   <xsl:template name="get-doc-uniform-title">

      <xsl:variable name="uniformTitle" select="*:msContents/*:summary/*:title[@type='uniform'][1]"/>

      <xsl:if test="normalize-space($uniformTitle)">

         <uniformTitle>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:attribute name="displayForm" select="normalize-space($uniformTitle)"/>

            <xsl:value-of select="normalize-space($uniformTitle)"/>

         </uniformTitle>

      </xsl:if>

   </xsl:template>

   <xsl:template name="get-item-uniform-title">

      <xsl:variable name="uniformTitle" select="*:title[@type='uniform'][1]"/>

      <xsl:if test="normalize-space($uniformTitle)">

         <uniformTitle>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:attribute name="displayForm" select="normalize-space($uniformTitle)"/>

            <xsl:value-of select="normalize-space($uniformTitle)"/>

         </uniformTitle>

      </xsl:if>

   </xsl:template>


   <!--ABSTRACTS-->

   <xsl:template name="get-doc-abstract">

      <xsl:if
         test="(ancestor-or-self::tei:teiHeader[1]//tei:profileDesc/tei:abstract,*:msContents/*:summary)[normalize-space(.)][1]">

         <abstract>

            <xsl:variable name="abstract">
               <xsl:apply-templates
                  select="(ancestor-or-self::tei:teiHeader[1]//tei:profileDesc/tei:abstract,*:msContents/*:summary)[normalize-space(.)][1]"
                  mode="html"/>
            </xsl:variable>

            <xsl:attribute name="display" select="'false'"/>

            <xsl:attribute name="displayForm" select="normalize-space($abstract)"/>

            <!-- <xsl:value-of select="normalize-space($abstract)" /> -->
            <xsl:value-of select="normalize-space(replace($abstract, '&lt;[^&gt;]+&gt;', ''))"/>

         </abstract>

      </xsl:if>

   </xsl:template>

   <xsl:template name="get-part-abstract">

      <xsl:if
         test="(ancestor-or-self::tei:teiHeader[1]//tei:profileDesc/tei:abstract,*:msContents/*:summary)[normalize-space(.)][1]">

         <abstract>

            <xsl:variable name="abstract">
               <xsl:apply-templates
                  select="(ancestor-or-self::tei:teiHeader[1]//tei:profileDesc/tei:abstract,*:msContents/*:summary)[normalize-space(.)][1]"
                  mode="html"/>
            </xsl:variable>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:attribute name="displayForm" select="normalize-space($abstract)"/>

            <!-- <xsl:value-of select="normalize-space($abstract)" /> -->
            <xsl:value-of select="normalize-space(replace($abstract, '&lt;[^&gt;]+&gt;', ''))"/>

         </abstract>

      </xsl:if>

   </xsl:template>

   <xsl:template match="*:summary" mode="html">

      <!--we need to put this in a paragraph if the summary itself contains no paragraphs-->
      <xsl:choose>
         <xsl:when test=".//*:seg[@type='para']">


            <xsl:apply-templates mode="html"/>

         </xsl:when>
         <xsl:otherwise>

            <xsl:text>&lt;p style=&apos;text-align: justify;&apos;&gt;</xsl:text>
            <xsl:apply-templates mode="html"/>
            <xsl:text>&lt;/p&gt;</xsl:text>


         </xsl:otherwise>

      </xsl:choose>


   </xsl:template>

   <xsl:template match="tei:abstract" mode="html">
      <xsl:apply-templates mode="#current"/>
   </xsl:template>

   <!--SUBJECTS-->
   <xsl:template name="get-doc-subjects">

      <xsl:if test="//*:profileDesc/*:textClass/*:keywords/*:list/*:item/*:term[not(@ref)][not(@type='placename')]">

         <subjects>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:for-each
               select="//*:profileDesc/*:textClass/*:keywords/*:list/*:item/*:term[not(@ref)][not(@type='placename')]">

               <xsl:if test="normalize-space(.)">

                  <subject>

                     <xsl:attribute name="display" select="'true'"/>

                     <xsl:attribute name="displayForm" select="normalize-space(.)"/>

                     <fullForm>
                        <xsl:value-of select="normalize-space(.)"/>
                     </fullForm>

                     <xsl:if test="(starts-with(@key, 'subject_sh'))">
                        <authority>
                           <xsl:text>Library of Congress Subject Headings</xsl:text>
                        </authority>
                        <authorityURI>
                           <xsl:text>http://id.loc.gov/authorities/about.html#lcsh</xsl:text>
                        </authorityURI>
                        <valueURI>
                           <xsl:value-of select="@key"/>
                        </valueURI>
                     </xsl:if>

                  </subject>

               </xsl:if>

            </xsl:for-each>


         </subjects>
      </xsl:if>

   </xsl:template>


   <xsl:template name="get-part-subjects">

      <xsl:variable name="mspart_id" select="@xml:id"/>
      <xsl:variable name="mspart_id_ref">
         <xsl:if test="normalize-space($mspart_id)">
            <xsl:value-of select="concat('#', $mspart_id)"/>
         </xsl:if>

      </xsl:variable>


      <xsl:if
         test="//*:profileDesc/*:textClass/*:keywords/*:list/*:item/*:term[@ref=$mspart_id_ref][not(@type='placename')]">

         <subjects>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:for-each
               select="//*:profileDesc/*:textClass/*:keywords/*:list/*:item/*:term[@ref=$mspart_id_ref][not(@type='placename')]">

               <xsl:if test="normalize-space(.)">

                  <subject>

                     <xsl:attribute name="display" select="'true'"/>

                     <xsl:attribute name="displayForm" select="normalize-space(.)"/>

                     <fullForm>
                        <xsl:value-of select="normalize-space(.)"/>
                     </fullForm>

                     <xsl:if test="(starts-with(@key, 'subject_sh'))">
                        <authority>
                           <xsl:text>Library of Congress Subject Headings</xsl:text>
                        </authority>
                        <authorityURI>
                           <xsl:text>http://id.loc.gov/authorities/about.html#lcsh</xsl:text>
                        </authorityURI>
                        <valueURI>
                           <xsl:value-of select="@key"/>
                        </valueURI>
                     </xsl:if>

                  </subject>

               </xsl:if>

            </xsl:for-each>


         </subjects>
      </xsl:if>

   </xsl:template>
   
   
   <!--PLACES-->
   
   <xsl:template name="get-doc-places">
      
      <xsl:if test="//*:profileDesc/*:textClass/*:keywords/*:list/*:item/*:term[not(@ref)][@type='placename']">
         
         <places>
            
            <xsl:attribute name="display" select="'true'"/>
            
            <xsl:for-each
               select="//*:profileDesc/*:textClass/*:keywords/*:list/*:item/*:term[not(@ref)][@type='placename']">
               
               <xsl:if test="normalize-space(.)">
                  
                  <place>
                     
                     <xsl:attribute name="display" select="'true'"/>
                     
                     <xsl:attribute name="displayForm" select="normalize-space(.)"/>
                     
                     <fullForm>
                        <xsl:value-of select="normalize-space(.)"/>
                     </fullForm>
                     
                  </place>
                  
               </xsl:if>
               
            </xsl:for-each>
            
            
         </places>
      </xsl:if>
      
   </xsl:template>
   
   
   <xsl:template name="get-part-places">
      
      <xsl:variable name="mspart_id" select="@xml:id"/>
      <xsl:variable name="mspart_id_ref">
         <xsl:if test="normalize-space($mspart_id)">
            <xsl:value-of select="concat('#', $mspart_id)"/>
         </xsl:if>
         
      </xsl:variable>
      
      
      <xsl:if
         test="//*:profileDesc/*:textClass/*:keywords/*:list/*:item/*:term[@ref=$mspart_id_ref][@type='placename']">
         
         <places>
            
            <xsl:attribute name="display" select="'true'"/>
            
            <xsl:for-each
               select="//*:profileDesc/*:textClass/*:keywords/*:list/*:item/*:term[@ref=$mspart_id_ref][@type='placename']">
               
               <xsl:if test="normalize-space(.)">
                  
                  <place>
                     
                     <xsl:attribute name="display" select="'true'"/>
                     
                     <xsl:attribute name="displayForm" select="normalize-space(.)"/>
                     
                     <fullForm>
                        <xsl:value-of select="normalize-space(.)"/>
                     </fullForm>
                     
                     
                     
                  </place>
                  
               </xsl:if>
               
            </xsl:for-each>
            
            
         </places>
      </xsl:if>
      
   </xsl:template>
   
   

   <!--EVENTS-->
   <xsl:template name="get-doc-events">

      <xsl:choose>
         <xsl:when test="//*:editor[@role='pbl'] and *:history/*:origin">

            <!--publication-->
            <publications>

               <xsl:attribute name="display" select="'true'"/>

               <!--will there only ever be one of these?-->
               <xsl:for-each select="*:history/*:origin">
                  <event>

                     <type>publication</type>

                     <xsl:variable name="place-elems" as="item()*">
                        <xsl:variable name="item_teiHeader"
                           select="ancestor-or-self::tei:teiHeader[1]"/>
                        <xsl:choose>
                           <xsl:when
                              test="exists($item_teiHeader//tei:profileDesc/tei:correspDesc/tei:correspAction//tei:placeName)">
                              <xsl:copy-of
                                 select="$item_teiHeader//tei:profileDesc/tei:correspDesc/tei:correspAction//tei:placeName"
                              />
                           </xsl:when>
                           <xsl:otherwise>
                              <xsl:copy-of select="descendant::*:origPlace"/>
                           </xsl:otherwise>
                        </xsl:choose>
                     </xsl:variable>

                     <xsl:if test="$place-elems">
                        <places>

                           <xsl:attribute name="display" select="'true'"/>

                           <xsl:for-each select="$place-elems">
                              <place>
                                 <xsl:attribute name="display" select="'true'"/>

                                 <xsl:attribute name="displayForm" select="normalize-space(.)"/>
                                 <shortForm>
                                    <xsl:value-of select="normalize-space(.)"/>
                                 </shortForm>
                                 <fullForm>
                                    <xsl:value-of select="normalize-space(.)"/>
                                 </fullForm>
                              </place>

                           </xsl:for-each>
                        </places>
                     </xsl:if>

                     <xsl:variable name="preferred-date-elem" as="item()*">
                        <xsl:variable name="correspAction-elems"
                           select="ancestor-or-self::tei:teiHeader[1]//tei:correspDesc/tei:correspAction"
                           as="item()*"/>
                        <xsl:copy-of
                           select="($correspAction-elems[@type='sent']//tei:date,$correspAction-elems[not(@type='sent')]//tei:date,.//*:origDate,.//*:date)[1]"
                        />
                     </xsl:variable>

                     <xsl:if test="not(empty($preferred-date-elem))">
                        <xsl:call-template name="output-date-elems">
                           <xsl:with-param name="date_elem" select="$preferred-date-elem"/>
                        </xsl:call-template>
                     </xsl:if>

                     <publishers>
                        <xsl:attribute name="display" select="'true'"/>

                        <xsl:apply-templates select="//*:editor[@role='pbl']" mode="publisher"/>

                     </publishers>


                  </event>
               </xsl:for-each>



            </publications>



         </xsl:when>

         <xsl:when
            test="*:history/*:origin 
                         |
                         ancestor-or-self::tei:teiHeader[1]//tei:profileDesc/tei:correspDesc/tei:correspAction[descendant::tei:placeName|descendant::tei:date]">


            <!--creation-->
            <creations>

               <xsl:attribute name="display" select="'true'"/>

               <xsl:variable name="context-elem" as="item()*">
                  <xsl:choose>
                     <xsl:when
                        test="ancestor-or-self::tei:teiHeader[1]//tei:profileDesc/tei:correspDesc">
                        <xsl:copy-of
                           select="ancestor-or-self::tei:teiHeader[1]//tei:profileDesc/tei:correspDesc"
                        />
                     </xsl:when>
                     <xsl:when test="*:history/*:origin">
                        <!--will there only ever be one of these?-->
                        <xsl:copy-of select="*:history/*:origin"/>
                     </xsl:when>
                  </xsl:choose>
               </xsl:variable>

               <xsl:for-each select="$context-elem">
                  <event>

                     <type>creation</type>

                     <xsl:variable name="place-elems" as="item()*">
                        <xsl:choose>
                           <xsl:when test="exists(tei:correspAction//tei:placeName)">
                              <xsl:copy-of select="tei:correspAction//tei:placeName"/>
                           </xsl:when>
                           <xsl:otherwise>
                              <xsl:copy-of select="descendant::*:origPlace"/>
                           </xsl:otherwise>
                        </xsl:choose>
                     </xsl:variable>

                     <xsl:if test="not(empty($place-elems))">
                        <places>

                           <xsl:attribute name="display" select="'true'"/>

                           <xsl:for-each select="$place-elems">
                              <place>
                                 <xsl:attribute name="display" select="'true'"/>

                                 <xsl:attribute name="displayForm" select="normalize-space(.)"/>
                                 <shortForm>
                                    <xsl:value-of select="normalize-space(.)"/>
                                 </shortForm>
                                 <fullForm>
                                    <xsl:value-of select="normalize-space(.)"/>
                                 </fullForm>
                              </place>

                           </xsl:for-each>
                        </places>
                     </xsl:if>


                     <xsl:variable name="preferred-date-elem" as="item()*">
                        <xsl:variable name="correspAction-elems"
                           select="$context-elem//tei:correspAction" as="item()*"/>
                        <xsl:copy-of
                           select="($correspAction-elems[@type='sent']//tei:date,$correspAction-elems[not(@type='sent')]//tei:date,.//*:origDate,.//*:date)[1]"
                        />
                     </xsl:variable>

                     <xsl:if test="not(empty($preferred-date-elem))">
                        <xsl:call-template name="output-date-elems">
                           <xsl:with-param name="date_elem" select="$preferred-date-elem"/>
                        </xsl:call-template>
                     </xsl:if>

                  </event>
               </xsl:for-each>


            </creations>
         </xsl:when>

      </xsl:choose>


      <!--acquisition-->
      <xsl:if test="*:history/*:acquisition">

         <acquisitions>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:for-each select="*:history/*:acquisition">
               <event>

                  <type>acquisition</type>

                  <xsl:for-each select=".//*:date[1][not (parent::*:date)]">

                     <xsl:choose>
                        <xsl:when test="@from">
                           <dateStart>
                              <xsl:value-of select="@from"/>
                           </dateStart>
                        </xsl:when>
                        <xsl:when test="@notBefore">
                           <dateStart>
                              <xsl:value-of select="@notBefore"/>
                           </dateStart>
                        </xsl:when>
                        <xsl:when test="@when">
                           <dateStart>
                              <xsl:value-of select="@when"/>
                           </dateStart>
                        </xsl:when>
                        <xsl:otherwise> </xsl:otherwise>
                     </xsl:choose>

                     <xsl:choose>
                        <xsl:when test="@to">
                           <dateEnd>
                              <xsl:value-of select="@to"/>
                           </dateEnd>
                        </xsl:when>
                        <xsl:when test="@notAfter">
                           <dateEnd>
                              <xsl:value-of select="@notBefore"/>
                           </dateEnd>
                        </xsl:when>
                        <xsl:when test="@when">
                           <dateEnd>
                              <xsl:value-of select="@when"/>
                           </dateEnd>
                        </xsl:when>
                        <xsl:otherwise> </xsl:otherwise>
                     </xsl:choose>

                     <dateDisplay>

                        <xsl:attribute name="display" select="'true'"/>

                        <xsl:attribute name="displayForm" select="normalize-space(.)"/>

                        <xsl:value-of select="normalize-space(.)"/>
                     </dateDisplay>

                  </xsl:for-each>
               </event>
            </xsl:for-each>

         </acquisitions>
      </xsl:if>

   </xsl:template>


   <xsl:template match="*:editor[@role='pbl']" mode="publisher">

      <publisher>

         <xsl:attribute name="display" select="'true'"/>

         <xsl:attribute name="displayForm" select="normalize-space(.)"/>


         <xsl:value-of select="normalize-space(.)"/>



      </publisher>


   </xsl:template>

   <!--LOCATION AND CLASSMARK-->
   <xsl:template name="get-doc-physloc">

      <xsl:if test="*:msIdentifier/*:repository[normalize-space(.)]">

         <physicalLocation>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:attribute name="displayForm" select="normalize-space(*:msIdentifier/*:repository)"/>

            <xsl:value-of select="normalize-space(*:msIdentifier/*:repository)"/>

         </physicalLocation>
      </xsl:if>
      <xsl:variable name="shelfLocator_elem" as="item()*">
         <xsl:choose>
            <xsl:when
               test="ancestor-or-self::tei:teiHeader[1]/tei:fileDesc/tei:sourceDesc/tei:bibl[normalize-space(.)]">
               <xsl:copy-of
                  select="(ancestor-or-self::tei:teiHeader[1]/tei:fileDesc/tei:sourceDesc/tei:bibl[normalize-space(.)])[1]"
               />
            </xsl:when>
            <xsl:otherwise>
               <xsl:copy-of select="*:msIdentifier/*:idno"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:if test="$shelfLocator_elem[normalize-space(.)]">
         <shelfLocator>
            <xsl:attribute name="display" select="'true'"/>
            <xsl:attribute name="displayForm" select="normalize-space($shelfLocator_elem)"/>
            <xsl:value-of select="normalize-space($shelfLocator_elem)"/>
         </shelfLocator>
      </xsl:if>

   </xsl:template>

   <!--ALTERNATIVE IDENTIFIERS-->
   <xsl:template name="get-doc-alt-ids">

      <xsl:if
         test="normalize-space(*:msIdentifier/*:altIdentifier[not(@type='internal')][1]/*:idno)">

         <altIdentifiers>

            <xsl:attribute name="display" select="'true'"/>


            <xsl:for-each select="*:msIdentifier/*:altIdentifier[not(@type='internal')]/*:idno">

               <altIdentifier>
                  <xsl:attribute name="display" select="'true'"/>
                  <xsl:attribute name="displayForm" select="normalize-space(.)"/>

                  <xsl:value-of select="normalize-space(.)"/>


               </altIdentifier>



            </xsl:for-each>

         </altIdentifiers>

      </xsl:if>

   </xsl:template>


   <!--THUMBNAIL-->
   <xsl:template name="get-doc-thumbnail">

      <xsl:if test="count(//*:graphic[@decls='#document-thumbnail']) gt 1">
         <xsl:message select="concat('WARN: More than one #document-thumbnail block in ', tokenize(document-uri(/), '/')[last()])"/>
      </xsl:if>
      
      <xsl:variable name="graphic" select="(//*:graphic[@decls='#document-thumbnail'])[1]"/>

      <xsl:if test="$graphic">

         <thumbnailUrl>
            <xsl:value-of select="normalize-space($graphic/@url)"/>
         </thumbnailUrl>

         <thumbnailOrientation>
            <xsl:choose>
               <xsl:when test="$graphic/@rend = 'portrait'">
                  <xsl:value-of select="'portrait'"/>
               </xsl:when>
               <xsl:when test="$graphic/@rend = 'landscape'">
                  <xsl:value-of select="'landscape'"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:value-of select="'portrait'"/>
               </xsl:otherwise>
            </xsl:choose>
         </thumbnailOrientation>

      </xsl:if>

   </xsl:template>



   <!-- RIGHTS-->
   <xsl:template name="get-doc-image-rights">

      <displayImageRights>
         <xsl:value-of
            select="normalize-space(//*:publicationStmt/*:availability[@xml:id='displayImageRights'])"
         />
      </displayImageRights>

      <downloadImageRights>
         <xsl:value-of
            select="normalize-space(//*:publicationStmt/*:availability[@xml:id='downloadImageRights'])"
         />
      </downloadImageRights>

      <imageReproPageURL>
         <xsl:value-of
            select="cudl:get-imageReproPageURL(normalize-space(*:msIdentifier/*:repository), normalize-space(*:msIdentifier/*:idno))"
         />
      </imageReproPageURL>

   </xsl:template>

   <xsl:template name="get-doc-metadata-rights">

      <metadataRights>
         <xsl:value-of
            select="normalize-space(//*:publicationStmt/*:availability[@xml:id='metadataRights'])"/>
      </metadataRights>

   </xsl:template>

   <xsl:template name="get-doc-pdf-rights">

      <pdfRights>
         <xsl:value-of
            select="normalize-space(//*:publicationStmt/*:availability[@xml:id='pdfRights'])"/>
      </pdfRights>

   </xsl:template>


   <xsl:template name="get-doc-watermark-statement">

      <watermarkStatement>
         <xsl:value-of
            select="normalize-space(//*:publicationStmt/*:availability[@xml:id='watermark'])"/>
      </watermarkStatement>

   </xsl:template>

   <!--AUTHORITY-->
   <xsl:template name="get-doc-authority">

      <docAuthority>

         <xsl:variable name="authority">
            <xsl:apply-templates select="//*:publicationStmt/*:authority" mode="html"/>

         </xsl:variable>

         <xsl:value-of select="normalize-space($authority)"/>

      </docAuthority>

   </xsl:template>

   <xsl:template match="*:authority" mode="html">
      <xsl:apply-templates mode="html"/>
   </xsl:template>

   <!--COMPLETENESS-->

   <xsl:template match="*:note[@type='completeness']">
      <completeness>

         <xsl:value-of select="normalize-space(.)"/>
      </completeness>
   </xsl:template>

   <!--FUNDING-->
   <xsl:template name="get-doc-funding">

      <fundings>

         <xsl:variable name="funding">
            <xsl:apply-templates select="//*:titleStmt/*:funder" mode="html"/>
         </xsl:variable>

         <xsl:attribute name="display" select="'true'"/>
         <funding>
            <xsl:attribute name="display" select="'true'"/>
            <xsl:attribute name="displayForm" select="normalize-space($funding)"/>
            <xsl:value-of select="normalize-space($funding)"/>
         </funding>
      </fundings>

   </xsl:template>

   <!--PHYSICAL DESCRIPTION-->
   <!--general physical description either in p tag or a list - often used as a general summary for composite manuscripts where physDesc has msParts-->
   <xsl:template name="get-doc-physdesc">

      <xsl:if test="exists(*:physDesc/*:p|*:physDesc/*:list)">

         <physdesc>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:variable name="physdesc">
               <xsl:apply-templates select="*:physDesc/*:p|*:physDesc/*:list" mode="html"/>

            </xsl:variable>

            <xsl:attribute name="displayForm" select="normalize-space($physdesc)"/>

            <!-- <xsl:value-of select="normalize-space($physdesc)" /> -->
            <xsl:value-of select="normalize-space(replace($physdesc, '&lt;[^&gt;]+&gt;', ''))"/>

         </physdesc>

      </xsl:if>

      <xsl:if test="normalize-space(*:physDesc/*:objectDesc/@form)">

         <form>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:variable name="form">
               <xsl:apply-templates select="*:physDesc/*:objectDesc/@form" mode="html"/>


            </xsl:variable>

            <xsl:attribute name="displayForm" select="normalize-space($form)"/>

            <xsl:value-of select="normalize-space(replace($form, '&lt;[^&gt;]+&gt;', ''))"/>

         </form>

      </xsl:if>

      <xsl:if test="normalize-space(*:physDesc/*:objectDesc/*:supportDesc/*:support)">

         <material>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:variable name="material">
               <xsl:apply-templates select="*:physDesc/*:objectDesc/*:supportDesc/*:support"
                  mode="html"/>


            </xsl:variable>

            <xsl:attribute name="displayForm" select="normalize-space($material)"/>

            <!-- <xsl:value-of select="normalize-space($material)" /> -->
            <xsl:value-of select="normalize-space(replace($material, '&lt;[^&gt;]+&gt;', ''))"/>

         </material>

      </xsl:if>

      <xsl:if test="normalize-space(*:physDesc/*:objectDesc/*:supportDesc/*:extent)">

         <extent>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:variable name="extent">
               <xsl:apply-templates select="*:physDesc/*:objectDesc/*:supportDesc/*:extent"
                  mode="html"/>

            </xsl:variable>

            <xsl:attribute name="displayForm" select="normalize-space($extent)"/>

            <!-- <xsl:value-of select="normalize-space($extent)" /> -->
            <xsl:value-of select="normalize-space(replace($extent, '&lt;[^&gt;]+&gt;', ''))"/>

         </extent>

      </xsl:if>

      <xsl:if test="*:physDesc/*:objectDesc/*:supportDesc/*:foliation">

         <foliation>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:variable name="foliation">
               <xsl:apply-templates select="*:physDesc/*:objectDesc/*:supportDesc/*:foliation"
                  mode="html"/>

            </xsl:variable>

            <xsl:attribute name="displayForm" select="normalize-space($foliation)"/>
            <!-- <xsl:value-of select="normalize-space($foliation)" /> -->
            <xsl:value-of select="normalize-space(replace($foliation, '&lt;[^&gt;]+&gt;', ''))"/>

         </foliation>

      </xsl:if>


      <xsl:if test="*:physDesc/*:objectDesc/*:supportDesc/*:collation">

         <collation>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:variable name="collation">
               <xsl:apply-templates select="*:physDesc/*:objectDesc/*:supportDesc/*:collation"
                  mode="html"/>

            </xsl:variable>

            <xsl:attribute name="displayForm" select="normalize-space($collation)"/>
            <xsl:value-of select="normalize-space(replace($collation, '&lt;[^&gt;]+&gt;', ''))"/>

         </collation>

      </xsl:if>


      <xsl:if test="normalize-space(*:physDesc/*:objectDesc/*:supportDesc/*:condition)">

         <conditions>

            <xsl:attribute name="display" select="'true'"/>

            <condition>

               <xsl:attribute name="display" select="'true'"/>

               <xsl:variable name="condition">
                  <xsl:apply-templates select="*:physDesc/*:objectDesc/*:supportDesc/*:condition"
                     mode="html"/>


               </xsl:variable>

               <xsl:attribute name="displayForm" select="normalize-space($condition)"/>

               <!-- <xsl:value-of select="normalize-space($condition)" /> -->
               <xsl:value-of select="normalize-space(replace($condition, '&lt;[^&gt;]+&gt;', ''))"/>

            </condition>

         </conditions>

      </xsl:if>

      <xsl:if test="*:physDesc/*:objectDesc/*:layoutDesc">

         <layouts>

            <xsl:attribute name="display" select="'true'"/>

            <layout>

               <xsl:attribute name="display" select="'true'"/>

               <xsl:variable name="layout">
                  <xsl:apply-templates select="*:physDesc/*:objectDesc/*:layoutDesc" mode="html"/>

               </xsl:variable>

               <xsl:attribute name="displayForm" select="normalize-space($layout)"/>

               <!-- <xsl:value-of select="normalize-space($layout)" /> -->
               <xsl:value-of select="normalize-space(replace($layout, '&lt;[^&gt;]+&gt;', ''))"/>

            </layout>

         </layouts>

      </xsl:if>

      <xsl:if test="*:physDesc/*:handDesc">

         <scripts>

            <xsl:attribute name="display" select="'true'"/>

            <script>
               
               <xsl:attribute name="display" select="'true'"/>
               
               <xsl:variable name="script">
                  <xsl:apply-templates select="*:physDesc/*:handDesc" mode="html"/>

                  
                  
               </xsl:variable>
            
               <xsl:attribute name="displayForm" select="normalize-space($script)"/>
               
               <!-- <xsl:value-of select="normalize-space($script)" /> -->
               <xsl:value-of select="normalize-space(replace($script, '&lt;[^&gt;]+&gt;', ''))"/>
               
            </script>

         </scripts>

      </xsl:if>


      <xsl:if test="*:physDesc/*:musicNotation">

         <musicNotations>

            <xsl:attribute name="display" select="'true'"/>

            <musicNotation>

               <xsl:attribute name="display" select="'true'"/>

               <xsl:variable name="musicNotation">
                  <xsl:apply-templates select="*:physDesc/*:musicNotation" mode="html"/>
               </xsl:variable>

               <xsl:attribute name="displayForm" select="normalize-space($musicNotation)"/>

               <!-- <xsl:value-of select="normalize-space($binding)" /> -->
               <xsl:value-of
                  select="normalize-space(replace($musicNotation, '&lt;[^&gt;]+&gt;', ''))"/>

            </musicNotation>

         </musicNotations>

      </xsl:if>


      <xsl:if test="*:physDesc/*:decoDesc">

         <decorations>

            <xsl:attribute name="display" select="'true'"/>

            <decoration>

               <xsl:attribute name="display" select="'true'"/>

               <xsl:variable name="decoration">
                  <xsl:apply-templates select="*:physDesc/*:decoDesc" mode="html"/>

               </xsl:variable>

               <xsl:attribute name="displayForm" select="normalize-space($decoration)"/>

               <!-- <xsl:value-of select="normalize-space($decoration)" /> -->
               <xsl:value-of select="normalize-space(replace($decoration, '&lt;[^&gt;]+&gt;', ''))"/>

            </decoration>

         </decorations>

      </xsl:if>

      <xsl:if test="*:physDesc/*:additions">

         <additions>

            <xsl:attribute name="display" select="'true'"/>

            <addition>

               <xsl:attribute name="display" select="'true'"/>

               <xsl:variable name="addition">
                  <xsl:apply-templates select="*:physDesc/*:additions" mode="html"/>

               </xsl:variable>

               <xsl:attribute name="displayForm" select="normalize-space($addition)"/>

               <!-- <xsl:value-of select="normalize-space($addition)" /> -->
               <xsl:value-of select="normalize-space(replace($addition, '&lt;[^&gt;]+&gt;', ''))"/>

            </addition>

         </additions>

      </xsl:if>

      <xsl:if test="*:physDesc/*:bindingDesc">

         <bindings>

            <xsl:attribute name="display" select="'true'"/>

            <binding>

               <xsl:attribute name="display" select="'true'"/>

               <xsl:variable name="binding">
                  <xsl:apply-templates select="*:physDesc/*:bindingDesc" mode="html"/>
               </xsl:variable>

               <xsl:attribute name="displayForm" select="normalize-space($binding)"/>

               <!-- <xsl:value-of select="normalize-space($binding)" /> -->
               <xsl:value-of select="normalize-space(replace($binding, '&lt;[^&gt;]+&gt;', ''))"/>

            </binding>

         </bindings>

      </xsl:if>

      <xsl:if test="*:physDesc/*:accMat">

         <accMats>

            <xsl:attribute name="display" select="'true'"/>

            <accMat>

               <xsl:attribute name="display" select="'true'"/>

               <xsl:variable name="accMat">
                  <xsl:apply-templates select="*:physDesc/*:accMat" mode="html"/>
               </xsl:variable>

               <xsl:attribute name="displayForm" select="normalize-space($accMat)"/>

               <!-- <xsl:value-of select="normalize-space($binding)" /> -->
               <xsl:value-of select="normalize-space(replace($accMat, '&lt;[^&gt;]+&gt;', ''))"/>

            </accMat>

         </accMats>

      </xsl:if>



   </xsl:template>

   <!--physical description processing templates-->
   <xsl:template match="*:objectDesc/@form" mode="html">


      <xsl:value-of select="concat(upper-case(substring(., 1, 1)), substring(., 2))"/>
      <!--<xsl:value-of select="normalize-space(.)" />-->
      <!--<xsl:text>.</xsl:text>-->

   </xsl:template>

   <xsl:template match="*:supportDesc/*:support" mode="html">

      <xsl:apply-templates mode="html"/>

   </xsl:template>

   <xsl:template match="*:supportDesc/*:extent" mode="html">

      <xsl:apply-templates mode="html"/>

   </xsl:template>

   <xsl:template match="*:supportDesc/*:foliation" mode="html">

      <xsl:text>&lt;p&gt;</xsl:text>

      <xsl:if test="@n">
         <xsl:value-of select="@n"/>
         <xsl:text>. </xsl:text>
      </xsl:if>

      <xsl:if test="@type">
         <xsl:value-of select="cudl:first-upper-case(@type)"/>
         <xsl:text>: </xsl:text>
      </xsl:if>

      <xsl:apply-templates mode="html"/>

      <xsl:text>&lt;/p&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:supportDesc/*:condition" mode="html">

      <xsl:apply-templates mode="html"/>

   </xsl:template>

   <xsl:template match="*:dimensions" mode="html">

      <!--      <xsl:text>&lt;br /&gt;</xsl:text> -->

      <xsl:if test="@subtype">
         <xsl:text>&lt;b&gt;</xsl:text>
         <xsl:value-of select="cudl:first-upper-case(translate(@subtype, '_', ' '))"/>
         <xsl:text>:</xsl:text>
         <xsl:text>&lt;/b&gt;</xsl:text>
         <xsl:text> </xsl:text>
      </xsl:if>

      <xsl:text> </xsl:text>
      <xsl:value-of select="cudl:first-upper-case(@type)"/>
      <xsl:text> </xsl:text>
      <xsl:for-each select="*">

         <xsl:choose>
            <xsl:when test="local-name(.) = 'dim'">
               <xsl:value-of select="@type"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:value-of select="local-name(.)"/>
            </xsl:otherwise>
         </xsl:choose>
         <xsl:text>: </xsl:text>

         <xsl:choose>
            <xsl:when test="normalize-space(.)">
               <xsl:value-of select="."/>
            </xsl:when>
            <xsl:when test="normalize-space(@quantity)">
               <xsl:value-of select="@quantity"/>
            </xsl:when>
            <xsl:otherwise>
               <!-- shouldn't happen? -->
            </xsl:otherwise>
         </xsl:choose>

         <xsl:if test="../@unit">
            <xsl:text> </xsl:text>
            <xsl:value-of select="../@unit"/>
         </xsl:if>

         <xsl:if test="not(position()=last())">
            <xsl:text>, </xsl:text>
         </xsl:if>

      </xsl:for-each>

      <xsl:text>. </xsl:text>


   </xsl:template>

   <xsl:template match="*:layoutDesc" mode="html">

      <xsl:apply-templates mode="html"/>

   </xsl:template>

   <xsl:template match="*:layout" mode="html">

      <xsl:apply-templates mode="html"/>

   </xsl:template>

   <xsl:template match="*:commentaryForm" mode="html">

      <xsl:text>&lt;div&gt;</xsl:text>
      <xsl:text>&lt;b&gt;Commentary form:&lt;/b&gt; </xsl:text>
      <xsl:value-of select="@type"/>
      <xsl:text>. </xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:stringHole" mode="html">


      <xsl:apply-templates mode="html"/>

   </xsl:template>

   <xsl:template match="*:handDesc" mode="html">

      <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:handNote" mode="html">



      <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:decoDesc" mode="html">

      <xsl:apply-templates mode="html"/>

   </xsl:template>

   <xsl:template match="*:decoNote" mode="html">

      <xsl:apply-templates mode="html"/>

      <xsl:if test="exists(following-sibling::*)">
         <xsl:text>&lt;br /&gt;</xsl:text>
      </xsl:if>

   </xsl:template>

   <xsl:template match="*:additions" mode="html">

      <xsl:apply-templates mode="html"/>

   </xsl:template>

   <xsl:template match="*:bindingDesc" mode="html">

      <xsl:apply-templates mode="html"/>

   </xsl:template>

   <xsl:template match="*:accMat" mode="html">

      <xsl:apply-templates mode="html"/>

   </xsl:template>


   <!--provenance-->
   <xsl:template name="get-doc-history">

      <xsl:if test="*:history/*:provenance">

         <provenances>

            <xsl:attribute name="display" select="'true'"/>

            <provenance>
               <xsl:attribute name="display" select="'true'"/>

               <xsl:variable name="provenance">
                  <xsl:apply-templates select="*:history/*:provenance" mode="html"/>
               </xsl:variable>

               <xsl:attribute name="displayForm" select="normalize-space($provenance)"/>

               <xsl:value-of select="normalize-space(replace($provenance, '&lt;[^&gt;]+&gt;', ''))"/>

            </provenance>

         </provenances>

      </xsl:if>

      <xsl:if test="*:history/*:origin/text()|*:history/*:origin/*:p">

         <origins>

            <xsl:attribute name="display" select="'true'"/>

            <origin>
               <xsl:attribute name="display" select="'true'"/>

               <xsl:variable name="origin">
                  <xsl:apply-templates select="*:history/*:origin" mode="html"/>
               </xsl:variable>

               <xsl:attribute name="displayForm" select="normalize-space($origin)"/>

               <xsl:value-of select="normalize-space(replace($origin, '&lt;[^&gt;]+&gt;', ''))"/>

            </origin>

         </origins>

      </xsl:if>

      <xsl:if test="*:history/*:acquisition/text()|*:history/*:acquisition/*:p">

         <acquisitionTexts>

            <xsl:attribute name="display" select="'true'"/>

            <acquisitionText>
               <xsl:attribute name="display" select="'true'"/>

               <xsl:variable name="acquisition">
                  <xsl:apply-templates select="*:history/*:acquisition" mode="html"/>
               </xsl:variable>

               <xsl:attribute name="displayForm" select="normalize-space($acquisition)"/>

               <xsl:value-of select="normalize-space(replace($acquisition, '&lt;[^&gt;]+&gt;', ''))"/>

            </acquisitionText>

         </acquisitionTexts>

      </xsl:if>



   </xsl:template>





   <xsl:template match="*:history/*:provenance" mode="html">

      <xsl:if test="normalize-space(.)">

         <xsl:apply-templates mode="html"/>

      </xsl:if>

   </xsl:template>


   <xsl:template match="*:history/*:origin" mode="html">

      <xsl:if test="normalize-space(.)">

         <xsl:apply-templates mode="html"/>

      </xsl:if>

   </xsl:template>


   <xsl:template match="*:history/*:acquisition" mode="html">

      <xsl:if test="normalize-space(.)">

         <xsl:apply-templates mode="html"/>

      </xsl:if>

   </xsl:template>

   <!--***********************************EXCERPTS - bits of transcription-->
   <!--TODO - review-->
   <xsl:template name="get-item-excerpts">


      <xsl:if
         test="*:head|*:div/*:head|*:p|*:div/*:p|*:div/*:note|*:colophon|*:div/*:colophon|*:decoNote|*:div/*:decoNote|*:explicit|*:div/*:explicit|*:finalRubric|*:div/*:finalRubric|*:incipit|*:div/*:incipit|*:rubric|*:div/*:rubric">
         <excerpts>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:variable name="excerpts">
               <xsl:apply-templates
                  select="*:head|*:div/*:head|*:p|*:div/*:p|*:div/*:note|*:colophon|*:div/*:colophon|*:decoNote|*:div/*:decoNote|*:explicit|*:div/*:explicit|*:finalRubric|*:div/*:finalRubric|*:incipit|*:div/*:incipit|*:rubric|*:div/*:rubric"
                  mode="html"/>
            </xsl:variable>

            <xsl:attribute name="displayForm" select="normalize-space($excerpts)"/>
            <!-- <xsl:value-of select="normalize-space($excerpts)" /> -->
            <xsl:value-of select="normalize-space(replace($excerpts, '&lt;[^&gt;]+&gt;', ''))"/>
         </excerpts>
      </xsl:if>

   </xsl:template>

   <!--NOTES-->
   <!--<xsl:template name="get-doc-notes">


      <xsl:if test="*:history/*:origin/*:note">
         <notes>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:for-each select="*:history/*:origin/*:note">

               <xsl:variable name="note">
                  <xsl:apply-templates mode="html"/>
               </xsl:variable>

               <note>
                  <xsl:attribute name="display" select="'true'"/>
                  <xsl:attribute name="displayForm" select="normalize-space($note)"/>
                  <xsl:value-of select="normalize-space($note)"/>
               </note>

            </xsl:for-each>

         </notes>
      </xsl:if>

   </xsl:template>-->


   <xsl:template name="get-item-notes">


      <xsl:if test="*:note">
         <notes>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:for-each select="*:note">

               <xsl:variable name="note">
                  <xsl:apply-templates mode="html"/>
               </xsl:variable>

               <note>
                  <xsl:attribute name="display" select="'true'"/>
                  <xsl:attribute name="displayForm" select="normalize-space($note)"/>
                  <xsl:value-of select="normalize-space($note)"/>
               </note>

            </xsl:for-each>

         </notes>
      </xsl:if>

   </xsl:template>

   <!--COLOPHON-->
   <xsl:template match="*:msItem/*:colophon|*:msItem/*:div/*:colophon" mode="html">

      <xsl:text>&lt;div&gt;</xsl:text>
      <xsl:text>&lt;b&gt;Colophon</xsl:text>

      <xsl:if test="normalize-space(@type)">
         <xsl:value-of select="concat(', ', normalize-space(@type))"/>
      </xsl:if>

      <xsl:text>:&lt;/b&gt; </xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>

   </xsl:template>

   <!--EXPLICIT-->
   <xsl:template match="*:msItem/*:explicit|*:msItem/*:div/*:explicit" mode="html">

      <xsl:text>&lt;div&gt;</xsl:text>
      <xsl:text>&lt;b&gt;Explicit</xsl:text>

      <xsl:if test="normalize-space(@type)">
         <xsl:value-of select="concat(', ', normalize-space(@type))"/>
      </xsl:if>

      <xsl:text>:&lt;/b&gt; </xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>

   </xsl:template>


   <!--INCIPIT-->
   <xsl:template match="*:msItem/*:incipit|*:msItem/*:div/*:incipit" mode="html">

      <xsl:text>&lt;div&gt;</xsl:text>
      <xsl:text>&lt;b&gt;Incipit</xsl:text>

      <xsl:if test="normalize-space(@type)">
         <xsl:value-of select="concat(', ', normalize-space(@type))"/>
      </xsl:if>

      <xsl:text>:&lt;/b&gt; </xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>

   </xsl:template>

   <!--INCIPIT as title-->
   <xsl:template match="*:incipit" mode="title">
      <xsl:apply-templates select="node() except *:locus" mode="html"/>


   </xsl:template>

   <!--RUBRIC as title-->
   <xsl:template match="*:rubric" mode="title">

      <xsl:apply-templates select="node() except *:locus" mode="html"/>

   </xsl:template>

   <!--RUBRIC-->
   <xsl:template match="*:msItem/*:rubric|*:msItem/*:div/*:rubric" mode="html">

      <xsl:text>&lt;div&gt;</xsl:text>
      <xsl:text>&lt;b&gt;Rubric</xsl:text>

      <xsl:if test="normalize-space(@type)">
         <xsl:value-of select="concat(', ', normalize-space(@type))"/>
      </xsl:if>

      <xsl:text>:&lt;/b&gt; </xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:msItem/*:finalRubric|*:msItem/*:div/*:finalRubric" mode="html">

      <xsl:text>&lt;div&gt;</xsl:text>
      <xsl:text>&lt;b&gt;Final Rubric</xsl:text>

      <xsl:if test="normalize-space(@type)">
         <xsl:value-of select="concat(', ', normalize-space(@type))"/>
      </xsl:if>

      <xsl:text>:&lt;/b&gt; </xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>

   </xsl:template>

   <!--****************************notes-->
   <xsl:template match="*:note" mode="html">


      <xsl:apply-templates mode="html"/>

   </xsl:template>

   <!--deco notes within msitems-->
   <xsl:template match="*:msItem//*:decoNote" mode="html">

      <xsl:choose>
         <xsl:when test="*:p">

            <xsl:text>&lt;p&gt;</xsl:text>
            <xsl:text>&lt;b&gt;Decoration:&lt;/b&gt; </xsl:text>
            <xsl:text>&lt;/p&gt;</xsl:text>

            <xsl:apply-templates mode="html"/>

         </xsl:when>
         <xsl:otherwise>

            <xsl:text>&lt;p&gt;</xsl:text>
            <xsl:text>&lt;b&gt;Decoration:&lt;/b&gt; </xsl:text>
            <xsl:apply-templates mode="html"/>
            <xsl:text>&lt;/p&gt;</xsl:text>

         </xsl:otherwise>
      </xsl:choose>

   </xsl:template>

   <!--FILIATION-->
   <xsl:template name="get-item-filiation">

      <xsl:if test="*:filiation">
         <filiations>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:variable name="filiation">
               <xsl:text>&lt;div&gt;</xsl:text>
               <xsl:apply-templates select="*:filiation" mode="html"/>
               <xsl:text>&lt;/div&gt;</xsl:text>
            </xsl:variable>

            <xsl:attribute name="displayForm" select="normalize-space($filiation)"/>
            <!-- <xsl:value-of select="normalize-space($filiation)" /> -->
            <xsl:value-of select="normalize-space(replace($filiation, '&lt;[^&gt;]+&gt;', ''))"/>
         </filiations>
      </xsl:if>

   </xsl:template>

   <xsl:template match="*:filiation" mode="html">

      <xsl:text>&lt;div&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>

   </xsl:template>




   <!--*******************************************NAMES-->

   <!-- Table of role relator codes and role element names -->
   <xsl:variable name="rolemap">
      <role code="aut" name="authors"/>
      <role code="dnr" name="donors"/>
      <role code="fmo" name="formerOwners"/>
      <role code="pbl" name="publishers"/>
      <role code="rcp" name="recipients"/>
      <role code="scr" name="scribes"/>
   </xsl:variable>

   <xsl:template name="get-doc-names">

      <!--for doc names looks only in summary, physdesc and history-->

      <xsl:if
         test="*:msContents/*:summary//*:name[@role='aut']|*:physDesc//*:name[@role='aut']|*:history//*:name[@role='aut']">

         <xsl:element name="authors">
            <xsl:attribute name="display" select="'true'"/>

            <xsl:apply-templates select="*:msContents/*:summary//*:name[@role='aut']"/>
            <xsl:apply-templates select="*:physDesc//*:name[@role='aut']"/>
            <xsl:apply-templates select="*:history//*:name[@role='aut']"/>


         </xsl:element>

      </xsl:if>

      <xsl:if
         test="*:msContents/*:summary//*:name[@role='dnr']|*:physDesc//*:name[@role='dnr']|*:history//*:name[@role='dnr']">

         <xsl:element name="donors">
            <xsl:attribute name="display" select="'true'"/>

            <xsl:apply-templates select="*:msContents/*:summary//*:name[@role='dnr']"/>
            <xsl:apply-templates select="*:physDesc//*:name[@role='dnr']"/>
            <xsl:apply-templates select="*:history//*:name[@role='dnr']"/>


         </xsl:element>


      </xsl:if>

      <xsl:if
         test="*:msContents/*:summary//*:name[@role='fmo']|*:physDesc//*:name[@role='fmo']|*:history//*:name[@role='fmo']">

         <xsl:element name="formerOwners">
            <xsl:attribute name="display" select="'true'"/>

            <xsl:apply-templates select="*:msContents/*:summary//*:name[@role='fmo']"/>
            <xsl:apply-templates select="*:physDesc//*:name[@role='fmo']"/>
            <xsl:apply-templates select="*:history//*:name[@role='fmo']"/>


         </xsl:element>

      </xsl:if>

      <xsl:if
         test="*:msContents/*:summary//*:name[@role='rcp']|*:physDesc//*:name[@role='rcp']|*:history//*:name[@role='rcp']">

         <xsl:element name="recipients">
            <xsl:attribute name="display" select="'true'"/>

            <xsl:apply-templates select="*:msContents/*:summary//*:name[@role='rcp']"/>
            <xsl:apply-templates select="*:physDesc//*:name[@role='rcp']"/>
            <xsl:apply-templates select="*:history//*:name[@role='rcp']"/>


         </xsl:element>

      </xsl:if>

      <xsl:if
         test="*:msContents/*:summary//*:name[@role='scr']|*:physDesc//*:name[@role='scr']|*:history//*:name[@role='scr']">

         <xsl:element name="scribes">
            <xsl:attribute name="display" select="'true'"/>

            <xsl:apply-templates select="*:msContents/*:summary//*:name[@role='scr']"/>
            <xsl:apply-templates select="*:physDesc//*:name[@role='scr']"/>
            <xsl:apply-templates select="*:history//*:name[@role='scr']"/>


         </xsl:element>
      </xsl:if>

      <xsl:if
         test="*:msContents/*:summary//*:name[@role='oth' or not(@role) or not(@role=$rolemap/role/@code)]|*:physDesc//*:name[@role='oth' or not(@role) or not(@role=$rolemap/role/@code)]|*:history//*:name[@role='oth' or not(@role) or not(@role=$rolemap/role/@code)]">

         <xsl:element name="associated">
            <xsl:attribute name="display" select="'true'"/>

            <xsl:apply-templates
               select="*:msContents/*:summary//*:name[@role='oth' or not(@role) or not(@role=$rolemap/role/@code)]"/>
            <xsl:apply-templates
               select="*:physDesc//*:name[@role='oth' or not(@role) or not(@role=$rolemap/role/@code)]"/>
            <xsl:apply-templates
               select="*:history//*:name[@role='oth' or not(@role) or not(@role=$rolemap/role/@code)]"/>


         </xsl:element>

      </xsl:if>

   </xsl:template>

   <xsl:template name="get-doc-and-item-names">


      <!--for doc and item, looks in summary, physdesc, history, first msItem author and respstmt fields-->
      <!--simplify to just pick up all names in first msItem?-->
      <!-- and correspDesc -->
      <xsl:if
         test="ancestor-or-self::tei:teiHeader//tei:correspDesc//tei:correspAction[@type=('sent','received')]">
         <xsl:apply-templates
            select="ancestor-or-self::tei:teiHeader//tei:correspDesc//tei:correspAction[@type=('sent','received')]"
         />
      </xsl:if>

      <xsl:if
         test="*:msContents/*:summary//*:name[@role='aut']|//*:physDesc//*:name[@role='aut']|*:history//*:name[@role='aut']|//*:msContents/*:msItem[1]/*:author">


         <xsl:element name="authors">
            <xsl:attribute name="display" select="'true'"/>

            <xsl:apply-templates select="*:msContents/*:summary//*:name[@role='aut']"/>
            <xsl:apply-templates select="*:physDesc//*:name[@role='aut']"/>
            <xsl:apply-templates select="*:history//*:name[@role='aut']"/>
            <xsl:apply-templates select="*:msContents/*:msItem[1]/*:author"/>

         </xsl:element>
      </xsl:if>


      <xsl:if
         test="*:msContents/*:summary//*:name[@role='dnr']|*:physDesc//*:name[@role='dnr']|*:history//*:name[@role='dnr']|*:msContents/*:msItem[1]/*:editor[@role='dnr']">

         <xsl:element name="donors">
            <xsl:attribute name="display" select="'true'"/>

            <xsl:apply-templates select="*:msContents/*:summary//*:name[@role='dnr']"/>
            <xsl:apply-templates select="*:physDesc//*:name[@role='dnr']"/>
            <xsl:apply-templates select="*:history//*:name[@role='dnr']"/>
            <xsl:apply-templates select="*:msContents/*:msItem[1]/*:editor[@role='dnr']"/>

         </xsl:element>

      </xsl:if>

      <xsl:if
         test="*:msContents/*:summary//*:name[@role='fmo']|*:physDesc//*:name[@role='fmo']|*:history//*:name[@role='fmo']|*:msContents/*:msItem[1]/*:editor[@role='fmo']">

         <xsl:element name="formerOwners">
            <xsl:attribute name="display" select="'true'"/>

            <xsl:apply-templates select="*:msContents/*:summary//*:name[@role='fmo']"/>
            <xsl:apply-templates select="*:physDesc//*:name[@role='fmo']"/>
            <xsl:apply-templates select="*:history//*:name[@role='fmo']"/>
            <xsl:apply-templates select="*:msContents/*:msItem[1]/*:editor[@role='fmo']"/>

         </xsl:element>

      </xsl:if>

      <xsl:if
         test="*:msContents/*:summary//*:name[@role='rcp']|*:physDesc//*:name[@role='rcp']|*:history//*:name[@role='rcp']|*:msContents/*:msItem[1]/*:editor[@role='rcp']">


         <xsl:element name="recipients">
            <xsl:attribute name="display" select="'true'"/>

            <xsl:apply-templates select="*:msContents/*:summary//*:name[@role='rcp']"/>
            <xsl:apply-templates select="*:physDesc//*:name[@role='rcp']"/>
            <xsl:apply-templates select="*:history//*:name[@role='rcp']"/>
            <xsl:apply-templates select="*:msContents/*:msItem[1]/*:editor[@role='rcp']"/>

         </xsl:element>
      </xsl:if>


      <xsl:if
         test="*:msContents/*:summary//*:name[@role='scr']|*:physDesc//*:name[@role='scr']|*:history//*:name[@role='scr']|*:msContents/*:msItem[1]/*:editor[@role='scr']">

         <xsl:element name="scribes">
            <xsl:attribute name="display" select="'true'"/>

            <xsl:apply-templates select="*:msContents/*:summary//*:name[@role='scr']"/>
            <xsl:apply-templates select="*:physDesc//*:name[@role='scr']"/>
            <xsl:apply-templates select="*:history//*:name[@role='scr']"/>
            <xsl:apply-templates select="*:msContents/*:msItem[1]/*:editor[@role='scr']"/>

         </xsl:element>
      </xsl:if>

      <xsl:if
         test="*:msContents/*:summary//*:name[@role='oth' or not(@role) or not(@role=$rolemap/role/@code)]|*:physDesc//*:name[@role='oth' or not(@role) or not(@role=$rolemap/role/@code)]|*:history//*:name[@role='oth' or not(@role) or not(@role=$rolemap/role/@code)]|*:msContents/*:msItem[1]/*:editor[@role='oth' or not(@role) or not(@role=$rolemap/role/@code)]">

         <xsl:element name="associated">
            <xsl:attribute name="display" select="'true'"/>

            <xsl:apply-templates
               select="*:msContents/*:summary//*:name[@role='oth' or not(@role) or not(@role=$rolemap/role/@code)]"/>
            <xsl:apply-templates
               select="*:physDesc//*:name[@role='oth' or not(@role) or not(@role=$rolemap/role/@code)]"/>
            <xsl:apply-templates
               select="*:history//*:name[@role='oth' or not(@role) or not(@role=$rolemap/role/@code)]"/>
            <xsl:apply-templates
               select="*:msContents/*:msItem[1]/*:editor[@role='oth' or not(@role) or not(@role=$rolemap/role/@code)]"/>



         </xsl:element>

      </xsl:if>


   </xsl:template>

   <xsl:template name="get-item-names">

      <!--for items, just look in author field-->
      <!--look for all names in msItem?-->

      <xsl:choose>
         <xsl:when
            test="ancestor-or-self::tei:teiHeader//tei:correspDesc//tei:correspAction[@type=('sent','received')]">
            <xsl:apply-templates
               select="ancestor-or-self::tei:teiHeader//tei:correspDesc//tei:correspAction[@type=('sent','received')]"
            />
         </xsl:when>
         <xsl:otherwise>
            <xsl:if test="*:author">

               <xsl:element name="authors">
                  <xsl:attribute name="display" select="'true'"/>

                  <xsl:apply-templates select="*:author"/>

               </xsl:element>
            </xsl:if>

            <xsl:if test="*:editor[@role='dnr']">

               <xsl:element name="donors">
                  <xsl:attribute name="display" select="'true'"/>

                  <xsl:apply-templates select="*:editor[@role='dnr']"/>

               </xsl:element>

            </xsl:if>

            <xsl:if test="*:editor[@role='fmo']">

               <xsl:element name="formerOwners">
                  <xsl:attribute name="display" select="'true'"/>

                  <xsl:apply-templates select="*:editor[@role='fmo']"/>

               </xsl:element>

            </xsl:if>

            <xsl:if test="*:editor[@role='rcp']">

               <xsl:element name="recipients">
                  <xsl:attribute name="display" select="'true'"/>

                  <xsl:apply-templates select="*:editor[@role='rcp']"/>

               </xsl:element>

            </xsl:if>

            <xsl:if test="*:editor[@role='scr']">

               <xsl:element name="scribes">
                  <xsl:attribute name="display" select="'true'"/>

                  <xsl:apply-templates select="*:editor[@role='scr']"/>

               </xsl:element>
            </xsl:if>

            <xsl:if test="*:editor[@role='oth' or not(@role) or not(@role=$rolemap/role/@code)]">

               <xsl:element name="associated">
                  <xsl:attribute name="display" select="'true'"/>

                  <xsl:apply-templates
                     select="*:editor[@role='oth' or not(@role) or not(@role=$rolemap/role/@code)]"/>

               </xsl:element>
            </xsl:if>

         </xsl:otherwise>

      </xsl:choose>

   </xsl:template>

   <xsl:template match="tei:correspAction[@type='sent'][normalize-space(.)]">
      <authors display="true">
         <xsl:apply-templates select="(tei:persName|tei:orgName|tei:name)[normalize-space(.)]"/>
      </authors>
   </xsl:template>

   <xsl:template match="tei:correspAction[@type='received']">
      <recipients display="true">
         <xsl:apply-templates select="(tei:persName|tei:orgName|tei:name)[normalize-space(.)]"/>
      </recipients>
   </xsl:template>

   <xsl:template match="*:name[*:persName]">

      <name>

         <xsl:attribute name="display" select="'true'"/>

         <xsl:choose>
            <xsl:when test="*:persName[@type='standard']">
               <xsl:for-each select="*:persName[@type='standard']">
                  <xsl:attribute name="displayForm" select="normalize-space(.)"/>
                  <fullForm>
                     <xsl:value-of select="normalize-space(.)"/>
                  </fullForm>
               </xsl:for-each>

               <xsl:choose>
                  <!-- if separate display form exists, use as short form -->
                  <xsl:when test="*:persName[@type='display']">
                     <xsl:for-each select="*:persName[@type='display']">
                        <shortForm>
                           <xsl:value-of select="normalize-space(.)"/>
                        </shortForm>
                     </xsl:for-each>

                  </xsl:when>
                  <!-- if no separate display form exists, use standard form as short form -->
                  <xsl:otherwise>
                     <xsl:for-each select="*:persName[@type='standard']">
                        <shortForm>
                           <xsl:value-of select="normalize-space(.)"/>
                        </shortForm>
                     </xsl:for-each>
                  </xsl:otherwise>
               </xsl:choose>

            </xsl:when>
            <xsl:when test="*:persName[@type='display']">

               <xsl:attribute name="displayForm"
                  select="normalize-space(*:persName[@type='display'][1])"/>
               <shortForm>
                  <xsl:value-of select="normalize-space(*:persName[@type='display'][1])"/>
               </shortForm>


            </xsl:when>
            <xsl:otherwise>
               <!-- No standard form, no display form, take whatever we've got? -->

               <xsl:attribute name="displayForm" select="normalize-space(*:persName[1])"/>
               <shortForm>
                  <xsl:value-of select="normalize-space(*:persName[1])"/>
               </shortForm>


            </xsl:otherwise>
         </xsl:choose>


         <xsl:for-each select="@type">
            <type>
               <xsl:value-of select="normalize-space(.)"/>
            </type>
         </xsl:for-each>

         <xsl:for-each select="@role">
            <role>
               <xsl:value-of select="normalize-space(.)"/>
            </role>
         </xsl:for-each>

         <xsl:for-each select="@key[contains(., 'person_v')]">

            <authority>VIAF</authority>
            <authorityURI>http://viaf.org/</authorityURI>

            <!-- Possible that there are multiple VIAF_* tokens (if multiple VIAF entries for same person) e.g. Sanskrit MS-OR-02339. For now, just use first, but should maybe handle multiple -->
            <xsl:for-each select="tokenize(normalize-space(.), ' ')[starts-with(., 'person_v')][1]">

               <!-- <xsl:if test="starts-with(., 'VIAF_')"> -->
               <valueURI>
                  <xsl:value-of
                     select="concat('http://viaf.org/viaf/', substring-after(.,'person_v'))"/>
               </valueURI>
               <!-- </xsl:if> -->
            </xsl:for-each>

         </xsl:for-each>

      </name>

   </xsl:template>


   <xsl:template
      match="*:author|tei:correspAction/tei:*[self::tei:persName|self::tei:orgName|self::tei:name]">

      <name>

         <xsl:attribute name="display" select="'true'"/>

         <xsl:attribute name="displayForm" select="normalize-space(.)"/>
         <fullForm>
            <xsl:value-of select="normalize-space(.)"/>
         </fullForm>

         <shortForm>
            <xsl:value-of select="normalize-space(.)"/>
         </shortForm>

         <xsl:for-each select="@type">
            <type>
               <xsl:value-of select="normalize-space(.)"/>
            </type>
         </xsl:for-each>


         <role>
            <xsl:choose>
               <xsl:when test="ancestor::tei:correspAction[@type='received']">
                  <xsl:text>rcp</xsl:text>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:text>aut</xsl:text>
               </xsl:otherwise>
            </xsl:choose>
         </role>


         <xsl:for-each select="@key[contains(., 'person_v')]">

            <authority>VIAF</authority>
            <authorityURI>http://viaf.org/</authorityURI>

            <!-- Possible that there are multiple VIAF_* tokens (if multiple VIAF entries for same person) e.g. Sanskrit MS-OR-02339. For now, just use first, but should maybe handle multiple -->
            <xsl:for-each select="tokenize(normalize-space(.), ' ')[starts-with(., 'person_v')][1]">

               <!-- <xsl:if test="starts-with(., 'VIAF_')"> -->
               <valueURI>
                  <xsl:value-of
                     select="concat('http://viaf.org/viaf/', substring-after(.,'person_v'))"/>
               </valueURI>
               <!-- </xsl:if> -->
            </xsl:for-each>

         </xsl:for-each>

      </name>

   </xsl:template>

   <xsl:template match="*:editor">

      <name>

         <xsl:attribute name="display" select="'true'"/>
         <xsl:attribute name="displayForm" select="normalize-space(.)"/>

         <fullForm>
            <xsl:value-of select="normalize-space(.)"/>
         </fullForm>

         <shortForm>
            <xsl:value-of select="normalize-space(.)"/>
         </shortForm>


         <xsl:for-each select="@type">
            <type>
               <xsl:value-of select="normalize-space(.)"/>
            </type>
         </xsl:for-each>

         <xsl:for-each select="@role">
            <role>
               <xsl:value-of select="normalize-space(.)"/>
            </role>
         </xsl:for-each>

         <xsl:for-each select="@key[contains(., 'person_v')]">

            <authority>VIAF</authority>
            <authorityURI>http://viaf.org/</authorityURI>

            <!-- Possible that there are multiple VIAF_* tokens (if multiple VIAF entries for same person) e.g. Sanskrit MS-OR-02339. For now, just use first, but should maybe handle multiple -->
            <xsl:for-each select="tokenize(normalize-space(.), ' ')[starts-with(., 'person_v')][1]">

               <!-- <xsl:if test="starts-with(., 'VIAF_')"> -->
               <valueURI>
                  <xsl:value-of
                     select="concat('http://viaf.org/viaf/', substring-after(.,'person_v'))"/>
               </valueURI>
               <!-- </xsl:if> -->
            </xsl:for-each>

         </xsl:for-each>

      </name>

   </xsl:template>


   <!--******************************LANGUAGES-->
   <xsl:template name="get-doc-languages">

      <xsl:variable name="language-elems" as="item()*">
         <xsl:choose>
            <xsl:when test="*:msContents/*:textLang">
               <xsl:copy-of select="*:msContents/*:textLang"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:copy-of select="ancestor-or-self::tei:teiHeader[1]//tei:langUsage/tei:language"
               />
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:if test="$language-elems/(@mainLang,@ident)[normalize-space(.)][1]">

         <languageCodes>

            <xsl:for-each select="$language-elems/(@mainLang,@ident)[normalize-space(.)][1]">

               <languageCode>
                  <xsl:value-of select="normalize-space(.)"/>
               </languageCode>

            </xsl:for-each>

         </languageCodes>

      </xsl:if>

      <xsl:if test="$language-elems">

         <languageStrings>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:for-each select="$language-elems">

               <languageString>

                  <xsl:attribute name="display" select="'true'"/>
                  <xsl:attribute name="displayForm" select="normalize-space(.)"/>
                  <xsl:value-of select="normalize-space(.)"/>
               </languageString>

            </xsl:for-each>

         </languageStrings>

      </xsl:if>

   </xsl:template>



   <xsl:template name="get-item-languages">

      <xsl:variable name="language-elems" as="item()*">
         <xsl:choose>
            <!--CHANGE-->
            <xsl:when test="*:textLang">
               <xsl:copy-of select="*:textLang"/>
            </xsl:when>

            <!--<xsl:when test="*:msContents/*:textLang">
               <xsl:copy-of select="*:msContents/*:textLang"/>
            </xsl:when>-->
            <xsl:otherwise>
               <xsl:copy-of select="ancestor-or-self::tei:teiHeader[1]//tei:langUsage/tei:language"
               />
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:if test="$language-elems/(@mainLang,@ident)[normalize-space(.)][1]">

         <languageCodes>

            <xsl:for-each select="$language-elems/(@mainLang,@ident)[normalize-space(.)][1]">

               <languageCode>
                  <xsl:value-of select="normalize-space(.)"/>
               </languageCode>

            </xsl:for-each>

         </languageCodes>

      </xsl:if>

      <xsl:if test="$language-elems[normalize-space(.)][1]">

         <languageStrings>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:for-each select="$language-elems[normalize-space(.)]">

               <languageString>

                  <xsl:attribute name="display" select="'true'"/>
                  <xsl:attribute name="displayForm" select="normalize-space(.)"/>
                  <xsl:value-of select="normalize-space(.)"/>
               </languageString>

            </xsl:for-each>

         </languageStrings>

      </xsl:if>

   </xsl:template>


   <!--******************************DATA SOURCES AND REVISIONS-->
   <xsl:template name="get-doc-metadata">

      <xsl:if test="normalize-space(*:additional/*:adminInfo/*:recordHist/*:source)">

         <dataSources>

            <xsl:attribute name="display" select="'true'"/>

            <dataSource>

               <xsl:variable name="dataSource">
                  <xsl:apply-templates select="*:additional/*:adminInfo/*:recordHist/*:source"
                     mode="html"/>
               </xsl:variable>

               <xsl:attribute name="display" select="'true'"/>
               <xsl:attribute name="displayForm" select="normalize-space($dataSource)"/>
               <!-- <xsl:value-of select="normalize-space($dataSource)" /> -->
               <xsl:value-of select="normalize-space(replace($dataSource, '&lt;[^&gt;]+&gt;', ''))"/>

            </dataSource>

         </dataSources>

      </xsl:if>

      <xsl:if test="normalize-space(//*:revisionDesc)">

         <dataRevisions>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:variable name="dataRevisions">
               <!--<xsl:apply-templates select="//*:revisionDesc/*:change[1]/*:persName" mode="html" />-->

               <xsl:value-of
                  select="distinct-values(//*:revisionDesc/*:change/tei:*[self::tei:persName|self::tei:name|self::tei:orgName][normalize-space(.)])"
                  separator=", "/>

            </xsl:variable>

            <xsl:attribute name="displayForm" select="normalize-space($dataRevisions)"/>
            <!-- <xsl:value-of select="normalize-space($dataRevisions)" /> -->
            <xsl:value-of select="normalize-space(replace($dataRevisions, '&lt;[^&gt;]+&gt;', ''))"/>

         </dataRevisions>

      </xsl:if>

   </xsl:template>

   <xsl:template match="*:recordHist/*:source" mode="html">

      <xsl:apply-templates mode="html"/>

   </xsl:template>

   <xsl:template match="*:revisionDesc" mode="html">

      <xsl:apply-templates mode="html"/>

   </xsl:template>

   <xsl:template match="*:revisionDesc/*:change" mode="html">

      <xsl:apply-templates mode="html"/>

      <xsl:if test="not(position()=last())">
         <xsl:text>&lt;br /&gt;</xsl:text>
      </xsl:if>

   </xsl:template>




   <!--***********************************************************************STRUCTURE-->
   <!--*****************************make pages and urls which relate to them-->

   <xsl:template name="make-pages">

      <pages>

         <xsl:choose>

            <!--does the item have any images?-->
            <xsl:when test="//*:facsimile/*:surface">

               <xsl:for-each select="//*:facsimile/*:surface">

                  <xsl:variable name="surface-elem" select="."/>
                  <xsl:variable name="label" select="normalize-space(@n)"/>

                  <page>
                     <label>
                        <xsl:value-of select="$label"/>
                     </label>

                     <physID>
                        <xsl:value-of select="concat('PHYS-',position())"/>
                     </physID>

                     <sequence>
                        <xsl:value-of select="position()"/>
                     </sequence>

                     <xsl:variable name="imageUrl"
                        select="normalize-space(*:graphic[contains(@decls, '#download')]/@url)"/>

                     <xsl:variable name="thumbnailOrientation"
                        select="normalize-space(*:graphic[contains(@decls, '#download')]/@rend)"/>

                     <xsl:variable name="imageWidth1"
                        select="normalize-space(*:graphic[contains(@decls, '#download')]/@width)"/>

                     <xsl:variable name="imageWidth" select="replace($imageWidth1, 'px', '')"/>

                     <xsl:variable name="imageHeight1"
                        select="normalize-space(*:graphic[contains(@decls, '#download')]/@height)"/>

                     <xsl:variable name="imageHeight" select="replace($imageHeight1, 'px', '')"/>


                     <IIIFImageURL>

                        <xsl:value-of select="$imageUrl"/>

                     </IIIFImageURL>

                     <thumbnailImageOrientation>
                        <xsl:value-of select="$thumbnailOrientation"/>
                     </thumbnailImageOrientation>

                     <!--default values for testing-->
                     <imageWidth>
                        <xsl:choose>
                           <xsl:when test="normalize-space($imageWidth)">
                              <xsl:value-of select="$imageWidth"/>
                           </xsl:when>
                           <xsl:otherwise>0</xsl:otherwise>
                        </xsl:choose>

                     </imageWidth>
                     <imageHeight>
                        <xsl:choose>


                           <xsl:when test="normalize-space($imageHeight)">
                              <xsl:value-of select="$imageHeight"/>
                           </xsl:when>
                           <xsl:otherwise>0</xsl:otherwise>
                        </xsl:choose>
                     </imageHeight>


                     <xsl:if
                        test="normalize-space(*:media[@mimeType='transcription_diplomatic']/@url)">

                        <xsl:variable name="transDiplUrl"
                           select="*:media[@mimeType='transcription_diplomatic']/@url"/>
                        <xsl:variable name="transDiplUrlShort"
                           select="replace($transDiplUrl, 'http://services.cudl.lib.cam.ac.uk','')"/>

                        <transcriptionDiplomaticURL>
                           <xsl:value-of select="normalize-space($transDiplUrlShort)"/>

                        </transcriptionDiplomaticURL>

                     </xsl:if>

                     <xsl:if
                        test="normalize-space(*:media[@mimeType='transcription_normalised']/@url)">

                        <xsl:variable name="transNormUrl"
                           select="*:media[@mimeType='transcription_normalised']/@url"/>
                        <xsl:variable name="transNormUrlShort"
                           select="replace($transNormUrl, 'http://services.cudl.lib.cam.ac.uk','')"/>

                        <transcriptionNormalisedURL>
                           <xsl:value-of select="normalize-space($transNormUrlShort)"/>

                        </transcriptionNormalisedURL>

                     </xsl:if>

                     <xsl:if test="normalize-space(*:media[@mimeType='translation']/@url)">

                        <xsl:variable name="translationNormUrl"
                           select="*:media[@mimeType='translation']/@url"/>
                        <xsl:variable name="translationNormUrlShort"
                           select="replace($translationNormUrl, 'http://services.cudl.lib.cam.ac.uk','')"/>

                        <translationURL>
                           <xsl:value-of select="normalize-space($translationNormUrlShort)"/>

                        </translationURL>

                     </xsl:if>


                     <xsl:variable name="isLast">
                        <xsl:choose>
                           <xsl:when test="position()=last()">
                              <xsl:text>true</xsl:text>
                           </xsl:when>
                           <xsl:otherwise>
                              <xsl:text>false</xsl:text>
                           </xsl:otherwise>
                        </xsl:choose>


                     </xsl:variable>

                     <!-- Page transcription -->
                     <xsl:choose>




                        <!--when file contains external transcription do nothing here-->
                        <xsl:when test="*:media[contains(@mimeType,'transcription')]"/>


                        <xsl:otherwise>

                           <xsl:for-each
                              select="(//*:text/*:body/*:div[not(@type)]//*:pb[@type='pageBoundary'][@n = $label],//*:text/*:body/*:div[not(@type)]//*:pb[@n = $label][lambda:has-valid-context(.)])[1]">
                              <xsl:call-template name="output-html-link">
                                 <xsl:with-param name="current_pb" select="."/>
                                 <xsl:with-param name="isLast" select="$isLast"/>
                                 <xsl:with-param name="label" select="$label"/>
                                 <xsl:with-param name="type" select="'transcription'"/>
                              </xsl:call-template>
                           </xsl:for-each>
                        </xsl:otherwise>
                     </xsl:choose>

                     <xsl:for-each
                        select="(//tei:text/tei:body/tei:div[@type='translation']//*:pb[@type='pageBoundary'][@n = $label],//tei:text/tei:body/tei:div[@type='translation']//*:pb[not(@type='pageBoundary')][@n = $label])[1]">
                        <xsl:call-template name="output-html-link">
                           <xsl:with-param name="current_pb" select="."/>
                           <xsl:with-param name="isLast" select="$isLast"/>
                           <xsl:with-param name="label" select="$label"/>
                           <xsl:with-param name="type" select="'translation'"/>
                        </xsl:call-template>
                     </xsl:for-each>

                     <!-- 
                  Note: possible to have:
                  - page with neither image nor transcription
                  - page with image but no transcription
                  - page with transcription but no image
                  - page with image and transcription
               -->
                  </page>

               </xsl:for-each>

            </xsl:when>


            <!--default single page for items without images-->
            <xsl:otherwise>

               <page>
                  <label>
                     <xsl:text>cover</xsl:text>
                  </label>

                  <physID>
                     <xsl:text>PHYS-1</xsl:text>
                  </physID>

                  <sequence>
                     <xsl:text>1</xsl:text>
                  </sequence>
               </page>

            </xsl:otherwise>


         </xsl:choose>

      </pages>

   </xsl:template>

   <xsl:template name="output-html-link">
      <xsl:param name="current_pb" as="item()*"/>
      <xsl:param name="isLast"/>
      <xsl:param name="label"/>
      <xsl:param name="type" as="xsd:string*"/>
      <xsl:choose>
         <xsl:when test="$isLast = 'true' and count(following::*) = 0"/>
         <!--when there's no content between here and the next pb element do nothing-->
          <xsl:when test="not(key('surfaceIDs', $current_pb/@facs))">
              <xsl:message select="concat('ERROR: ', $current_filename, ' has invalid pb/@facs or surface/@xml:id: ''', $current_pb/@facs, '''')"/>
          </xsl:when>
         <xsl:when
            test="local-name(following-sibling::*[1]) = 'pb' and not(ancestor::tei:div[tokenize(normalize-space(@decls), '\s+')[. = '#unpaginated']])"/>
         <xsl:otherwise>
            <xsl:variable name="pb_id.end" as="item()">
               <xsl:choose>
                  <xsl:when test="@next">
                     <xsl:value-of select="replace(@next, '^#', '')"/>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:value-of
                        select="(following::tei:pb[replace(@facs, '^#', '') = //tei:surface/@xml:id][lambda:has-valid-context(.)])[1]/@xml:id"
                     />
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:variable>
            <xsl:variable name="end.pb" select="//tei:pb[@xml:id = $pb_id.end]"/>

            <xsl:if
               test="ancestor::tei:div[tokenize(normalize-space(@decls), '\s+')[. = '#unpaginated']] or exists($current_pb[. is (//tei:pb)[last()]][following::node()[lambda:page-has-content(.)]]) or exists(//node()[self::text()[normalize-space(.)] | self::tei:gap | self::tei:graphic | self::tei:g | self::tei:figure][. >> $current_pb and . &lt;&lt; $end.pb][lambda:page-has-content(.)])">
               <xsl:choose>
                  <xsl:when test="$type='transcription'">
                     <xsl:variable name="encoded-label" select="replace($label, ' ', '%20')"/>

                     <transcriptionDiplomaticURL>
                        <xsl:value-of select="lambda:write-tei-services-link(., 'transcription')"/>
                     </transcriptionDiplomaticURL>
                  </xsl:when>
                  <xsl:when test="$type='translation'">
                     <translationURL>
                        <xsl:value-of select="lambda:write-tei-services-link(.,'translation')"/>
                     </translationURL>
                  </xsl:when>
               </xsl:choose>
            </xsl:if>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <!--LIST ITEM PAGES - passing through for indexing-->
   <xsl:template name="make-list-item-pages">


      <listItemPages>

         <!--this indexes any list items containing at least one locus element under the from attribute of the first locus-->
         <xsl:for-each select="//*:list/*:item[*:locus]">


            <listItemPage>

               <fileID>
                  <xsl:value-of select="$fileID"/>
               </fileID>



               <dmdID xtf:noindex="true">DOCUMENT</dmdID>

               <xsl:variable name="startPageLabel" select="*:locus[1]/@from"/>

               <xsl:variable name="startPagePosition">

                  <xsl:choose>
                      <xsl:when test="key('surfaceNs', $startPageLabel)">
                         <xsl:apply-templates select="key('surfaceNs', $startPageLabel)" mode="count"/>
                        <!--<xsl:variable name="xmlid" select="//*:facsimile/*:surface[@n=$startPageLabel]/@xml:id"/>
                        <xsl:value-of select="substring-after($xmlid, 'i')"></xsl:value-of>-->
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:text>1</xsl:text>
                     </xsl:otherwise>
                  </xsl:choose>

               </xsl:variable>


               <startPageLabel>
                  <xsl:value-of select="$startPageLabel"/>



               </startPageLabel>

               <startPage>
                  <xsl:value-of select="$startPagePosition"/>
               </startPage>

               <title>
                  <xsl:value-of select="$startPageLabel"/>
               </title>

               <listItemText>

                  <xsl:value-of select="normalize-space(.)"/>


               </listItemText>

            </listItemPage>

         </xsl:for-each>


      </listItemPages>

   </xsl:template>


   <!--make logical structure for navigation-->
   <xsl:template name="make-logical-structure">

      <logicalStructures xtf:noindex="true">


         <xsl:apply-templates select="*:TEI/*:teiHeader/*:fileDesc/*:sourceDesc/*:msDesc"
            mode="logicalstructure"/>


      </logicalStructures>

   </xsl:template>

   <xsl:template match="*:msDesc" mode="logicalstructure">


      <logicalStructure>

         <descriptiveMetadataID>
            <xsl:value-of select="'DOCUMENT'"/>
         </descriptiveMetadataID>


         <!--TODO - review this-->
         <!--is this even used?-->
         <label>
            
            <xsl:choose>
               <!--general titles take precedence-->
               <xsl:when test="*:head">
                  <xsl:value-of select="normalize-space(*:head)"/>
               </xsl:when>
               <xsl:when test="*:msIdentifier/*:msName">
                  <xsl:value-of select="normalize-space(*:msIdentifier/*:msName)"/>
               </xsl:when>

               <!--then titles in the first msItem-->
               <xsl:when test="normalize-space(*:msContents/*:msItem[1]/*:title[not(@type)][1])">
                  <xsl:value-of
                     select="normalize-space(*:msContents/*:msItem[1]/*:title[not(@type)][1])"/>

               </xsl:when>
               <xsl:when
                  test="normalize-space(*:msContents/*:msItem[1]/*:title[@type='general'][1])">
                  <xsl:value-of
                     select="normalize-space(*:msContents/*:msItem[1]/*:title[@type='general'][1])"
                  />
               </xsl:when>
               <xsl:when test="normalize-space(*:msContents/*:msItem[1]/*:title[@type='desc'][1])">
                  <xsl:value-of
                     select="normalize-space(*:msContents/*:msItem[1]/*:title[@type='desc'][1])"/>
               </xsl:when>
               <xsl:when
                  test="normalize-space(*:msContents/*:msItem[1]/*:title[@type='standard'][1])">
                  <xsl:value-of
                     select="normalize-space(*:msContents/*:msItem[1]/*:title[@type='standard'][1])"
                  />
               </xsl:when>
               <xsl:when
                  test="normalize-space(*:msContents/*:msItem[1]/*:title[@type='supplied'][1])">
                  <xsl:value-of
                     select="normalize-space(*:msContents/*:msItem[1]/*:title[@type='supplied'][1])"
                  />
               </xsl:when>
               <xsl:when test="normalize-space(*:msContents/*:msItem[1]/*:rubric)">
                  <xsl:variable name="rubric_title">

                     <xsl:apply-templates select="*:msContents/*:msItem[1]/*:rubric" mode="title"/>

                  </xsl:variable>

                  <xsl:value-of select="normalize-space($rubric_title)"/>
               </xsl:when>

               <xsl:when test="normalize-space(*:msContents/*:msItem[1]/*:incipit)">
                  <xsl:variable name="incipit_title">

                     <xsl:apply-templates select="*:msContents/*:msItem[1]/*:incipit" mode="title"/>

                  </xsl:variable>

                  <xsl:value-of select="normalize-space($incipit_title)"/>
               </xsl:when>

               <!--then titles from the summary-->
               <xsl:when test="*:msContents/*:summary//*:title[not(@type)]">
                  <xsl:for-each-group select="*:msContents/*:summary//*:title[not(@type)]"
                     group-by="normalize-space(.)">
                     <xsl:value-of select="normalize-space(.)"/>
                     <xsl:if test="not(position()=last())">
                        <xsl:text>, </xsl:text>
                     </xsl:if>
                  </xsl:for-each-group>
               </xsl:when>
               <!--then classmark-->
               <xsl:when test="*:msIdentifier/*:idno">
                  <xsl:for-each-group select="*:msIdentifier/*:idno" group-by="normalize-space(.)">
                     <xsl:value-of select="normalize-space(.)"/>
                     <xsl:if test="not(position()=last())">
                        <xsl:text>, </xsl:text>
                     </xsl:if>
                  </xsl:for-each-group>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:text>Untitled Document</xsl:text>
               </xsl:otherwise>
            </xsl:choose>

         </label>

         <startPageLabel>

            <xsl:choose>
               <xsl:when test="//*:facsimile/*:surface">
                  <xsl:value-of select="//*:facsimile/*:surface[1]/@n"/>

               </xsl:when>
               <xsl:otherwise>
                  <xsl:text>cover</xsl:text>
               </xsl:otherwise>
            </xsl:choose>


         </startPageLabel>

         <startPagePosition>
            <xsl:text>1</xsl:text>
         </startPagePosition>

         <startPageID>
            <xsl:value-of select="'PHYS-1'"/>
         </startPageID>

         <endPageLabel>

            <xsl:choose>
               <xsl:when test="//*:facsimile/*:surface">

                  <xsl:value-of select="//*:facsimile/*:surface[last()]/@n"/>

               </xsl:when>
               <xsl:otherwise>
                  <xsl:text>cover</xsl:text>
               </xsl:otherwise>
            </xsl:choose>

         </endPageLabel>

         <endPagePosition>
            <xsl:choose>
               <xsl:when test="//*:facsimile/*:surface">
                  <xsl:value-of select="count(//*:facsimile/*:surface)"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:text>1</xsl:text>
               </xsl:otherwise>
            </xsl:choose>

         </endPagePosition>


         <xsl:if
            test="(count(*:msContents/*:msItem) = 1 and *:msContents/*:msItem/*:msItem) or count(*:msContents/*:msItem) > 1 or *:msPart">

            <children>
               <xsl:choose>
                  <xsl:when test="count(*:msContents/*:msItem) = 1">

                     <xsl:apply-templates select="*:msContents/*:msItem/*:msItem"
                        mode="logicalstructure"/>


                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:apply-templates select="*:msContents/*:msItem" mode="logicalstructure"/>
                  </xsl:otherwise>
               </xsl:choose>



               <xsl:apply-templates select="*:msPart" mode="logicalstructure"/>

            </children>

         </xsl:if>

      </logicalStructure>

   </xsl:template>


   <xsl:template match="*:msPart" mode="logicalstructure">

      <logicalStructure>

         <xsl:variable name="n-tree">
            <xsl:value-of
               select="sum((count(ancestor-or-self::*[local-name()='msPart']), count(preceding::*[local-name()='msPart'])))"
            />
         </xsl:variable>

         <descriptiveMetadataID>
            <xsl:value-of select="concat('PART-', normalize-space($n-tree))"/>
         </descriptiveMetadataID>


         <label>
            <xsl:variable name="mspart_title">
               <xsl:choose>
                  <!--general titles take precedence-->
                  <xsl:when test="*:head">
                     <xsl:value-of select="normalize-space(*:head)"/>
                  </xsl:when>
                  <xsl:when test="*:msIdentifier/*:msName">
                     <xsl:value-of select="normalize-space(*:msIdentifier/*:msName)"/>
                  </xsl:when>

                  <!--then titles in the first msItem-->
                  <xsl:when test="normalize-space(*:msContents/*:msItem[1]/*:title[not(@type)][1])">
                     <xsl:value-of
                        select="normalize-space(*:msContents/*:msItem[1]/*:title[not(@type)][1])"/>

                  </xsl:when>
                  <xsl:when
                     test="normalize-space(*:msContents/*:msItem[1]/*:title[@type='general'][1])">
                     <xsl:value-of
                        select="normalize-space(*:msContents/*:msItem[1]/*:title[@type='general'][1])"
                     />
                  </xsl:when>
                  <xsl:when
                     test="normalize-space(*:msContents/*:msItem[1]/*:title[@type='desc'][1])">
                     <xsl:value-of
                        select="normalize-space(*:msContents/*:msItem[1]/*:title[@type='desc'][1])"
                     />
                  </xsl:when>
                  <xsl:when
                     test="normalize-space(*:msContents/*:msItem[1]/*:title[@type='standard'][1])">
                     <xsl:value-of
                        select="normalize-space(*:msContents/*:msItem[1]/*:title[@type='standard'][1])"
                     />
                  </xsl:when>
                  <xsl:when
                     test="normalize-space(*:msContents/*:msItem[1]/*:title[@type='supplied'][1])">
                     <xsl:value-of
                        select="normalize-space(*:msContents/*:msItem[1]/*:title[@type='supplied'][1])"
                     />
                  </xsl:when>
                  <xsl:when test="normalize-space(*:msContents/*:msItem[1]/*:rubric)">
                     <xsl:variable name="rubric_title">

                        <xsl:apply-templates select="*:msContents/*:msItem[1]/*:rubric" mode="title"/>

                     </xsl:variable>

                     <xsl:value-of select="normalize-space($rubric_title)"/>
                  </xsl:when>

                  <xsl:when test="normalize-space(*:msContents/*:msItem[1]/*:incipit)">
                     <xsl:variable name="incipit_title">

                        <xsl:apply-templates select="*:msContents/*:msItem[1]/*:incipit"
                           mode="title"/>

                     </xsl:variable>

                     <xsl:value-of select="normalize-space($incipit_title)"/>
                  </xsl:when>

                  <!--then titles from the summary-->
                  <xsl:when test="*:msContents/*:summary//*:title[not(@type)]">
                     <xsl:for-each-group select="*:msContents/*:summary//*:title[not(@type)]"
                        group-by="normalize-space(.)">
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:if test="not(position()=last())">
                           <xsl:text>, </xsl:text>
                        </xsl:if>
                     </xsl:for-each-group>
                  </xsl:when>
               </xsl:choose>

            </xsl:variable>
            
            <xsl:choose>
               <xsl:when test="normalize-space($mspart_title)">
                  
                  <xsl:value-of select="normalize-space(concat(*:msIdentifier/*:idno, ': ', $mspart_title))"/>
                  
               </xsl:when>
               <xsl:otherwise>
                  <xsl:value-of select="normalize-space(*:msIdentifier/*:idno)"/>      
               </xsl:otherwise>
               
            </xsl:choose>
            

            
         </label>

         <xsl:variable name="startPageLabel">
            <xsl:choose>
               <xsl:when test="*:msContents/*:msItem[1]/*:locus[1][normalize-space(@from)]">
                  <xsl:value-of select="*:msContents/*:msItem[1]/*:locus[1]/normalize-space(@from)"/>
               </xsl:when>
               <xsl:otherwise>

                  <xsl:choose>
                     <xsl:when test="//*:facsimile/*:surface">
                        <xsl:value-of select="//*:facsimile/*:surface[1]/@n"/>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:text>cover</xsl:text>
                     </xsl:otherwise>
                  </xsl:choose>

               </xsl:otherwise>

            </xsl:choose>
         </xsl:variable>

         <startPageLabel>
            <xsl:value-of select="$startPageLabel"/>

         </startPageLabel>

         <xsl:variable name="startPagePosition">


            <xsl:choose>
                <xsl:when test="key('surfaceNs', $startPageLabel)">
                   <xsl:apply-templates select="key('surfaceNs', $startPageLabel)" mode="count"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:text>1</xsl:text>
               </xsl:otherwise>
            </xsl:choose>


         </xsl:variable>

         <startPagePosition>
            <xsl:value-of select="$startPagePosition"/>
         </startPagePosition>

         <startPageID>
            <xsl:value-of select="concat('PHYS-',$startPagePosition)"/>
         </startPageID>



         <xsl:variable name="endPageLabel">
             <xsl:choose>
                 <xsl:when test="*:msContents/*:msItem[last()]/*:locus[1][normalize-space(@to)]">
                     <xsl:value-of select="*:msContents/*:msItem[last()]/*:locus[1]/normalize-space(@to)"/>
                 </xsl:when>
                 <xsl:otherwise>
                     
                     <xsl:choose>
                         <xsl:when test="//*:facsimile/*:surface">
                             <xsl:value-of select="//*:facsimile/*:surface[last()]/@n"/>
                         </xsl:when>
                         <xsl:otherwise>
                             <xsl:text>cover</xsl:text>
                         </xsl:otherwise>
                     </xsl:choose>
                     
                 </xsl:otherwise>
             </xsl:choose>
         </xsl:variable>

         <endPageLabel>
            <xsl:value-of select="$endPageLabel"/>
         </endPageLabel>

         <endPagePosition>

            <xsl:choose>
                <xsl:when test="key('surfaceNs', $endPageLabel)">
                   <xsl:apply-templates select="key('surfaceNs', $endPageLabel)" mode="count"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:text>1</xsl:text>
               </xsl:otherwise>
            </xsl:choose>

         </endPagePosition>

         
         <children>
            <xsl:choose>
               <xsl:when test="count(*:msContents/*:msItem) = 1">

                  <xsl:apply-templates select="*:msContents/*:msItem/*:msItem"
                     mode="logicalstructure"/>


               </xsl:when>
               <xsl:otherwise>
                  <xsl:apply-templates select="*:msContents/*:msItem" mode="logicalstructure"/>
               </xsl:otherwise>
            </xsl:choose>



            <xsl:apply-templates select="*:msPart" mode="logicalstructure"/>

         </children>


      </logicalStructure>

   </xsl:template>


   <xsl:template match="*:msItem" mode="logicalstructure">

      <logicalStructure>

         <xsl:variable name="n-tree">
            <xsl:value-of
               select="sum((count(ancestor-or-self::*[local-name()='msItem']), count(preceding::*[local-name()='msItem'])))"
            />
         </xsl:variable>

         <descriptiveMetadataID>
            <xsl:value-of select="concat('ITEM-', normalize-space($n-tree))"/>
         </descriptiveMetadataID>

         <label>
            <xsl:choose>
               <xsl:when test="normalize-space(*:title[not(@type)][1])">
                  <xsl:value-of select="normalize-space(*:title[not(@type)][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(*:title[@type='general'][1])">
                  <xsl:value-of select="normalize-space(*:title[@type='general'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(*:title[@type='desc'][1])">
                  <xsl:value-of select="normalize-space(*:title[@type='desc'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(*:title[@type='standard'][1])">
                  <xsl:value-of select="normalize-space(*:title[@type='standard'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(*:title[@type='supplied'][1])">
                  <xsl:value-of select="normalize-space(*:title[@type='supplied'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(*:rubric[1])">
                  <xsl:variable name="rubric_title">

                     <xsl:apply-templates select="*:rubric[1]" mode="title"/>

                  </xsl:variable>

                  <xsl:value-of select="normalize-space($rubric_title)"/>
               </xsl:when>

               <xsl:when test="normalize-space(*:incipit[1])">
                  <xsl:variable name="incipit_title">

                     <xsl:apply-templates select="*:incipit[1]" mode="title"/>

                  </xsl:variable>

                  <xsl:value-of select="normalize-space($incipit_title)"/>
               </xsl:when>


               <xsl:otherwise>
                  <xsl:text>Untitled Item</xsl:text>
               </xsl:otherwise>
            </xsl:choose>
         </label>

         <xsl:variable name="startPageLabel">
            <xsl:choose>
               <xsl:when test="*:locus[normalize-space(@from)]">
                  <xsl:value-of select="*:locus[1]/normalize-space(@from)"/>
               </xsl:when>
               <xsl:otherwise>

                  <xsl:choose>
                     <xsl:when test="//*:facsimile/*:surface">
                        <xsl:value-of select="//*:facsimile/*:surface[1]/@n"/>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:text>cover</xsl:text>
                     </xsl:otherwise>
                  </xsl:choose>

               </xsl:otherwise>

            </xsl:choose>
         </xsl:variable>

         <startPageLabel>
            <xsl:value-of select="$startPageLabel"/>

         </startPageLabel>

         <xsl:variable name="startPagePosition">


            <xsl:choose>
               <xsl:when test="key('surfaceNs', $startPageLabel)">
                   <xsl:apply-templates select="key('surfaceNs', $startPageLabel)" mode="count"/>
               </xsl:when>
               <xsl:otherwise>
                   <xsl:message select="concat('ERROR: ', $current_filename, ' has invalid locus/@from or surface/@n value: ''', $startPageLabel, '''')"/>
                  <xsl:text>1</xsl:text>
               </xsl:otherwise>
            </xsl:choose>


         </xsl:variable>

         <startPagePosition>
            <xsl:value-of select="$startPagePosition"/>
         </startPagePosition>

         <startPageID>
            <xsl:value-of select="concat('PHYS-',$startPagePosition)"/>
         </startPageID>



         <xsl:variable name="endPageLabel">
            <xsl:choose>
               <xsl:when test="*:locus/@to">
                  <xsl:value-of select="*:locus[1]/normalize-space(@to)"/>
               </xsl:when>
               <xsl:otherwise>

                  <xsl:choose>
                     <xsl:when test="//*:facsimile/*:surface">
                        <xsl:value-of select="//*:facsimile/*:surface[last()]/@n"/>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:text>cover</xsl:text>
                     </xsl:otherwise>
                  </xsl:choose>

               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>

         <endPageLabel>
            <xsl:value-of select="$endPageLabel"/>
         </endPageLabel>

         <endPagePosition>

            <xsl:choose>
                <xsl:when test="key('surfaceNs', $endPageLabel)">
                    <xsl:apply-templates select="key('surfaceNs', $endPageLabel)" mode="count"/>
                </xsl:when>
               <xsl:otherwise>
                   <xsl:message select="concat('ERROR: ', $current_filename, ' has invalid locus/@to or surface/@n value: ''', $endPageLabel, '''')"/>
                  <xsl:text>1</xsl:text>
               </xsl:otherwise>
            </xsl:choose>

         </endPagePosition>

         <!-- <xsl:if test="*:msContents/*:msItem">
            <children>
               <xsl:apply-templates select="*:msContents/*:msItem" mode="logicalstructure"/>
            </children>
         </xsl:if>-->

         <xsl:if test="*:msItem">
            <children>
               <xsl:apply-templates select="*:msItem" mode="logicalstructure"/>
            </children>
         </xsl:if>

      </logicalStructure>

   </xsl:template>



   <!-- ******************************HTML-->


   <xsl:template match="*:p" mode="html">

      <xsl:text>&lt;p&gt;</xsl:text>

      <xsl:apply-templates mode="html"/>

      <xsl:text>&lt;/p&gt;</xsl:text>

   </xsl:template>

   <!--allows creation of paragraphs in summary (a bit of a cheat - TEI doesn't allow p tags here so we use seg and process into p)-->
   <!--this is necessary to allow collapse to first paragraph in interface-->
   <xsl:template match="*:seg[@type='para']|tei:abstract/tei:p" mode="html">

      <xsl:text>&lt;p style=&apos;text-align: justify;&apos;&gt;</xsl:text>

      <xsl:apply-templates mode="#current"/>
      <xsl:text>&lt;/p&gt;</xsl:text>


   </xsl:template>

   <xsl:template match="tei:list" mode="html">
      <xsl:text>&lt;ul&gt;</xsl:text>
      <xsl:apply-templates mode="#current"/>
      <xsl:text>&lt;/ul&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:item" mode="html">
      <xsl:text>&lt;li&gt;</xsl:text>
      <xsl:apply-templates mode="#current"/>
      <xsl:text>&lt;/li&gt;</xsl:text>
   </xsl:template>


   <!--tables-->

   <xsl:template match="*:table" mode="html">

      <xsl:text>&lt;table border='1'&gt;</xsl:text>

      <xsl:apply-templates mode="html"/>

      <xsl:text>&lt;/table&gt;</xsl:text>

   </xsl:template>


   <xsl:template match="*:table/*:head" mode="html">

      <xsl:text>&lt;caption&gt;</xsl:text>

      <xsl:apply-templates mode="html"/>

      <xsl:text>&lt;/caption&gt;</xsl:text>

   </xsl:template>



   <xsl:template match="*:table/*:row" mode="html">

      <xsl:text>&lt;tr&gt;</xsl:text>

      <xsl:apply-templates mode="html"/>

      <xsl:text>&lt;/tr&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:table/*:row[@role='label']/*:cell" mode="html">

      <xsl:text>&lt;th&gt;</xsl:text>

      <xsl:apply-templates mode="html"/>

      <xsl:text>&lt;/th&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:table/*:row[@role='data']/*:cell" mode="html">

      <xsl:text>&lt;td&gt;</xsl:text>

      <xsl:apply-templates mode="html"/>

      <xsl:text>&lt;/td&gt;</xsl:text>

   </xsl:template>


   <!--end of tables-->


   <xsl:template match="*[not(local-name()='additions')]/*:list" mode="html">

      <xsl:text>&lt;div&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>
      <xsl:text>&lt;br /&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*[not(local-name()='additions')]/*:list/*:item" mode="html">


      <xsl:apply-templates mode="html"/>

      <xsl:text>&lt;br /&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:additions/*:list" mode="html">

      <xsl:apply-templates select="*:head" mode="html"/>

      <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>
      <xsl:apply-templates select="*[not(local-name()='head')]" mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:additions/*:list/*:item" mode="html">

      <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:lb" mode="html">

      <xsl:text>&lt;br /&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:title" mode="html">

      <xsl:text>&lt;i&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:term" mode="html">

      <xsl:text>&lt;i&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:q|*:quote" mode="html">

      <xsl:text>"</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>"</xsl:text>

   </xsl:template>

   <xsl:template match="*[@rend='italic']" mode="html">

      <xsl:text>&lt;i&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*[normalize-space(@rend)=('underline','doubleUnderline')]" mode="html">
      <xsl:text>&lt;em class="</xsl:text>
      <xsl:value-of select="normalize-space(@rend)"/>
      <xsl:text>"&gt;</xsl:text>
      <xsl:apply-templates mode="#current"/>
      <xsl:text>&lt;/em&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="*[@rend='superscript']" mode="html">

      <xsl:text>&lt;sup&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/sup&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*[@rend='subscript']" mode="html">

      <xsl:text>&lt;sub&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/sub&gt;</xsl:text>

   </xsl:template>


   <xsl:template match="*[@rend='bold']" mode="html">

      <xsl:text>&lt;b&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/b&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:g" mode="html">

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
            <xsl:text>&lt;i&gt;</xsl:text>
            <xsl:apply-templates mode="html"/>
            <xsl:text>&lt;/i&gt;</xsl:text>
         </xsl:otherwise>
      </xsl:choose>

   </xsl:template>

   <xsl:template match="*:l" mode="html">

      <xsl:if test="not(local-name(preceding-sibling::*[1]) = 'l')">
         <xsl:text>&lt;br /&gt;</xsl:text>
      </xsl:if>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;br /&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:name" mode="html">

      <xsl:choose>
         <xsl:when test="*[@type='display']">
            <xsl:value-of select="*[@type='display']"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates mode="html"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="*:ref[@type='biblio']" mode="html">

      <xsl:apply-templates mode="html"/>

   </xsl:template>




   <xsl:template match="*:ref[@type='extant_mss']" mode="html">

      <xsl:choose>
         <xsl:when test="normalize-space(@target)">
            <xsl:text>&lt;a target=&apos;_blank&apos; class=&apos;externalLink&apos; href=&apos;</xsl:text>
            <xsl:value-of select="normalize-space(@target)"/>
            <xsl:text>&apos;&gt;</xsl:text>
            <xsl:apply-templates mode="html"/>
            <xsl:text>&lt;/a&gt;</xsl:text>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates mode="html"/>
         </xsl:otherwise>
      </xsl:choose>

   </xsl:template>

   <xsl:template match="*:ref[@type='cudl_link']" mode="html">

      <xsl:choose>
         <xsl:when test="normalize-space(@target)">
            <xsl:text>&lt;a href=&apos;</xsl:text>
            <xsl:value-of select="normalize-space(@target)"/>
            <xsl:text>&apos;&gt;</xsl:text>
            <xsl:apply-templates mode="html"/>
            <xsl:text>&lt;/a&gt;</xsl:text>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates mode="html"/>
         </xsl:otherwise>
      </xsl:choose>

   </xsl:template>

   <xsl:template match="*:ref[@type='nmm_link']" mode="html">

      <xsl:choose>
         <xsl:when test="normalize-space(@target)">
            <xsl:apply-templates mode="html"/>
            <xsl:text> [</xsl:text>
            <xsl:text>&lt;a target=&apos;_blank&apos; class=&apos;externalLink&apos; href=&apos;</xsl:text>
            <xsl:value-of select="normalize-space(@target)"/>
            <xsl:text>&apos;&gt;</xsl:text>
            <xsl:text>&lt;img title="Link to RMG" alt=&apos;RMG icon&apos; class=&apos;nmm_icon&apos; src=&apos;/images/general/nmm_small.png&apos;/&gt;</xsl:text>
            <xsl:text>&lt;/a&gt;</xsl:text>
            <xsl:text>]</xsl:text>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates mode="html"/>
         </xsl:otherwise>
      </xsl:choose>

   </xsl:template>

   <xsl:template match="*:ref[not(@type)]" mode="html">

      <xsl:choose>
         <xsl:when test="normalize-space(@target)">

            <xsl:choose>

               <xsl:when test="@rend='left' or @rend='right'">

                  <xsl:text>&lt;span style=&quot;float:</xsl:text>
                  <xsl:value-of select="@rend"/>
                  <xsl:text>; text-align:center; padding-bottom:10px&quot;&gt;</xsl:text>

                  <xsl:text>&lt;a target=&apos;_blank&apos; class=&apos;externalLink&apos; href=&apos;</xsl:text>
                  <xsl:value-of select="normalize-space(@target)"/>
                  <xsl:text>&apos;&gt;</xsl:text>
                  <xsl:apply-templates mode="html"/>
                  <xsl:text>&lt;/a&gt;</xsl:text>

                  <xsl:text>&lt;/span&gt;</xsl:text>

               </xsl:when>

               <xsl:otherwise>

                  <xsl:text>&lt;a target=&apos;_blank&apos; class=&apos;externalLink&apos; href=&apos;</xsl:text>
                  <xsl:value-of select="normalize-space(@target)"/>
                  <xsl:text>&apos;&gt;</xsl:text>
                  <xsl:apply-templates mode="html"/>
                  <xsl:text>&lt;/a&gt;</xsl:text>


               </xsl:otherwise>


            </xsl:choose>

         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates mode="html"/>
         </xsl:otherwise>
      </xsl:choose>

   </xsl:template>


   <xsl:template match="*:ref[@type='popup']" mode="html">

      <xsl:choose>
         <xsl:when test="normalize-space(@target)">

            <xsl:choose>

               <xsl:when test="@rend='left' or @rend='right'">

                  <xsl:text>&lt;span style=&quot;float:</xsl:text>
                  <xsl:value-of select="@rend"/>
                  <xsl:text>; text-align:center; padding-bottom:10px&quot;&gt;</xsl:text>

                  <xsl:text>&lt;a class=&apos;popup&apos; href=&apos;</xsl:text>
                  <xsl:value-of select="normalize-space(@target)"/>
                  <xsl:text>&apos;&gt;</xsl:text>
                  <xsl:apply-templates mode="html"/>
                  <xsl:text>&lt;/a&gt;</xsl:text>

                  <xsl:text>&lt;/span&gt;</xsl:text>

               </xsl:when>

               <xsl:otherwise>

                  <xsl:text>&lt;a class=&apos;popup&apos; href=&apos;</xsl:text>
                  <xsl:value-of select="normalize-space(@target)"/>
                  <xsl:text>&apos;&gt;</xsl:text>
                  <xsl:apply-templates mode="html"/>
                  <xsl:text>&lt;/a&gt;</xsl:text>


               </xsl:otherwise>


            </xsl:choose>

         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates mode="html"/>
         </xsl:otherwise>
      </xsl:choose>

   </xsl:template>


   <xsl:template match="*:locus" mode="html">
      

      <xsl:variable name="from" select="normalize-space(@from)"/>


      <xsl:variable name="page">
         <xsl:variable name="context-root" select="ancestor::*[last()]"/>
         <xsl:choose>
            <xsl:when test="$context-root[not(self::*:TEI|self::*:teiCorpus)]">
               <xsl:text>1</xsl:text>
            </xsl:when>
            <xsl:when test="key('surfaceNs', $from, $context-root)">
                <xsl:apply-templates select="key('surfaceNs', $from, $context-root)" mode="count"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:text>1</xsl:text>
            </xsl:otherwise>
         </xsl:choose>

      </xsl:variable>

      <xsl:text>&lt;a href=&apos;&apos; onclick=&apos;store.loadPage(</xsl:text>
      <xsl:value-of select="$page"/>
      <xsl:text>);return false;&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/a&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:graphic[not(@url)]" mode="html">

      <xsl:text>&lt;i class=&apos;graphic&apos; style=&apos;font-style:italic;&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>

   </xsl:template>


   <xsl:template match="*:graphic[@url]" mode="html">


      <xsl:variable name="float">
         <xsl:choose>
            <xsl:when test="@rend='right'">
               <xsl:text>float:right</xsl:text>

            </xsl:when>
            <xsl:when test="@rend='left'">
               <xsl:text>float:left</xsl:text>

            </xsl:when>
            <xsl:otherwise> </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:text>&lt;img style=&quot;padding:10px;</xsl:text>
      <xsl:value-of select="$float"/>
      <xsl:text>&quot; src=&quot;</xsl:text>
      <xsl:value-of select="@url"/>
      <xsl:text>&quot; /&gt;</xsl:text>

   </xsl:template>


   <xsl:template match="*:damage" mode="html">

      <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
      <xsl:text>[</xsl:text>
      <xsl:text>&lt;/i&gt;</xsl:text>
      <xsl:text>&lt;i class=&apos;damage&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal;&apos;</xsl:text>
      <xsl:text> title=&apos;This text damaged in source&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>
      <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
      <xsl:text>]</xsl:text>
      <xsl:text>&lt;/i&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:sic" mode="html">

      <xsl:text>&lt;i class=&apos;error&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal;&apos;</xsl:text>
      <xsl:text> title=&apos;This text in error in source&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>
      <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
      <xsl:text>(!)</xsl:text>
      <xsl:text>&lt;/i&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:term/*:sic" mode="html">

      <xsl:text>&lt;i class=&apos;error&apos;</xsl:text>
      <xsl:text> title=&apos;This text in error in source&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>
      <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
      <xsl:text> style=&apos;color:red&apos;&gt;</xsl:text>
      <xsl:text>(!)</xsl:text>
      <xsl:text>&lt;/i&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:unclear" mode="html">

      <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
      <xsl:text>[</xsl:text>
      <xsl:text>&lt;/i&gt;</xsl:text>
      <xsl:text>&lt;i class=&apos;unclear&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal;&apos;</xsl:text>
      <xsl:text> title=&apos;This text imperfectly legible in source&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>
      <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
      <xsl:text>]</xsl:text>
      <xsl:text>&lt;/i&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:supplied" mode="html">

      <xsl:text>&lt;i class=&apos;supplied&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal;&apos;</xsl:text>
      <xsl:text> title=&apos;This text supplied by transcriber&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:add" mode="html">

      <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
      <xsl:text>\</xsl:text>
      <xsl:text>&lt;/i&gt;</xsl:text>
      <xsl:text>&lt;i class=&apos;add&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal;&apos;</xsl:text>
      <xsl:text> title=&apos;This text added&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>
      <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
      <xsl:text>/</xsl:text>
      <xsl:text>&lt;/i&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:del[@type='illegible']" mode="html">

      <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
      <xsl:text>&#x301A;</xsl:text>
      <xsl:text>&lt;/i&gt;</xsl:text>
      <xsl:text>&lt;i class=&apos;del&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal;&apos;</xsl:text>
      <xsl:text> title=&apos;This text deleted and illegible&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>
      <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
      <xsl:text>&#x301B;</xsl:text>
      <xsl:text>&lt;/i&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:del" mode="html">

      <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
      <xsl:text>&#x301A;</xsl:text>
      <xsl:text>&lt;/i&gt;</xsl:text>
      <xsl:text>&lt;i class=&apos;del&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal; text-decoration:line-through;&apos;</xsl:text>
      <xsl:text> title=&apos;This text deleted&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>
      <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
      <xsl:text>&#x301B;</xsl:text>
      <xsl:text>&lt;/i&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:subst" mode="html">

      <xsl:apply-templates mode="html"/>

   </xsl:template>

   <xsl:template match="*:gap" mode="html">

      <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
      <xsl:text>&gt;-</xsl:text>
      <xsl:text>&lt;/i&gt;</xsl:text>
      <xsl:text>&lt;i class=&apos;gap&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>
      <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
      <xsl:text>-&lt;</xsl:text>
      <xsl:text>&lt;/i&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:desc" mode="html">

      <xsl:apply-templates mode="html"/>

   </xsl:template>

   <xsl:template match="*:choice[*:orig][*:reg[@type='hyphenated']]" mode="html">

      <xsl:text>&lt;i class=&apos;reg&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal;&apos;</xsl:text>
      <xsl:text> title=&apos;String hyphenated for display. Original: </xsl:text>
      <xsl:value-of select="normalize-space(*:orig)"/>
      <xsl:text>&apos;&gt;</xsl:text>
      <xsl:apply-templates select="*:reg[@type='hyphenated']" mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>

   </xsl:template>




   <xsl:template match="*:reg" mode="html">

      <xsl:apply-templates mode="html"/>

   </xsl:template>

   <!-- <xsl:template match="*:reg[@type='hyphenated']" mode="html">
      
      <xsl:value-of select="replace(., '-', '')"/> 
     
   </xsl:template>-->



   <xsl:template match="text()" mode="html">

      <xsl:variable name="translated" select="translate(., '^&#x00A7;', '&#x00A0;&#x30FB;')"/>
      <!--      <xsl:variable name="replaced" select="replace($translated, '&#x005F;&#x005F;&#x005F;', '&#x2014;&#x2014;&#x2014;')" /> -->
      <xsl:variable name="replaced"
         select="replace($translated, '_ _ _', '&#x2014;&#x2014;&#x2014;')"/>
      <xsl:value-of select="$replaced"/>

   </xsl:template>


   <!--************************************BIBLIOGRAPHY PROCESSING-->
   <xsl:template name="get-doc-biblio">

      <xsl:if test="*:additional//*:listBibl">

         <bibliographies>

            <xsl:attribute name="display" select="'true'"/>

            <bibliography>

               <xsl:attribute name="display" select="'true'"/>

               <xsl:variable name="bibliography">
                  <xsl:apply-templates select="*:additional//*:listBibl" mode="html"/>
               </xsl:variable>

               <xsl:attribute name="displayForm" select="normalize-space($bibliography)"/>
               <!-- <xsl:value-of select="normalize-space($bibliography)" /> -->
               <xsl:value-of
                  select="normalize-space(replace($bibliography, '&lt;[^&gt;]+&gt;', ''))"/>

            </bibliography>

         </bibliographies>

      </xsl:if>

   </xsl:template>


   <xsl:template name="get-doc-and-item-biblio">

      <xsl:if test="*:additional//*:listBibl|*:msContents/*:msItem[1]/*:listBibl">

         <bibliographies>

            <xsl:attribute name="display" select="'true'"/>

            <bibliography>

               <xsl:attribute name="display" select="'true'"/>

               <xsl:variable name="bibliography">
                  <xsl:apply-templates
                     select="*:additional//*:listBibl|*:msContents/*:msItem[1]/*:listBibl"
                     mode="html"/>
               </xsl:variable>

               <xsl:attribute name="displayForm" select="normalize-space($bibliography)"/>
               <!-- <xsl:value-of select="normalize-space($bibliography)" /> -->
               <xsl:value-of
                  select="normalize-space(replace($bibliography, '&lt;[^&gt;]+&gt;', ''))"/>

            </bibliography>

         </bibliographies>

      </xsl:if>

   </xsl:template>


   <xsl:template name="get-item-biblio">

      <xsl:if test="*:listBibl">

         <!--         <bibliographies> -->
         <bibliographies>

            <xsl:attribute name="display" select="'true'"/>

            <bibliography>

               <xsl:attribute name="display" select="'true'"/>
               <xsl:variable name="bibliography">
                  <xsl:apply-templates select="*:listBibl" mode="html"/>
               </xsl:variable>

               <xsl:attribute name="displayForm" select="normalize-space($bibliography)"/>
               <!-- <xsl:value-of select="normalize-space($bibliography)" /> -->
               <xsl:value-of
                  select="normalize-space(replace($bibliography, '&lt;[^&gt;]+&gt;', ''))"/>

            </bibliography>

         </bibliographies>

      </xsl:if>

   </xsl:template>

   <xsl:template match="*:head" mode="html">

      <!-- <xsl:text>&lt;br /&gt;</xsl:text> -->

      <xsl:text>&lt;p&gt;&lt;b&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/b&gt;&lt;/p&gt;</xsl:text>

   </xsl:template>

   <xsl:template match="*:listBibl" mode="html">


      <xsl:apply-templates select="*:head" mode="html"/>

      <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>
      <xsl:apply-templates select=".//*:bibl|.//*:biblStruct" mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>

      <xsl:text>&lt;br /&gt;</xsl:text>

   </xsl:template>


   <xsl:template match="*:listBibl//*:bibl" mode="html">

      <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>

   </xsl:template>


   <xsl:template match="*:listBibl//*:biblStruct[not(*)]" mode="html">

      <!-- Template to catch biblStruct w no child elements and treat like bibl - shouldn't really happen but frequently does, so prob easiest to handle it -->

      <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>

   </xsl:template>


   <xsl:template match="*:listBibl//*:biblStruct[*:analytic]" mode="html">

      <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;</xsl:text>

      <xsl:choose>
         <xsl:when test="@xml:id">
            <xsl:text> id=&quot;</xsl:text>
            <xsl:value-of select="normalize-space(@xml:id)"/>
            <xsl:text>&quot;</xsl:text>
         </xsl:when>
         <xsl:when test="*:idno[@type='callNumber']">
            <xsl:text> id=&quot;</xsl:text>
            <xsl:value-of select="normalize-space(*:idno)"/>
            <xsl:text>&quot;</xsl:text>
         </xsl:when>
      </xsl:choose>

      <xsl:text>&gt;</xsl:text>

      <xsl:choose>
         <xsl:when
            test="@type='bookSection' or @type='encyclopaediaArticle' or @type='encyclopediaArticle'">

            <xsl:for-each select="*:analytic">

               <xsl:for-each select="*:author|*:editor">

                  <xsl:call-template name="get-names-first-surname-first"/>

               </xsl:for-each>

               <xsl:text>, </xsl:text>

               <xsl:for-each select="*:title">

                  <xsl:text>&quot;</xsl:text>
                  <xsl:value-of select="normalize-space(.)"/>
                  <xsl:text>&quot;</xsl:text>

               </xsl:for-each>

            </xsl:for-each>

            <xsl:text>, in </xsl:text>

            <xsl:for-each select="*:monogr">

               <xsl:choose>
                  <xsl:when test="*:author">

                     <xsl:for-each select="*:author">

                        <xsl:call-template name="get-names-all-forename-first"/>

                     </xsl:for-each>

                     <xsl:text>, </xsl:text>

                     <xsl:for-each select="*:title[not (@type='short')]">

                        <xsl:text>&lt;i&gt;</xsl:text>
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:text>&lt;/i&gt;</xsl:text>

                     </xsl:for-each>

                     <xsl:if test="*:editor">

                        <xsl:text>, ed. </xsl:text>

                        <xsl:for-each select="*:editor">

                           <xsl:call-template name="get-names-all-forename-first"/>

                        </xsl:for-each>

                     </xsl:if>

                  </xsl:when>

                  <xsl:when test="*:editor">

                     <xsl:for-each select="*:editor">

                        <xsl:call-template name="get-names-all-forename-first"/>

                     </xsl:for-each>


                     <xsl:choose>
                        <xsl:when test="(count(*:editor) &gt; 1)">
                           <xsl:text> (eds)</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:text> (ed.)</xsl:text>
                        </xsl:otherwise>
                     </xsl:choose>

                     <xsl:text>, </xsl:text>

                     <xsl:for-each select="*:title[not(@type='short')]">

                        <xsl:text>&lt;i&gt;</xsl:text>
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:text>&lt;/i&gt;</xsl:text>

                     </xsl:for-each>

                  </xsl:when>

                  <xsl:otherwise>

                     <xsl:for-each select="*:title[not(@type='short')]">

                        <xsl:text>&lt;i&gt;</xsl:text>
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:text>&lt;/i&gt;</xsl:text>

                     </xsl:for-each>

                  </xsl:otherwise>

               </xsl:choose>

               <xsl:if test="*:edition">
                  <xsl:text> </xsl:text>
                  <xsl:value-of select="*:edition"/>
               </xsl:if>

               <xsl:if test="*:respStmt">

                  <xsl:for-each select="*:respStmt">

                     <xsl:text> </xsl:text>

                     <xsl:call-template name="get-respStmt"/>

                  </xsl:for-each>

               </xsl:if>



               <xsl:if test="../*:series">

                  <xsl:for-each select="../*:series">

                     <xsl:text>, </xsl:text>

                     <xsl:for-each select="*:title">

                        <!-- <xsl:text>&lt;i&gt;</xsl:text> -->
                        <xsl:value-of select="normalize-space(.)"/>
                        <!-- <xsl:text>&lt;/i&gt;</xsl:text> -->

                     </xsl:for-each>

                     <xsl:if test=".//*:biblScope">

                        <xsl:for-each select=".//*:biblScope">

                           <xsl:text> </xsl:text>

                           <xsl:if test="@type">
                              <xsl:value-of select="normalize-space(@type)"/>
                              <xsl:text>. </xsl:text>
                           </xsl:if>

                           <xsl:value-of select="normalize-space(.)"/>

                        </xsl:for-each>

                     </xsl:if>

                  </xsl:for-each>

               </xsl:if>

               <xsl:if test="*:imprint">

                  <xsl:text> </xsl:text>

                  <xsl:for-each select="*:imprint">

                     <xsl:call-template name="get-imprint"/>

                  </xsl:for-each>

               </xsl:if>


               <xsl:if test=".//*:biblScope">

                  <xsl:for-each select=".//*:biblScope">

                     <xsl:text> </xsl:text>

                     <xsl:if test="@type">
                        <xsl:value-of select="normalize-space(@type)"/>
                        <xsl:text>. </xsl:text>
                     </xsl:if>

                     <xsl:value-of select="normalize-space(.)"/>

                  </xsl:for-each>

               </xsl:if>

            </xsl:for-each>

            <xsl:text>.</xsl:text>

         </xsl:when>

         <xsl:when test="@type='journalArticle'">

            <xsl:for-each select="*:analytic">

               <xsl:for-each select="*:author|*:editor">

                  <xsl:call-template name="get-names-first-surname-first"/>

               </xsl:for-each>

               <xsl:text>, </xsl:text>

               <xsl:for-each select="*:title">

                  <xsl:text>&quot;</xsl:text>
                  <xsl:value-of select="normalize-space(.)"/>
                  <xsl:text>&quot;</xsl:text>

               </xsl:for-each>

            </xsl:for-each>

            <xsl:text>, </xsl:text>

            <xsl:for-each select="*:monogr">

               <xsl:for-each select="*:title[not(@type='short')]">

                  <xsl:text>&lt;i&gt;</xsl:text>
                  <xsl:value-of select="normalize-space(.)"/>
                  <xsl:text>&lt;/i&gt;</xsl:text>

               </xsl:for-each>

               <xsl:if test=".//*:biblScope">

                  <xsl:for-each select=".//*:biblScope">

                     <xsl:text> </xsl:text>

                     <xsl:if test="@type">
                        <xsl:value-of select="normalize-space(@type)"/>
                        <xsl:text>. </xsl:text>
                     </xsl:if>

                     <xsl:value-of select="normalize-space(.)"/>

                  </xsl:for-each>

               </xsl:if>

               <xsl:if test="../*:series">

                  <xsl:for-each select="../*:series">

                     <xsl:text>, </xsl:text>

                     <xsl:for-each select="*:title">

                        <!-- <xsl:text>&lt;i&gt;</xsl:text> -->
                        <xsl:value-of select="normalize-space(.)"/>
                        <!-- <xsl:text>&lt;/i&gt;</xsl:text> -->

                     </xsl:for-each>

                     <xsl:if test=".//*:biblScope">

                        <xsl:for-each select=".//*:biblScope">

                           <xsl:text>. </xsl:text>

                           <xsl:if test="@type">
                              <xsl:value-of select="normalize-space(@type)"/>
                              <xsl:text> </xsl:text>
                           </xsl:if>

                           <xsl:value-of select="normalize-space(.)"/>

                        </xsl:for-each>

                     </xsl:if>

                  </xsl:for-each>

               </xsl:if>

               <xsl:if test="*:imprint">

                  <xsl:text> </xsl:text>

                  <xsl:for-each select="*:imprint">

                     <xsl:call-template name="get-imprint"/>

                  </xsl:for-each>

               </xsl:if>

            </xsl:for-each>

            <xsl:text>.</xsl:text>

         </xsl:when>

         <xsl:otherwise> </xsl:otherwise>

      </xsl:choose>

      <xsl:text>&lt;/div&gt;</xsl:text>

   </xsl:template>



   <xsl:template match="*:listBibl//*:biblStruct[*:monogr and not(*:analytic)]" mode="html">

      <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;</xsl:text>

      <xsl:choose>
         <xsl:when test="@xml:id">
            <xsl:text> id=&quot;</xsl:text>
            <xsl:value-of select="normalize-space(@xml:id)"/>
            <xsl:text>&quot;</xsl:text>
         </xsl:when>
         <xsl:when test="*:idno[@type='callNumber']">
            <xsl:text> id=&quot;</xsl:text>
            <xsl:value-of select="normalize-space(*:idno)"/>
            <xsl:text>&quot;</xsl:text>
         </xsl:when>
      </xsl:choose>

      <xsl:text>&gt;</xsl:text>

      <xsl:choose>
         <xsl:when
            test="@type='book' or @type='document' or @type='thesis' or @type='manuscript' or @type='webpage'">

            <xsl:for-each select="*:monogr">

               <xsl:choose>
                  <xsl:when test="*:author">

                     <xsl:for-each select="*:author">

                        <xsl:call-template name="get-names-first-surname-first"/>

                     </xsl:for-each>

                     <xsl:text>, </xsl:text>

                     <xsl:for-each select="*:title[not(@type='short')]">

                        <xsl:text>&lt;i&gt;</xsl:text>
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:text>&lt;/i&gt;</xsl:text>

                     </xsl:for-each>

                     <xsl:if test="*:editor">

                        <xsl:text>, ed. </xsl:text>

                        <xsl:for-each select="*:editor">

                           <xsl:call-template name="get-names-all-forename-first"/>

                        </xsl:for-each>

                     </xsl:if>

                  </xsl:when>

                  <xsl:when test="*:editor">

                     <xsl:for-each select="*:editor">

                        <xsl:call-template name="get-names-first-surname-first"/>

                     </xsl:for-each>


                     <xsl:choose>
                        <xsl:when test="(count(*:editor) &gt; 1)">
                           <xsl:text> (eds)</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:text> (ed.)</xsl:text>
                        </xsl:otherwise>
                     </xsl:choose>

                     <xsl:text>, </xsl:text>

                     <xsl:for-each select="*:title[not(@type='short')]">

                        <xsl:text>&lt;i&gt;</xsl:text>
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:text>&lt;/i&gt;</xsl:text>

                     </xsl:for-each>

                  </xsl:when>

                  <xsl:otherwise>

                     <xsl:for-each select="*:title[not(@type='short')]">

                        <xsl:text>&lt;i&gt;</xsl:text>
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:text>&lt;/i&gt;</xsl:text>

                     </xsl:for-each>

                  </xsl:otherwise>

               </xsl:choose>

               <xsl:if test="*:edition">
                  <xsl:text> </xsl:text>
                  <xsl:value-of select="*:edition"/>
               </xsl:if>

               <xsl:if test="*:respStmt">

                  <xsl:for-each select="*:respStmt">

                     <xsl:text> </xsl:text>

                     <xsl:call-template name="get-respStmt"/>

                  </xsl:for-each>

               </xsl:if>



               <xsl:if test="../*:series">

                  <xsl:for-each select="../*:series">

                     <xsl:text>, </xsl:text>

                     <xsl:for-each select="*:title">

                        <!-- <xsl:text>&lt;i&gt;</xsl:text> -->
                        <xsl:value-of select="normalize-space(.)"/>
                        <!-- <xsl:text>&lt;/i&gt;</xsl:text> -->

                     </xsl:for-each>

                     <xsl:if test=".//*:biblScope">

                        <xsl:for-each select=".//*:biblScope">


                           <xsl:text> </xsl:text>

                           <xsl:if test="@type">
                              <xsl:value-of select="normalize-space(@type)"/>
                              <xsl:text>. </xsl:text>
                           </xsl:if>

                           <xsl:value-of select="normalize-space(.)"/>

                        </xsl:for-each>

                     </xsl:if>

                  </xsl:for-each>

               </xsl:if>

               <xsl:if test="*:extent">

                  <xsl:for-each select="*:extent">

                     <xsl:text>, </xsl:text>

                     <xsl:value-of select="normalize-space(.)"/>

                  </xsl:for-each>

               </xsl:if>


               <xsl:if test="*:imprint">

                  <xsl:for-each select="*:imprint">

                     <xsl:text> </xsl:text>

                     <xsl:call-template name="get-imprint"/>

                  </xsl:for-each>

               </xsl:if>


               <xsl:if test=".//*:biblScope">

                  <xsl:for-each select=".//*:biblScope">

                     <xsl:text> </xsl:text>

                     <xsl:if test="@type">
                        <xsl:value-of select="normalize-space(@type)"/>
                        <xsl:text>. </xsl:text>
                     </xsl:if>

                     <xsl:value-of select="normalize-space(.)"/>

                  </xsl:for-each>

               </xsl:if>



            </xsl:for-each>

            <xsl:if test="*:idno[@type='ISBN']">

               <xsl:for-each select="*:idno[@type='ISBN']">

                  <xsl:text> ISBN: </xsl:text>
                  <xsl:value-of select="normalize-space(.)"/>

               </xsl:for-each>

            </xsl:if>



            <xsl:text>.</xsl:text>

         </xsl:when>

         <xsl:otherwise> </xsl:otherwise>
      </xsl:choose>


      <xsl:text>&lt;/div&gt;</xsl:text>

   </xsl:template>


   <!--names processing for bibliography-->
   <xsl:template name="get-names-first-surname-first">

      <xsl:choose>
         <xsl:when test="position() = 1">
            <!-- first author = surname first -->

            <xsl:choose>
               <xsl:when test=".//*:surname">
                  <!-- surname explicitly present -->

                  <xsl:for-each select=".//*:surname">
                     <xsl:value-of select="normalize-space(.)"/>
                     <xsl:if test="not(position()=last())">
                        <xsl:text> </xsl:text>
                     </xsl:if>
                  </xsl:for-each>

                  <xsl:if test=".//*:forename">
                     <xsl:text>, </xsl:text>

                     <xsl:for-each select=".//*:forename">
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:if test="not(position()=last())">
                           <xsl:text> </xsl:text>
                        </xsl:if>
                     </xsl:for-each>

                  </xsl:if>

               </xsl:when>
               <xsl:when test="*:name[not(*)]">
                  <!-- just a name, not surname/forename -->

                  <xsl:for-each select=".//*:name[not(*)]">
                     <xsl:value-of select="normalize-space(.)"/>
                     <xsl:if test="not(position()=last())">
                        <xsl:text> </xsl:text>
                     </xsl:if>
                  </xsl:for-each>

               </xsl:when>

               <xsl:otherwise>
                  <!-- forenames only? not sure what else to do but render them -->

                  <xsl:for-each select=".//*:forename">
                     <xsl:value-of select="normalize-space(.)"/>
                     <xsl:if test="not(position()=last())">
                        <xsl:text> </xsl:text>
                     </xsl:if>
                  </xsl:for-each>

               </xsl:otherwise>
            </xsl:choose>

         </xsl:when>
         <xsl:otherwise>
            <!-- not first author = forenames first -->

            <xsl:choose>
               <xsl:when test="position()=last()">
                  <xsl:text> and </xsl:text>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:text>, </xsl:text>
               </xsl:otherwise>
            </xsl:choose>

            <xsl:choose>
               <xsl:when test=".//*:surname">
                  <!-- surname explicitly present -->

                  <xsl:if test=".//*:forename">

                     <xsl:for-each select=".//*:forename">
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:if test="not(position()=last())">
                           <xsl:text> </xsl:text>
                        </xsl:if>
                     </xsl:for-each>

                     <xsl:text> </xsl:text>

                  </xsl:if>

                  <xsl:for-each select=".//*:surname">
                     <xsl:value-of select="normalize-space(.)"/>
                     <xsl:if test="not(position()=last())">
                        <xsl:text> </xsl:text>
                     </xsl:if>
                  </xsl:for-each>

               </xsl:when>
               <xsl:when test="*:name[not(*)]">
                  <!-- just a name, not forename/surname -->

                  <xsl:for-each select=".//*:name[not(*)]">
                     <xsl:value-of select="normalize-space(.)"/>
                     <xsl:if test="not(position()=last())">
                        <xsl:text> </xsl:text>
                     </xsl:if>
                  </xsl:for-each>

               </xsl:when>
               <xsl:otherwise>
                  <!-- forenames only? not sure what else to do but render them -->

                  <xsl:for-each select=".//*:forename">
                     <xsl:value-of select="normalize-space(.)"/>
                     <xsl:if test="not(position()=last())">
                        <xsl:text> </xsl:text>
                     </xsl:if>
                  </xsl:for-each>

               </xsl:otherwise>

            </xsl:choose>

         </xsl:otherwise>
      </xsl:choose>

   </xsl:template>

   <xsl:template name="get-names-all-forename-first">

      <xsl:choose>
         <xsl:when test="position() = 1"/>
         <xsl:when test="position()=last()">
            <xsl:text> and </xsl:text>
         </xsl:when>
         <xsl:otherwise>
            <xsl:text>, </xsl:text>
         </xsl:otherwise>
      </xsl:choose>

      <xsl:for-each select=".//*:name[not(*)]">
         <xsl:value-of select="normalize-space(.)"/>
         <xsl:if test="not(position()=last())">
            <xsl:text> </xsl:text>
         </xsl:if>
      </xsl:for-each>

      <xsl:for-each select=".//*:forename">
         <xsl:value-of select="normalize-space(.)"/>
         <xsl:if test="not(position()=last())">
            <xsl:text> </xsl:text>
         </xsl:if>
      </xsl:for-each>

      <xsl:text> </xsl:text>

      <xsl:for-each select=".//*:surname">
         <xsl:value-of select="normalize-space(.)"/>
         <xsl:if test="not(position()=last())">
            <xsl:text> </xsl:text>
         </xsl:if>
      </xsl:for-each>

   </xsl:template>

   <xsl:template name="get-imprint">


      <xsl:variable name="pubText">

         <xsl:if test="*:note[@type='thesisType']">
            <xsl:for-each select="*:note[@type='thesisType']">
               <xsl:value-of select="normalize-space(.)"/>
               <xsl:text> thesis</xsl:text>
            </xsl:for-each>
            <xsl:text> </xsl:text>
         </xsl:if>

         <xsl:if test="*:pubPlace">
            <xsl:for-each select="*:pubPlace">
               <xsl:value-of select="normalize-space(.)"/>
            </xsl:for-each>
            <xsl:text>: </xsl:text>
         </xsl:if>

         <xsl:if test="*:publisher">
            <xsl:for-each select="*:publisher">
               <xsl:value-of select="normalize-space(.)"/>
            </xsl:for-each>
            <xsl:if test="*:date">
               <xsl:text>, </xsl:text>
            </xsl:if>
         </xsl:if>

         <xsl:if test="*:date">
            <xsl:for-each select="*:date">
               <xsl:value-of select="normalize-space(.)"/>
            </xsl:for-each>
         </xsl:if>




      </xsl:variable>


      <xsl:if test="normalize-space($pubText)">

         <xsl:text>(</xsl:text>
         <xsl:value-of select="$pubText"/>
         <xsl:text>)</xsl:text>

      </xsl:if>



      <xsl:if test="*:note[@type='url']">
         <xsl:text> &lt;a target=&apos;_blank&apos; class=&apos;externalLink&apos; href=&apos;</xsl:text>
         <xsl:value-of select="*:note[@type='url']"/>
         <xsl:text>&apos;&gt;</xsl:text>
         <xsl:value-of select="*:note[@type='url']"/>
         <xsl:text>&lt;/a&gt;</xsl:text>
      </xsl:if>

      <xsl:if test="*:note[@type='accessed']">
         <xsl:text> Accessed: </xsl:text>
         <xsl:for-each select="*:note[@type='accessed']">
            <xsl:value-of select="normalize-space(.)"/>
         </xsl:for-each>
      </xsl:if>

   </xsl:template>

   <xsl:template name="get-respStmt">

      <xsl:choose>
         <xsl:when test="*">
            <xsl:for-each select="*:resp">
               <xsl:value-of select="."/>
               <xsl:text>: </xsl:text>
            </xsl:for-each>
            <xsl:for-each select=".//*:forename">
               <xsl:value-of select="."/>
               <xsl:text> </xsl:text>
            </xsl:for-each>
            <xsl:for-each select=".//*:surname">
               <xsl:value-of select="."/>
               <xsl:if test="not(position()=last())">
                  <xsl:text> </xsl:text>
               </xsl:if>
            </xsl:for-each>
            <xsl:for-each select=".//*:name[not(*)]">
               <xsl:value-of select="."/>
               <xsl:if test="not(position()=last())">
                  <xsl:text> </xsl:text>
               </xsl:if>
            </xsl:for-each>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="."/>
         </xsl:otherwise>
      </xsl:choose>

   </xsl:template>

   <xsl:template name="output-date-elems">
      <xsl:param name="date_elem"/>

      <xsl:choose>
         <xsl:when test="$date_elem/@from">
            <dateStart>
               <xsl:value-of select="$date_elem/@from"/>
            </dateStart>
         </xsl:when>
         <xsl:when test="$date_elem/@notBefore">
            <dateStart>
               <xsl:value-of select="$date_elem/@notBefore"/>
            </dateStart>
         </xsl:when>
         <xsl:when test="$date_elem/@when">
            <dateStart>
               <xsl:value-of select="$date_elem/@when"/>
            </dateStart>
         </xsl:when>
         <xsl:otherwise/>
      </xsl:choose>

      <xsl:choose>
         <xsl:when test="$date_elem/@to">
            <dateEnd>
               <xsl:value-of select="$date_elem/@to"/>
            </dateEnd>
         </xsl:when>
         <xsl:when test="$date_elem/@notAfter">
            <dateEnd>
               <xsl:value-of select="$date_elem/@notBefore"/>
            </dateEnd>
         </xsl:when>
         <xsl:when test="$date_elem/@when">
            <dateEnd>
               <xsl:value-of select="$date_elem/@when"/>
            </dateEnd>
         </xsl:when>
         <xsl:otherwise/>
      </xsl:choose>

      <dateDisplay display="true">
         <xsl:variable name="dateDisplay">
            <xsl:apply-templates select="$date_elem" mode="html"/>
         </xsl:variable>

         <xsl:attribute name="displayForm" select="normalize-space($dateDisplay)"/>
         <xsl:value-of select="normalize-space($dateDisplay)"/>
      </dateDisplay>
   </xsl:template>

   <xsl:template name="get-calendarnum">
      <!--CHANGE-->
      <!--<xsl:variable name="dcpID" select="(ancestor-or-self::tei:teiHeader//tei:idno[@type='calendarnum'],root(.)/*/@xml:id)[normalize-space(.)][1]"/>-->
      <xsl:variable name="dcpID"
         select="ancestor-or-self::tei:teiHeader//tei:idno[@type='calendarnum']"/>
      <xsl:if test="$dcpID">
         <calendarnum display="true" displayForm="{$dcpID}">
            <xsl:value-of select="$dcpID"/>
         </calendarnum>
      </xsl:if>
   </xsl:template>

   <xsl:template name="get-correspDesc-details">
      <!-- This template returns the author, date and recipient -->
      <xsl:message>correspDesc</xsl:message>
      <xsl:variable name="correspDesc" select="//tei:correspDesc" as="item()*"/>

      <xsl:if
         test="exists($correspDesc) and exists(//tei:publicationStmt/tei:authority[lower-case(normalize-space(.)) = 'darwin correspondence project'])">
         <xsl:message>DCP file</xsl:message>

         <xsl:if test="//tei:note[@type='physdesc'][normalize-space(.)]">
            <!-- TODO: physdesc is not just extent, it's also all manner of abbreviate to indicate whether it's an
                       autograph signed letter, etc. We either display it all as it is or suppress 
            -->
            <xsl:variable name="physdesc" as="xsd:string*">
               <xsl:for-each select="//tei:note[@type='physdesc'][normalize-space(.)]">
                  <xsl:apply-templates select="." mode="html"/>
                  <xsl:if test="position() ne last()">
                     <xsl:text>, </xsl:text>
                  </xsl:if>
               </xsl:for-each>
            </xsl:variable>
            <extent display="true" displayForm="{normalize-space(string-join($physdesc,''))}">
               <xsl:value-of select="normalize-space(string-join($physdesc,''))"/>
            </extent>
         </xsl:if>
         <xsl:if
            test="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:seriesStmt/tei:biblScope[@unit='vol'][normalize-space(.)]">
            <dataSources display="true">
               <xsl:variable name="vol-nums"
                  select="distinct-values(/tei:TEI/tei:teiHeader/tei:fileDesc/tei:seriesStmt/tei:biblScope[@unit='vol'][normalize-space(.)]/normalize-space(.))"/>
               <xsl:variable name="dsStatement" as="xsd:string*">
                  <xsl:variable name="volume" as="xsd:string*">
                     <xsl:variable name="t" as="xsd:string*">
                        <xsl:for-each select="$vol-nums">
                           <xsl:value-of select="normalize-space(.)"/>
                           <xsl:choose>
                              <xsl:when test="position() lt last() -1">
                                 <xsl:text>, </xsl:text>
                              </xsl:when>
                              <xsl:when test="position() eq last() -1">
                                 <xsl:text> &amp; </xsl:text>
                              </xsl:when>
                              <xsl:otherwise/>
                           </xsl:choose>
                        </xsl:for-each>
                     </xsl:variable>
                     <xsl:value-of select="normalize-space(string-join($t,''))"/>
                  </xsl:variable>
                  <xsl:choose>
                     <xsl:when test="$volume !=''">
                        <xsl:variable name="inflected-vol-label"
                           select="if (count($vol-nums) gt 1) then 'volumes' else 'volume'"
                           as="xsd:string"/>
                        <xsl:value-of
                           select="concat('Published in ',$inflected-vol-label,' ', $volume, ' of the Correspondence of Charles Darwin, Cambridge University Press')"
                        />
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:text>Darwin Correspondence Project</xsl:text>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:variable>

               <dataSource display="true" displayForm="{normalize-space($dsStatement)}">
                  <xsl:value-of
                     select="normalize-space(replace($dsStatement, '&lt;[^&gt;]+&gt;', ''))"/>
               </dataSource>
            </dataSources>
         </xsl:if>
      </xsl:if>
      <xsl:message
         select="exists($correspDesc//tei:correspAction[@type='sent']/(tei:persName|tei:orgName|tei:name)[normalize-space(.)])"/>

      <xsl:if
         test="$correspDesc//tei:correspAction[@type='sent']/(tei:persName|tei:orgName|tei:name)[normalize-space(.)]">

         <authors display="true">
            <xsl:apply-templates
               select="$correspDesc//tei:correspAction[@type='sent']/(tei:persName|tei:orgName|tei:name)[normalize-space(.)]"
            />
         </authors>

      </xsl:if>

      <xsl:if
         test="$correspDesc//tei:correspAction[@type='received']/(tei:persName|tei:orgName|tei:name)[normalize-space(.)]">
         <recipients display="true">
            <xsl:apply-templates
               select="$correspDesc//tei:correspAction[@type='received']/(tei:persName|tei:orgName|tei:name)[normalize-space(.)]"
            />
         </recipients>

      </xsl:if>

      <!-- placeName and date for the sender are both picked up in the event coding in get-doc-events -->
   </xsl:template>

   <xsl:function name="lambda:write-tei-services-link" as="xsd:string*">
      <xsl:param name="node" as="item()"/>
      <xsl:param name="type" as="xsd:string"/>

      <xsl:variable name="fileID" select="lambda:construct-output-filename-path($node)"/>

      <xsl:choose>
         <xsl:when
            test="namespace-uri($node) = 'http://www.tei-c.org/ns/1.0' and $type = ('', 'transcription')">
            <xsl:value-of select="concat('/v1/transcription/tei/diplomatic/internal/',$fileID)"/>
         </xsl:when>
         <xsl:when
            test="namespace-uri($node) = 'http://www.tei-c.org/ns/1.0' and $type = ('translation')">
            <!-- Can it be /EN/tei/...? The tei/... is part of fileID -->
            <xsl:value-of
               select="concat('/v1/translation/tei/',lambda:get-translation-lang-code($node),'/',$fileID)"
            />
         </xsl:when>
         <xsl:when
            test="namespace-uri($node) = 'http://www.tei-c.org/ns/1.0' and $type = ('metadata')">
            <xsl:value-of
               select="concat('/v1/metadata/tei/',replace(tokenize($fileID,'/')[last()],'\.xml$',''),'/')"
            />
         </xsl:when>
         <xsl:otherwise/>
      </xsl:choose>
   </xsl:function>

   <xsl:function name="lambda:construct-output-filename-path" as="xsd:string">
      <xsl:param name="node" as="item()*"/>

      <xsl:variable name="surfaceID" select="key('surfaceIDs',$node/@facs, root($node))/@xml:id"
         as="xsd:string*"/>

      <xsl:variable name="filename-root"
         select="replace(normalize-space(tokenize(document-uri(root($node)), '/')[last()]),'\..*$','')"
         as="xsd:string"/>
      <xsl:variable name="path-to-filename"
         select="string-join(tokenize(replace(document-uri(root($node)),'^file:',''), '/')[position() lt last()],'/')"
         as="xsd:string"/>
      <xsl:variable name="is_unpaginated"
         select="exists($node[ancestor::tei:div[tokenize(@decls,'\s+') = '#unpaginated']])"
         as="xsd:boolean"/>

      <xsl:variable name="output-filename" as="xsd:string">

         <xsl:variable name="surfaceID_final" as="xsd:string*">
            <xsl:choose>
               <xsl:when test="$is_unpaginated">
                  <xsl:sequence
                     select="distinct-values(($node//ancestor::tei:div[tokenize(@decls,'\s+') = '#unpaginated']//tei:pb[replace(@facs,'^#','')= root($node)//tei:surface/@xml:id]/replace(@facs,'^#',''))[position() = (1, last())])"
                  />
               </xsl:when>
               <xsl:otherwise>
                  <xsl:sequence select="$surfaceID"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>

         <xsl:value-of select="string-join(($filename-root, $surfaceID_final)[.!=''],'/')"/>

      </xsl:variable>

      <!--<xsl:variable name="hierarchy" as="xsd:string">
         <xsl:variable name="tmp" as="xsd:string*">
            <xsl:variable name="clean_data_dir" select="doc('../../../conf/textIndexer.conf')//*:index[@*:name='index-cudl']//*:src/@*:path" as="xsd:string"/>
            <xsl:choose>
               <xsl:when test="$clean_data_dir != ''">
                  <xsl:value-of select="replace($path-to-filename,concat('^',$clean_data_dir),'')"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:value-of select="$path-to-filename"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>
         <xsl:value-of select="replace($tmp,'^/','')"/>
      </xsl:variable>
      
      <xsl:value-of select="concat(replace($hierarchy,'tei/',''),'/',$output-filename)"/>-->
      <xsl:value-of select="$output-filename"/>

   </xsl:function>

   <xsl:function name="lambda:get-translation-lang-code" as="xsd:string*">
      <xsl:param name="node"/>
      <xsl:sequence
         select="('EN',$node/ancestor::tei:div[@type='translation']/upper-case(@xml:lang))[.!=''][1]"
      />
   </xsl:function>

   <xsl:function name="lambda:has-valid-context" as="xsd:boolean">
      <xsl:param name="context"/>

      <!-- Presume that if @next contains content that it's accurate to increase excecution speed of script -->
      <xsl:sequence
         select="exists($context[normalize-space(@next)!=''])
         or exists($context[normalize-space(@prev)!=''])
         or exists($context[not(ancestor::tei:add | ancestor::tei:note)
         and
         not(preceding::tei:addSpan/replace(normalize-space(@spanTo), '#', '')
         = following::tei:anchor/@xml:id)])"
      />
   </xsl:function>

   <xsl:function name="lambda:page-has-content" as="xsd:boolean">
      <xsl:param name="node" as="item()"/>

      <xsl:sequence select="exists($node[normalize-space(.) or self::tei:graphic or self::tei:gap])"
      />
   </xsl:function>

    <xsl:template match="tei:surface" mode="count">
        <xsl:number count="//tei:facsimile/tei:surface" level="any"/>
    </xsl:template>


   <!--SIMILARITY STUFF - DITCH?-->

   <!-- Currently transcriptions are not indexed as XTF runs out of memory
         while indexing. They'll get duplicated quite a bit for nested
         documents... -->
   <xsl:variable name="sim:INDEX_TRANSCRIPTIONS" select="false()"/>
   
   <!-- If false, similarity-* fields will be marked xtf:store="false"
         It appears that moreLike queries don't work unless the similarity
         fields are stored as well as indexed, which is annoying because they
         never need to be fetched... -->
   <xsl:variable name="sim:STORE_SIMILARITY" select="true()"/>
   
   <!-- Index transcriptionPage elements by dmdID -->
   <xsl:key
      name="sim:transcription-pages-by-dmd"
      match="/xtf-converted/xtf:meta/transcriptionPage"
      use="dmdID"/>
   
   <!-- Index descriptive metadat sections by their ID -->
   <xsl:key
      name="sim:dmd-sections"
      match="/xtf-converted/xtf:meta/descriptiveMetadata/part"
      use="ID"/>
   
   <!-- Keep everything as-is unless we explicitly change anything -->
   <xsl:template match="@*|node()" mode="similarity">
      <xsl:copy>
         <xsl:apply-templates select="@*|node()" mode="similarity"/>
      </xsl:copy>
   </xsl:template>
   
   <!-- Add our new similarity subdocuments to the meta block alongside the
         other data. -->
   <xsl:template match="xtf:meta" mode="similarity">
      <xsl:call-template name="sim:copy-with-extra-content">
         <xsl:with-param name="extra-content">
            
            <!-- Introduce a new set of subdocuments to index similarity
                     info. We'll need to exclude these from the regular search
                     results... -->
            <xsl:apply-templates select=".//logicalStructure" mode="similarity-subdoc"/>
            
         </xsl:with-param>
      </xsl:call-template>
   </xsl:template>
   
   <!-- Each logical structure node is indexed for similarity.
         When querying for similarity, the index of the most specific structure
         (narowest & deepest) node for a given page is used to obtain the
         similarity ID for a page.
          -->
   <xsl:template match="logicalStructure" mode="similarity-subdoc">
      <!-- The 0-based position of the logical structure item is the
             similarity ID. -->
      <xsl:variable name="similarityID" select="position() - 1"/>
      <!-- $fileID is defined in preFilterCommon.xsl -->
      <xsl:variable name="qualifiedSimID" select="concat($fileID, '/', $similarityID)"/>
      
      <similarity-match-candidate xtf:subDocument="similarity-{$similarityID}">
         
         <!-- The identifier field is used by XTF to identify the starting
                 point for similarity (moreLike) queries. -->
         <identifier xtf:meta="true" xtf:tokenize="no">
            <xsl:value-of select="$qualifiedSimID"/>
         </identifier>
         
         <itemId xtf:meta="true" xtf:index="true" xtf:tokenize="no" xtf:store="true">
            <xsl:value-of select="$fileID"/>
         </itemId>
         
         <structureNodeId xtf:meta="true" xtf:index="false" xtf:store="true">
            <xsl:value-of select="$similarityID"/>
         </structureNodeId>
         
         <!-- Generate similarity fields for each dmd section associated with
                 this logical structure. e.g. this structure node and its
                 ancestors. -->
         <xsl:for-each select="reverse(ancestor-or-self::logicalStructure)">
            <!-- TODO: Could modify the xtf:wordBoost value for similarity
                     fields from different depths in the logical structure tree.
                     e.g. boost deeper (more specific) fields or unboost less
                     specific fields (closer to the top). -->
            <xsl:apply-templates
               select="key('sim:dmd-sections', descriptiveMetadataID)"
               mode="similarity-subdoc"/>
         </xsl:for-each>
         
      </similarity-match-candidate>
   </xsl:template>
   
   <!-- Add similarity fields to descriptive metadata.  -->
   <xsl:template match="descriptiveMetadata/part" mode="similarity-subdoc">
      
      <similarity-fields for="descriptive-metadata {ID}">
         
         <xsl:apply-templates select="title" mode="similarity-field"/>
         
         <xsl:apply-templates
            select="authors/name|recipients/name|associated/name"
            mode="similarity-field"/>
         
         <xsl:apply-templates select="abstract|content" mode="similarity-field"/>
         
         <xsl:if test="$sim:INDEX_TRANSCRIPTIONS">
            <xsl:apply-templates
               select="key('sim:transcription-pages-by-dmd', ID)"
               mode="similarity-field"/>
         </xsl:if>
         
         <xsl:apply-templates
            select="subjects/subject" mode="similarity-field"/>
         
         <xsl:apply-templates
            select="creations/event/places/place"
            mode="similarity-field"/>
         
      </similarity-fields>
   </xsl:template>
   
   <!-- These are the possible similarity fields which can be created: -->
   
   <!-- similarity-titile contains the title of the subdocument -->
   <xsl:template match="title[normalize-space()]" mode="similarity-field">
      <similarity-title xtf:meta="true" xtf:index="true" xtf:store="{$sim:STORE_SIMILARITY}">
         <xsl:value-of select="normalize-space()"/>
      </similarity-title>
   </xsl:template>
   
   <!-- similarity-name contains any names of people associated with the
         subDocument. -->
   <xsl:template match="name[@displayForm]" mode="similarity-field">
      <similarity-name xtf:meta="true" xtf:index="true" xtf:store="{$sim:STORE_SIMILARITY}">
         <!-- FIXME: strip date ranges from names -->
         <xsl:value-of select="@displayForm"/>
      </similarity-name>
   </xsl:template>
   
   <!-- similarity-text contains any available full-text fields -->
   <xsl:template match="abstract|content" mode="similarity-field">
      <similarity-text xtf:meta="true" xtf:index="true" xtf:store="{$sim:STORE_SIMILARITY}">
         <xsl:value-of select="normalize-space()"/>
      </similarity-text>
   </xsl:template>
   
   <xsl:template match="transcriptionPage[normalize-space(transcriptionText)]"
      mode="similarity-field">
      <similarity-text xtf:meta="true" xtf:index="true" xtf:store="{$sim:STORE_SIMILARITY}">
         <xsl:value-of select="normalize-space(transcriptionText)"/>
      </similarity-text>
   </xsl:template>
   
   <!-- similarity-subject contains a subject/topic associated with the
         item -->
   <xsl:template match="subject[@displayForm]" mode="similarity-field">
      <similarity-subject xtf:meta="true" xtf:index="true" xtf:store="{$sim:STORE_SIMILARITY}">
         <xsl:value-of select="@displayForm"/>
      </similarity-subject>
   </xsl:template>
   
   <!-- similarity-place contains the name of a location associated with the
         item -->
   <xsl:template match="place[@displayForm]" mode="similarity-field">
      <similarity-place xtf:meta="true" xtf:index="true" xtf:store="{$sim:STORE_SIMILARITY}">
         <xsl:value-of select="@displayForm"/>
      </similarity-place>
   </xsl:template>
   
   <!-- Utilities -->
   <xsl:template name="sim:copy-with-extra-content">
      <xsl:param name="extra-content"/>
      
      <xsl:copy>
         <!-- Copy attributes unchanged -->
         <xsl:apply-templates select="@*" mode="similarity"/>
         
         <!-- Insert the extra content before the existing elements. -->
         <xsl:copy-of select="$extra-content"/>
         
         <!-- Copy all the other nodes -->
         <xsl:apply-templates select="node()" mode="similarity"/>
      </xsl:copy>
   </xsl:template>




</xsl:stylesheet>

