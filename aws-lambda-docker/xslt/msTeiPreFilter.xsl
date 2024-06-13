<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.1"
   xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:cudl="http://cudl.lib.cam.ac.uk/xtf/"
   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
   xmlns:json="http://www.w3.org/2005/xpath-functions"
   xmlns="http://www.w3.org/1999/xhtml"
   exclude-result-prefixes="#all"
   xmlns:lambda="http://cudl.lib.cam.ac.uk/lambda/">

   <xsl:output method="xml" indent="no" encoding="UTF-8"/>
   <xsl:strip-space elements="*"/>

   <xsl:include href="common-util.xsl"/>


   <xsl:param name="dest_dir" as="xsd:string*" required="yes" /><!-- Point to the output directory -->
   <xsl:param name="data_dir" as="xsd:string*" required="no" />
   <xsl:param name="SEARCH_HOST" as="xsd:string" required="no"/>
   <xsl:param name="SEARCH_PORT" as="xsd:string" required="no"/>
   <xsl:param name="SEARCH_COLLECTION_PATH" as="xsd:string" required="no"/>

   <xsl:param name="path_to_buildfile" as="xsd:string*" required="no"/>

   <xsl:variable name="clean_dest_dir" select="cudl:path-to-directory($dest_dir, $path_to_buildfile)"/>
   <xsl:variable name="clean_data_dir" select="cudl:path-to-directory($data_dir, $path_to_buildfile)"/>

   <!--<xsl:variable name="pathToConf" select="'../../../conf/local.conf'"/>
   <xsl:variable name="conf_file" select="document($pathToConf)"/>
   <xsl:variable name="servicesURI" select="$conf_file//services/@path"/>
   <xsl:variable name="apiKey" select="$conf_file)//services/@key"/>-->

   <xsl:variable name="fileID" select="substring-before(tokenize(document-uri(/), '/')[last()], '.xml')"/>

   <xsl:key name="surfaceIDs" match="//tei:surface" use="(@xml:id, concat('#',@xml:id))"/>
   <xsl:key name="surfaceNs" match="//tei:surface" use="normalize-space(@n)"/>
   <xsl:key name="pbNs" match="//tei:pb[normalize-space(@n)]" use="@n"/>

   <xsl:template match="/">
      <xsl:call-template name="get-meta"/>
   </xsl:template>

   <xsl:template match="@*|node()" mode="meta">
      <xsl:copy>
         <xsl:apply-templates select="@*|node()" mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:key name="collection_items" match="/*:map/*:map[@key='response']/*:array[@key='docs']/*:map/*:array[@key='items._id']/*:string" use="string-join(tokenize(tokenize(., '/')[last()], '\.')[position() lt last()], '.')"/>

   <xsl:template name="get-collection">
      <xsl:if test="$SEARCH_HOST !=''">
         <xsl:variable name="search_addr" select="string-join(($SEARCH_HOST, $SEARCH_PORT)[normalize-space(.)], ':')"/>
         
         <xsl:variable name="collection-query">
            <xsl:try>
               <xsl:variable name="request_uri" select="concat('http://', $search_addr,'/', $SEARCH_COLLECTION_PATH,'?q=items._id:%22%2F', $fileID, '.json%22')"/>
               <xsl:message select="concat('Submitting request to: ', $request_uri)"/>
               <xsl:copy-of select="json-to-xml(unparsed-text($request_uri))"/>
               <xsl:catch>
                  <xsl:message>ERROR: Search API not responding</xsl:message>
               </xsl:catch>
            </xsl:try>
         </xsl:variable>


         <xsl:variable name="item_matches" select="key('collection_items', $fileID, $collection-query)"/>

         <xsl:variable name="collection_names" select="$item_matches/parent::*/parent::*/*:array[@key='name.short']" as="xsd:string*"/>

         <xsl:if test="$collection-query[*/*:map[@key='responseHeader']]">
            <array key="collection" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:for-each select="$collection_names">
                  <string xmlns="http://www.w3.org/2005/xpath-functions">
                     <xsl:value-of select="."/>
                  </string>
               </xsl:for-each>
            </array>

            <xsl:for-each select="$item_matches">
               <xsl:variable name="parent_obj" select="./parent::*/parent::*"/>
               <xsl:variable name="collection_name" select="$parent_obj/*:array[@key='name.short'][1]"/>
               <string key="{$collection_name}_sort" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:variable name="pos">
                     <xsl:apply-templates select="." mode="count"/>
                  </xsl:variable>
                  <xsl:value-of select="format-number(xsd:int($pos),'000000')"/>
               </string>
            </xsl:for-each>
         </xsl:if>
      </xsl:if>
   </xsl:template>

   <xsl:template match="*:string" mode="count">
      <xsl:number count="/*:map/*:map[@key='response']/*:array[@key='docs']/*:map/*:array[@key='items._id']/*:string" level="single"/>
   </xsl:template>

   <xsl:template name="get-meta">
      <xsl:variable name="meta">
         <array key="descriptiveMetadata" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:apply-templates select="tei:TEI/tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:msDesc"/>
         </array>

         <!--top level fields concerning the document as a whole-->
         <string key="fileID" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="$fileID"/>
         </string>
         <xsl:call-template name="get-collection"/>
         <xsl:call-template name="get-numberOfPages"/>
         <xsl:call-template name="get-embeddable"/>
         <xsl:call-template name="get-text-direction"/>
         <xsl:call-template name="get-transcription-flags"/>
         <xsl:call-template name="get-sourceData"/>

         <!--is this a complete representation of the item-->
         <!--QUERY - deprecate?--><!-- TODO IS IT USED -->
         <xsl:if test=".//tei:note[@type='completeness']">
            <xsl:apply-templates select=".//tei:note[@type='completeness']"/>
         </xsl:if>

         <!--structural information about the item-->
         <xsl:call-template name="make-pages"/>
         <xsl:call-template name="make-logical-structure"/>

         <!--a special case where items in a list with a locus are indexed against that locus-->
         <!--QUERY - can we index straight from the content?-->
         <xsl:if test="//tei:list/tei:item[tei:locus]">
            <xsl:call-template name="make-list-item-pages"/>
         </xsl:if>

      </xsl:variable>

      <!-- Add doc kind and sort fields to the data, and output the result. -->
      <xsl:variable name="result" as="item()*">
         <map xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:apply-templates select="$meta/*" mode="meta"/>
         </map>
      </xsl:variable>

      <xsl:variable name="t" as="item()*">
         <xsl:apply-templates select="$result" mode="updateSeq"/>
      </xsl:variable>
      <xsl:copy-of select="$t"/>
   </xsl:template>

   <xsl:template name="get-numberOfPages">
      <number key="numberOfPages" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:choose>
            <xsl:when test="//tei:facsimile/tei:surface">
               <xsl:value-of select="count(//tei:facsimile/tei:surface)"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:text>1</xsl:text>
            </xsl:otherwise>
         </xsl:choose>
      </number>
   </xsl:template>

   <xsl:template name="get-embeddable">
      <xsl:variable name="images" select="//tei:facsimile/tei:surface[1]/tei:graphic[1][normalize-space(@url)]"/>
      <boolean key="embeddable" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:value-of select="exists($images)"/>
      </boolean>
   </xsl:template>

   <xsl:template name="get-text-direction">
      <xsl:variable name="languageCode">
         <xsl:choose>
            <xsl:when test="//tei:sourceDesc/tei:msDesc/tei:msContents/tei:textLang/@mainLang">
               <xsl:value-of select="//tei:sourceDesc/tei:msDesc/tei:msContents/tei:textLang/@mainLang"/>
            </xsl:when>
            <xsl:when test="count(//tei:sourceDesc/tei:msDesc/tei:msContents/tei:msItem) = 1 and //tei:sourceDesc/tei:msDesc/tei:msContents/tei:msItem[1]/tei:textLang/@mainLang">
               <xsl:value-of select="//tei:sourceDesc/tei:msDesc/tei:msContents/tei:msItem[1]/tei:textLang/@mainLang"/>
            </xsl:when>
            <xsl:when test="(/tei:*/tei:teiHeader//tei:langUsage/tei:language/@ident)[normalize-space(.)][1]">
               <xsl:value-of select="(/tei:*/tei:teiHeader//tei:langUsage/tei:language/@ident)[normalize-space(.)][1]" />
            </xsl:when>
            <xsl:otherwise>
               <xsl:text>none</xsl:text>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <string key="textDirection" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:value-of select="cudl:get-language-direction($languageCode)"/>
      </string>
   </xsl:template>

   <xsl:template name="get-sourceData">
      <string key="sourceData" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:value-of select="lambda:write-tei-services-link(root(.)/*,'metadata')"/>
      </string>
   </xsl:template>

   <xsl:template name="get-transcription-flags">
      <xsl:choose>
         <xsl:when test="//tei:surface/tei:media[contains(@mimeType,'transcription')]">
            <boolean key="useTranscriptions" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:text>true</xsl:text>
            </boolean>
            <xsl:if test="//tei:surface/tei:media[@mimeType='transcription_diplomatic']">
               <boolean key="useDiplomaticTranscriptions" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:text>true</xsl:text>
               </boolean>
            </xsl:if>
            <xsl:if test="//tei:surface/tei:media[@mimeType='transcription_normalised']">
               <boolean key="useNormalisedTranscriptions" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:text>true</xsl:text>
               </boolean>
            </xsl:if>
         </xsl:when>
         <xsl:when test="//tei:text/tei:body/tei:div[not(@type)]/*[not(self::tei:pb)]">
            <boolean key="useTranscriptions" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:text>true</xsl:text>
            </boolean>
            <boolean key="useDiplomaticTranscriptions" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:text>true</xsl:text>
            </boolean>
         </xsl:when>
      </xsl:choose>

      <xsl:if test="//tei:surface/tei:media[@mimeType='translation']">
         <boolean key="useTranslations" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:text>true</xsl:text>
         </boolean>
      </xsl:if>

      <xsl:if test="//tei:text/tei:body/tei:div[@type='translation']/*[not(self::tei:pb)]">
         <boolean key="useTranslations" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:text>true</xsl:text>
         </boolean>
      </xsl:if>
   </xsl:template>


   <xsl:template match="tei:msDesc">
      <map xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:call-template name="get-doc-thumbnail"/>
         <xsl:call-template name="get-doc-image-rights"/>
         <xsl:call-template name="get-doc-metadata-rights"/>
         <xsl:call-template name="get-doc-transcription-rights"/>
         <xsl:call-template name="get-doc-pdf-rights"/>
         <xsl:call-template name="get-doc-watermark-statement"/>
         <xsl:call-template name="get-doc-authority"/>
         <xsl:call-template name="get-doc-funding"/>
         <xsl:call-template name="get-subjects">
            <xsl:with-param name="level" select="'doc'"/>
         </xsl:call-template>
         <xsl:call-template name="get-places">
            <xsl:with-param name="level" select="'doc'"/>
         </xsl:call-template>
         <xsl:call-template name="get-doc-metadata"/>
         <xsl:call-template name="get-dmdID">
            <xsl:with-param name="level" select="'doc'"/>
         </xsl:call-template>
         <xsl:call-template name="get-calendarnum"/>

         <xsl:choose>
            <xsl:when test="count(tei:msContents/tei:msItem) = 1">
               <xsl:call-template name="get-abstract">
                     <xsl:with-param name="level" select="'doc'"/>
                  </xsl:call-template>
               <xsl:call-template name="get-doc-and-item-names"/>
               <xsl:call-template name="get-doc-events"/>
               <xsl:call-template name="get-doc-physloc"/>
               <xsl:call-template name="get-doc-alt-ids"/>
               <xsl:call-template name="get-doc-physdesc"/>
               <xsl:call-template name="get-doc-history"/>
               <xsl:call-template name="get-biblio">
                     <xsl:with-param name="level" select="'doc-and-item'"/>
                  </xsl:call-template>

               <xsl:for-each select="tei:msContents/tei:msItem[1]">
                  <xsl:call-template name="get-item-title">
                     <xsl:with-param name="display" select="false()"/>
                  </xsl:call-template>
                  <xsl:call-template name="get-alt-titles">
                     <xsl:with-param name="level" select="'item'"/>
                  </xsl:call-template>
                  <xsl:call-template name="get-desc-titles">
                     <xsl:with-param name="level" select="'item'"/>
                  </xsl:call-template>
                  <xsl:call-template name="get-uniform-title">
                     <xsl:with-param name="level" select="'item'"/>
                  </xsl:call-template>
                  <xsl:call-template name="get-languages">
                     <xsl:with-param name="level" select="'item'"/>
                  </xsl:call-template>
                  <xsl:call-template name="get-item-excerpts"/>
                  <xsl:call-template name="get-item-notes"/>
                  <xsl:call-template name="get-item-filiation"/>
               </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
               <xsl:call-template name="get-doc-title"/>
               <xsl:call-template name="get-alt-titles">
                     <xsl:with-param name="level" select="'doc'"/>
                  </xsl:call-template>
               <xsl:call-template name="get-desc-titles">
                     <xsl:with-param name="level" select="'doc'"/>
                  </xsl:call-template>
               <xsl:call-template name="get-uniform-title">
                     <xsl:with-param name="level" select="'doc'"/>
                  </xsl:call-template>
               <xsl:call-template name="get-abstract">
                     <xsl:with-param name="level" select="'doc'"/>
                  </xsl:call-template>
               <xsl:call-template name="get-languages">
                     <xsl:with-param name="level" select="'doc'"/>
                  </xsl:call-template>
               <xsl:call-template name="get-doc-names"/>
               <xsl:call-template name="get-doc-events"/>
               <xsl:call-template name="get-doc-physloc"/>
               <xsl:call-template name="get-doc-alt-ids"/>
               <xsl:call-template name="get-doc-physdesc"/>
               <xsl:call-template name="get-doc-history"/>
               <xsl:call-template name="get-biblio">
                     <xsl:with-param name="level" select="'doc'"/>
                  </xsl:call-template>
            </xsl:otherwise>
         </xsl:choose>
      </map>

      <!--process the rest of the msItems in this part-->
      <xsl:choose>
         <xsl:when test="count(tei:msContents/tei:msItem) = 1">
            <xsl:apply-templates select="tei:msContents/tei:msItem/tei:msItem"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates select="tei:msContents/tei:msItem"/>
         </xsl:otherwise>
      </xsl:choose>

      <!--and then process the msParts-->
      <xsl:apply-templates select="tei:msPart"/>
   </xsl:template>

   <xsl:template match="tei:msPart">
      <map xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:call-template name="get-dmdID">
                     <xsl:with-param name="level" select="'msPart'"/>
                  </xsl:call-template>
         <xsl:call-template name="get-calendarnum"/>

         <xsl:choose>
            <!-- if there is just one top-level msItem, merge into the document level -->
            <xsl:when test="count(tei:msContents/tei:msItem) = 1">
               <xsl:call-template name="get-abstract">
                  <xsl:with-param name="level" select="'part'"/>
               </xsl:call-template>
               <xsl:call-template name="get-doc-and-item-names"/>
               <xsl:call-template name="get-doc-events"/>
               <xsl:call-template name="get-doc-physloc"/>
               <xsl:call-template name="get-doc-alt-ids"/>
               <xsl:call-template name="get-doc-physdesc"/>
               <xsl:call-template name="get-doc-history"/>
               <xsl:call-template name="get-biblio">
                  <xsl:with-param name="level" select="'doc-and-item'"/>
               </xsl:call-template>
               <xsl:call-template name="get-subjects">
                  <xsl:with-param name="level" select="'part'"/>
               </xsl:call-template>
               <xsl:call-template name="get-places">
                  <xsl:with-param name="level" select="'part'"/>
               </xsl:call-template>

               <xsl:for-each select="tei:msContents/tei:msItem[1]">
                  <xsl:call-template name="get-item-title">
                     <xsl:with-param name="display" select="true()"/>
                  </xsl:call-template>
                  <xsl:call-template name="get-alt-titles">
                     <xsl:with-param name="level" select="'item'"/>
                  </xsl:call-template>
                  <xsl:call-template name="get-desc-titles">
                     <xsl:with-param name="level" select="'item'"/>
                  </xsl:call-template>
                  <xsl:call-template name="get-uniform-title">
                     <xsl:with-param name="level" select="'item'"/>
                  </xsl:call-template>
                  <xsl:call-template name="get-languages">
                     <xsl:with-param name="level" select="'item'"/>
                  </xsl:call-template>
                  <xsl:call-template name="get-item-excerpts"/>
                  <xsl:call-template name="get-item-notes"/>
                  <xsl:call-template name="get-item-filiation"/>
               </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
               <!-- Sequence of top-level msItems, so need to introduce additional top-level to represent item as a whole-->
               <xsl:call-template name="get-doc-title"/>
               <xsl:call-template name="get-alt-titles">
                  <xsl:with-param name="level" select="'doc'"/>
               </xsl:call-template>
               <xsl:call-template name="get-desc-titles">
                  <xsl:with-param name="level" select="'doc'"/>
               </xsl:call-template>
               <xsl:call-template name="get-uniform-title">
                  <xsl:with-param name="level" select="'doc'"/>
               </xsl:call-template>
               <xsl:call-template name="get-abstract">
                  <xsl:with-param name="level" select="'part'"/>
               </xsl:call-template>
               <xsl:call-template name="get-languages">
                  <xsl:with-param name="level" select="'doc'"/>
               </xsl:call-template>
               <xsl:call-template name="get-doc-names"/>
               <xsl:call-template name="get-doc-events"/>
               <xsl:call-template name="get-doc-alt-ids"/>
               <xsl:call-template name="get-doc-physdesc"/>
               <xsl:call-template name="get-doc-history"/>
               <xsl:call-template name="get-biblio">
                  <xsl:with-param name="level" select="'doc'"/>
               </xsl:call-template>
               <xsl:call-template name="get-subjects">
                  <xsl:with-param name="level" select="'part'"/>
               </xsl:call-template>
               <xsl:call-template name="get-places">
                  <xsl:with-param name="level" select="'part'"/>
               </xsl:call-template>
            </xsl:otherwise>
         </xsl:choose>
      </map>
      <!--process the rest of the msItems in this part-->
      <xsl:choose>
         <xsl:when test="count(tei:msContents/tei:msItem) = 1">
            <xsl:apply-templates select="tei:msContents/tei:msItem/tei:msItem"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates select="tei:msContents/tei:msItem"/>
         </xsl:otherwise>
      </xsl:choose>

      <!--process the msParts in this part-->
      <xsl:apply-templates select="tei:msPart"/>
   </xsl:template>

   <!--each msItem is also a part-->
   <xsl:template match="tei:msItem">
      <map xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:call-template name="get-dmdID">
            <xsl:with-param name="level" select="'item'"/>
         </xsl:call-template>
         <xsl:call-template name="get-calendarnum"/>
         <xsl:call-template name="get-item-title">
            <xsl:with-param name="display" select="true()"/>
         </xsl:call-template>
         <xsl:call-template name="get-alt-titles">
            <xsl:with-param name="level" select="'item'"/>
         </xsl:call-template>
         <xsl:call-template name="get-desc-titles">
            <xsl:with-param name="level" select="'item'"/>
         </xsl:call-template>
         <xsl:call-template name="get-uniform-title">
            <xsl:with-param name="level" select="'item'"/>
         </xsl:call-template>
         <xsl:call-template name="get-item-names"/>
         <xsl:call-template name="get-languages">
            <xsl:with-param name="level" select="'item'"/>
         </xsl:call-template>
         <xsl:call-template name="get-item-excerpts"/>
         <xsl:call-template name="get-item-notes"/>
         <xsl:call-template name="get-item-filiation"/>
         <xsl:call-template name="get-biblio">
            <xsl:with-param name="level" select="'item'"/>
         </xsl:call-template>
      </map>
         <!-- Any child items of this item -->
         <xsl:apply-templates select="tei:msContents/tei:msItem|tei:msItem"/>
   </xsl:template>

   <xsl:template name="get-dmdID">
      <xsl:param name="level" select="'doc'"/>

      <xsl:variable name="id">
         <xsl:choose>
            <xsl:when test="$level eq 'item'">
               <xsl:variable name="n-tree" select="sum((count(ancestor-or-self::*[self::tei:msItem]), count(preceding::*[self::tei:msItem])))" />
               <xsl:value-of select="concat('ITEM-', normalize-space(string($n-tree)))"/>
            </xsl:when>
            <xsl:when test="$level eq 'msPart'">
               <xsl:variable name="n-tree" select="sum((count(ancestor-or-self::*[self::tei:msPart]), count(preceding::*[self::tei:msPart])))" />
               <xsl:value-of select="concat('PART-', normalize-space(string($n-tree)))"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:text>DOCUMENT</xsl:text>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <string key="ID" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:value-of select="$id"/>
      </string>
   </xsl:template>

   <xsl:template name="get-doc-title">
      <xsl:call-template name="write-container-lg">
         <xsl:with-param name="type" select="'title'"/>
         <xsl:with-param name="display" select="name() ne 'msDesc'"/>
         <xsl:with-param name="displayForm">
            <xsl:variable name="t">
               <xsl:choose>
                  <xsl:when test="tei:head">
                     <xsl:value-of select="normalize-space(tei:head)"/>
                  </xsl:when>
                  <xsl:when test="tei:msIdentifier/tei:msName">
                     <xsl:value-of select="normalize-space(tei:msIdentifier/tei:msName)"/>
                  </xsl:when>
                  <xsl:when test="tei:msContents/tei:summary//tei:title[not(@type)]">
                     <xsl:for-each-group select="tei:msContents/tei:summary//tei:title[not(@type)]" group-by="normalize-space(.)">
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:if test="not(position()=last())">
                           <xsl:text>, </xsl:text>
                        </xsl:if>
                     </xsl:for-each-group>
                  </xsl:when>
                  <xsl:when test="tei:msIdentifier/tei:idno">
                     <xsl:for-each-group select="tei:msIdentifier/tei:idno" group-by="normalize-space(.)">
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
            <xsl:value-of select="normalize-space($t)"/>
         </xsl:with-param>
         <xsl:with-param name="label" select="'Title'"/>
         <xsl:with-param name="seq" select="1"/>
      </xsl:call-template>
   </xsl:template>

   <!--item titles-->
   <xsl:template name="get-item-title">
      <xsl:param name="display"/>

      <map key="title" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:copy-of select="cudl:display($display)"/>
         <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:choose>
               <xsl:when test="normalize-space(tei:title[not(@type)][1])">
                  <xsl:value-of select="normalize-space(tei:title[not(@type)][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(tei:title[@type='general'][1])">
                  <xsl:value-of select="normalize-space(tei:title[@type='general'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(tei:title[@type='desc'][1])">
                  <xsl:value-of select="normalize-space(tei:title[@type='desc'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(tei:title[@type='standard'][1])">
                  <xsl:value-of select="normalize-space(tei:title[@type='standard'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(tei:title[@type='supplied'][1])">
                  <xsl:value-of select="normalize-space(tei:title[@type='supplied'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(tei:rubric[1])">
                  <xsl:variable name="rubric_title">
                     <xsl:apply-templates select="tei:rubric[1]" mode="title"/>
                  </xsl:variable>
                  <xsl:value-of select="normalize-space($rubric_title)"/>
               </xsl:when>
               <xsl:when test="normalize-space(tei:incipit[1])">
                  <xsl:variable name="incipit_title">
                     <xsl:apply-templates select="tei:incipit[1]" mode="title"/>
                  </xsl:variable>
                  <xsl:value-of select="normalize-space($incipit_title)"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:text>Untitled Item</xsl:text>
               </xsl:otherwise>
            </xsl:choose>
         </string>
         <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:text>Title</xsl:text>
         </string>
         <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="1"/>
         </number>
      </map>
   </xsl:template>

   <xsl:template name="get-alt-titles">
      <!-- level may be either 'doc' or 'item' -->
      <xsl:param name="level" select="'doc'"/>

      <xsl:variable name="target" as="item()*">
         <xsl:choose>
            <xsl:when test="$level ='doc'">
               <xsl:copy-of select="tei:msContents/tei:summary/tei:title[@type='alt']"/>
            </xsl:when>
            <xsl:otherwise>
               <!-- item level -->
               <xsl:copy-of select="tei:title[@type='alt']"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:if test="$target">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'alternativeTitles'"/>
            <xsl:with-param name="displayFormIter" select="if ($level eq 'doc') then $target[normalize-space(.)] else $target"/>
            <xsl:with-param name="label" select="'Alternative Title(s)'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="seq2" select="2"/>
         </xsl:call-template>
      </xsl:if>
   </xsl:template>

   <xsl:template name="get-desc-titles">
      <!-- level may be either 'doc' or 'item' -->
      <xsl:param name="level" select="'doc'"/>

      <xsl:variable name="target" as="item()*">
         <xsl:choose>
            <xsl:when test="$level = 'doc'">
               <xsl:if test="tei:msContents/tei:summary/tei:title[@type='desc']">
                  <xsl:copy-of select="tei:msContents/tei:summary/tei:title[@type='desc'][normalize-space(.)]"/>
               </xsl:if>
            </xsl:when>
            <xsl:otherwise>
               <xsl:copy-of select="tei:title[@type='desc']"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:if test="$target">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'descriptiveTitles'"/>
            <xsl:with-param name="displayFormIter" select="if ($level eq 'doc') then $target[normalize-space(.)] else $target"/>
            <xsl:with-param name="label" select="'Descriptive Title(s)'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="seq2" select="2"/>
         </xsl:call-template>
      </xsl:if>
   </xsl:template>

   <xsl:template name="get-uniform-title">
      <!-- level may be either 'doc' or 'item' -->
      <xsl:param name="level" select="'doc'"/>

      <!-- Cumbersome code needed at present since uniform title, which is always a context-level singleton,
           has differing data structures. Doc-level has a values array; item level only provides a string.
           Revisit these structures and update Viewer to support consistent structure?
      -->
      <xsl:choose>
         <xsl:when test="$level = 'doc'">
            <xsl:variable name="target" select="tei:msContents/tei:summary/tei:title[@type='uniform'][1]"/>
            <xsl:if test="normalize-space($target)">
               <xsl:call-template name="write-container-lg">
                  <xsl:with-param name="type" select="'uniformTitle'"/>
                  <xsl:with-param name="displayFormIter" select="$target"/>
                  <xsl:with-param name="label" select="'Uniform Title'"/>
                  <xsl:with-param name="seq" select="1"/>
               </xsl:call-template>
            </xsl:if>
         </xsl:when>
         <xsl:otherwise>
            <xsl:variable name="target" select="normalize-space(tei:title[@type='uniform'][1])"/>
            <xsl:if test="$target">
               <xsl:call-template name="write-container-lg">
                  <xsl:with-param name="type" select="'uniformTitle'"/>
                  <xsl:with-param name="displayForm" select="$target"/>
                  <xsl:with-param name="label" select="'Uniform Title'"/>
                  <xsl:with-param name="seq" select="1"/>
               </xsl:call-template>
            </xsl:if>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template name="get-abstract">
      <!-- level may be either 'doc' or 'part' -->
      <xsl:param name="level" select="'doc'"/>

      <xsl:if test="(ancestor-or-self::tei:teiHeader[1]//tei:profileDesc/tei:abstract,tei:msContents/tei:summary)[normalize-space(.)][1]">
         <xsl:variable name="abstract">
            <xsl:apply-templates select="(ancestor-or-self::tei:teiHeader[1]//tei:profileDesc/tei:abstract,tei:msContents/tei:summary)[normalize-space(.)][1]" mode="html"/>
         </xsl:variable>
         <map key="abstract" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:call-template name="write-data-obj-flat">
               <xsl:with-param name="display" select="$level ne 'doc'"/>
               <xsl:with-param name="displayForm" select="normalize-space($abstract)"/>
               <xsl:with-param name="label" select="'Abstract'"/>
               <xsl:with-param name="seq" select="1"/>
            </xsl:call-template>
         </map>
      </xsl:if>
   </xsl:template>

   <xsl:template name="get-subjects">
      <!-- level may be either 'doc' or 'part' -->
      <xsl:param name="level" select="'doc'"/>

      <xsl:variable name="target" as="item()*">
         <xsl:choose>
            <xsl:when test="$level = 'doc'">
               <xsl:copy-of select="//tei:profileDesc/tei:textClass/tei:keywords/tei:list/tei:item/tei:term[not(@ref)][not(@type='placename')]"/>
            </xsl:when>
            <xsl:otherwise>
               <!-- part -->
               <xsl:variable name="mspart_id" select="@xml:id"/>
               <xsl:variable name="mspart_id_ref">
                  <xsl:if test="normalize-space($mspart_id)">
                     <xsl:value-of select="concat('#', $mspart_id)"/>
                  </xsl:if>
               </xsl:variable>
               <xsl:copy-of select="//tei:profileDesc/tei:textClass/tei:keywords/tei:list/tei:item/tei:term[@ref=$mspart_id_ref][not(@type='placename')]"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:if test="$target">
         <!-- SHIM removed [normalize-space(.)] for testing compatibility -->
         <map key="subjects" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:call-template name="write-metadata-block-header">
               <xsl:with-param name="seq" select="1"/>
               <xsl:with-param name="label" select="'Subject(s)'"/>
               <xsl:with-param name="listDisplay" select="'inline'"/>
            </xsl:call-template>

            <array key="value" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:for-each select="if ($level eq 'part') then $target else $target[normalize-space(.)]">
                  <map xmlns="http://www.w3.org/2005/xpath-functions">
                     <xsl:if test="normalize-space(.)">
                        <xsl:copy-of select="cudl:display(true())"/>
                        <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
                           <xsl:value-of select="normalize-space(.)"/>
                        </string>
                        <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
                           <xsl:value-of select="1"/>
                        </number>
                        <string key="linktype" xmlns="http://www.w3.org/2005/xpath-functions">
                           <xsl:value-of select="'keyword search'"/>
                        </string>
                        <string key="fullForm" xmlns="http://www.w3.org/2005/xpath-functions">
                           <xsl:value-of select="normalize-space(.)"/>
                        </string>
                        <xsl:if test="(starts-with(@key, 'subject_sh'))">
                           <string key="authority" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:text>Library of Congress Subject Headings</xsl:text>
                           </string>
                           <string key="authorityURI" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:text>http://id.loc.gov/authorities/about.html#lcsh</xsl:text>
                           </string>
                           <string key="valueURI" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:value-of select="@key"/>
                           </string>
                        </xsl:if>
                     </xsl:if>
                  </map>
               </xsl:for-each>
            </array>
         </map>
      </xsl:if>
   </xsl:template>

   <xsl:template name="get-places">
      <!-- level may be either 'doc' or 'part' -->
      <xsl:param name="level" select="'doc'"/>

      <xsl:variable name="target" as="item()*">
         <xsl:choose>
            <xsl:when test="$level = 'doc'">
               <xsl:copy-of select="//tei:profileDesc/tei:textClass/tei:keywords/tei:list/tei:item/tei:term[not(@ref)][@type='placename']"/>
            </xsl:when>
            <xsl:otherwise>
               <!-- part -->
               <xsl:variable name="mspart_id" select="@xml:id"/>
               <xsl:variable name="mspart_id_ref">
                  <xsl:if test="normalize-space($mspart_id)">
                     <xsl:value-of select="concat('#', $mspart_id)"/>
                  </xsl:if>
               </xsl:variable>
               <xsl:copy-of select="//tei:profileDesc/tei:textClass/tei:keywords/tei:list/tei:item/tei:term[@ref=$mspart_id_ref][@type='placename']"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:if test="$target">
         <map key="places" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:copy-of select="cudl:display(true())"/>
            <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:text>Associated Place(s)</xsl:text>
            </string>
            <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="1"/>
            </number>
            <array key="value" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:for-each select="$target">
                  <xsl:if test="normalize-space(.)">
                     <map xmlns="http://www.w3.org/2005/xpath-functions">
                        <xsl:if test="normalize-space(.)">
                           <xsl:copy-of select="cudl:display(true())"/>
                           <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:value-of select="normalize-space(.)"/>
                           </string>
                           <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions" parent="descriptiveMetadata">
                              <xsl:value-of select="1"/>
                           </number>
                           <string key="linktype" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:value-of select="'keyword search'"/>
                           </string>
                           <string key="fullForm" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:value-of select="normalize-space(.)"/>
                           </string>
                           <xsl:if test="(starts-with(@key, 'subject_sh'))"><!-- IS THIS USED -->
                              <string key="authority" xmlns="http://www.w3.org/2005/xpath-functions">
                                 <xsl:text>Library of Congress Subject Headings</xsl:text>
                              </string>
                              <string key="authorityURI" xmlns="http://www.w3.org/2005/xpath-functions">
                                 <xsl:text>http://id.loc.gov/authorities/about.html#lcsh</xsl:text>
                              </string>
                              <string key="valueURI" xmlns="http://www.w3.org/2005/xpath-functions">
                                 <xsl:value-of select="@key"/>
                              </string>
                           </xsl:if>
                        </xsl:if>
                     </map>
                  </xsl:if>
               </xsl:for-each>
            </array>
         </map>
      </xsl:if>
   </xsl:template>

   <xsl:template name="get-doc-events">
      <xsl:choose>
         <xsl:when test="//tei:editor[@role='pbl'] and tei:history/tei:origin">
            <map key="publications" xmlns="http://www.w3.org/2005/xpath-functions">
               <!-- Root of object is a container for our standard flat objects, stored in value array -->
               <xsl:copy-of select="cudl:display(true())"/>
               <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="1"/>
               </number>
               <array key="value" xmlns="http://www.w3.org/2005/xpath-functions">
                  <!--will there only ever be one of these?-->
                  <xsl:for-each select="tei:history/tei:origin">
                     <map xmlns="http://www.w3.org/2005/xpath-functions">
                        <string key="type" xmlns="http://www.w3.org/2005/xpath-functions">
                           <xsl:text>publication</xsl:text>
                        </string>

                        <xsl:variable name="place-elems" as="item()*">
                           <xsl:variable name="item_teiHeader" select="ancestor-or-self::tei:teiHeader[1]"/>
                           <xsl:choose>
                              <xsl:when test="exists($item_teiHeader//tei:profileDesc/tei:correspDesc/tei:correspAction//tei:placeName)">
                                 <xsl:copy-of select="$item_teiHeader//tei:profileDesc/tei:correspDesc/tei:correspAction//tei:placeName"/>
                              </xsl:when>
                              <xsl:otherwise>
                                 <xsl:copy-of select="descendant::tei:origPlace"/>
                              </xsl:otherwise>
                           </xsl:choose>
                        </xsl:variable>

                        <xsl:if test="$place-elems">
                           <map key="places" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:copy-of select="cudl:display(true())"/>
                              <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
                                 <xsl:value-of select="'Place of Publication'"/>
                              </string>
                              <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
                                 <xsl:value-of select="1"/>
                              </number>
                              <array key="value" xmlns="http://www.w3.org/2005/xpath-functions">
                                 <xsl:for-each select="$place-elems">
                                    <map xmlns="http://www.w3.org/2005/xpath-functions">
                                       <xsl:copy-of select="cudl:display(true())"/>
                                       <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
                                          <xsl:value-of select="normalize-space(.)"/>
                                       </string>
                                       <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
                                          <xsl:value-of select="1"/>
                                       </number>
                                       <string key="linktype" xmlns="http://www.w3.org/2005/xpath-functions">
                                          <xsl:value-of select="'keyword search'"/>
                                       </string>
                                       <string key="shortForm" xmlns="http://www.w3.org/2005/xpath-functions">
                                          <xsl:value-of select="normalize-space(.)"/>
                                       </string>
                                       <string key="fullForm" xmlns="http://www.w3.org/2005/xpath-functions">
                                          <xsl:value-of select="normalize-space(.)"/>
                                       </string>
                                    </map>
                                 </xsl:for-each>
                              </array>
                           </map>
                        </xsl:if>

                        <xsl:variable name="preferred-date-elem" as="item()*">
                           <xsl:variable name="correspAction-elems" select="ancestor-or-self::tei:teiHeader[1]//tei:correspDesc/tei:correspAction" as="item()*"/>
                           <xsl:copy-of select="($correspAction-elems[@type='sent']//tei:date,$correspAction-elems[not(@type='sent')]//tei:date,.//tei:origDate,.//tei:date)[1]" />
                        </xsl:variable>

                        <xsl:if test="not(empty($preferred-date-elem))">
                           <xsl:call-template name="output-date-elems">
                              <xsl:with-param name="date_elem" select="$preferred-date-elem"/>
                              <xsl:with-param name="label" select="'Date of Publication'"/>
                              <xsl:with-param name="output_empty" select="false()"/>
                           </xsl:call-template>
                        </xsl:if>

                        <map key="publishers" xmlns="http://www.w3.org/2005/xpath-functions">
                           <xsl:copy-of select="cudl:display(true())"/>
                           <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:value-of select="1"/>
                           </number>
                           <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:text>Publisher</xsl:text>
                           </string>
                           <array key="value" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:apply-templates select="//tei:editor[@role='pbl']" mode="publisher"/>
                           </array>
                        </map>
                     </map>
                  </xsl:for-each>
               </array>
            </map>
         </xsl:when>
         <xsl:when test="tei:history/tei:origin|ancestor-or-self::tei:teiHeader[1]//tei:profileDesc/tei:correspDesc/tei:correspAction[descendant::tei:placeName|descendant::tei:date]">
            <map key="creations" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:copy-of select="cudl:display(true())"/>
               <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="1"/>
               </number>

               <xsl:variable name="context-elem" as="item()*">
                  <xsl:choose>
                     <xsl:when test="ancestor-or-self::tei:teiHeader[1]//tei:profileDesc/tei:correspDesc">
                        <xsl:copy-of select="ancestor-or-self::tei:teiHeader[1]//tei:profileDesc/tei:correspDesc"/>
                     </xsl:when>
                     <xsl:when test="tei:history/tei:origin">
                        <xsl:copy-of select="tei:history/tei:origin"/>
                     </xsl:when>
                  </xsl:choose>
               </xsl:variable>

               <array key="value" xmlns="http://www.w3.org/2005/xpath-functions">

                  <xsl:for-each select="$context-elem">
                     <map xmlns="http://www.w3.org/2005/xpath-functions">
                        <string key="type" xmlns="http://www.w3.org/2005/xpath-functions">
                           <xsl:text>creation</xsl:text>
                        </string>

                        <xsl:variable name="place-elems" as="item()*">
                           <xsl:choose>
                              <xsl:when test="exists(tei:correspAction//tei:placeName)">
                                 <xsl:copy-of select="tei:correspAction//tei:placeName"/>
                              </xsl:when>
                              <xsl:otherwise>
                                 <xsl:copy-of select="descendant::tei:origPlace"/>
                              </xsl:otherwise>
                           </xsl:choose>
                        </xsl:variable>

                        <xsl:if test="not(empty($place-elems))">
                           <map key="places" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:copy-of select="cudl:display(true())"/>
                              <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
                                 <xsl:value-of select="70"/>
                              </number>
                              <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
                                 <xsl:text>Origin Place</xsl:text>
                              </string>
                              <array key="value" xmlns="http://www.w3.org/2005/xpath-functions">
                                 <xsl:for-each select="$place-elems">
                                    <map xmlns="http://www.w3.org/2005/xpath-functions">
                                       <xsl:copy-of select="cudl:display(true())"/>
                                       <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
                                          <xsl:value-of select="normalize-space(.)"/>
                                       </string>
                                       <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
                                          <xsl:value-of select="1"/>
                                       </number>
                                       <string key="linktype" xmlns="http://www.w3.org/2005/xpath-functions">
                                          <xsl:text>keyword search</xsl:text>
                                       </string>
                                       <string key="shortForm" xmlns="http://www.w3.org/2005/xpath-functions">
                                          <xsl:value-of select="normalize-space(.)"/>
                                       </string>
                                       <string key="fullForm" xmlns="http://www.w3.org/2005/xpath-functions">
                                          <xsl:value-of select="normalize-space(.)"/>
                                       </string>
                                    </map>
                                 </xsl:for-each>
                              </array>
                           </map>
                        </xsl:if>

                        <xsl:variable name="preferred-date-elem" as="item()*">
                           <xsl:variable name="correspAction-elems" select="$context-elem//tei:correspAction" as="item()*"/>
                           <xsl:copy-of select="($correspAction-elems[@type='sent']//tei:date,$correspAction-elems[not(@type='sent')]//tei:date,.//tei:origDate,.//tei:date)[1]"/>
                        </xsl:variable>

                        <xsl:if test="not(empty($preferred-date-elem))">
                           <xsl:call-template name="output-date-elems">
                              <xsl:with-param name="date_elem" select="$preferred-date-elem"/>
                              <xsl:with-param name="output_empty" select="false()"/><!-- SHIM COMPAT -->
                              <xsl:with-param name="output_centuries" select="true()"/>
                           </xsl:call-template>
                        </xsl:if>
                     </map>
                  </xsl:for-each>
               </array>
            </map>
         </xsl:when>
      </xsl:choose>

      <xsl:if test="tei:history/tei:acquisition">
         <map key="acquisitions" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:copy-of select="cudl:display(true())"/>
            <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="1"/>
            </number>
            <array key="value" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:for-each select="tei:history/tei:acquisition">
                  <map xmlns="http://www.w3.org/2005/xpath-functions">
                     <string key="type" xmlns="http://www.w3.org/2005/xpath-functions">
                        <xsl:value-of select="'acquisition'"/>
                     </string>
                     <xsl:for-each select=".//tei:date[1][not (parent::tei:date)]">
                        <xsl:variable name="dateStart" select="cudl:get-date-start(.)" as="xsd:string*"/>
                        <xsl:if test="exists((@from, @notBefore, @when)[1]) or $dateStart !=''"><!-- SHIM COMPAT -->
                           <string key="dateStart" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:value-of select="$dateStart"/>
                           </string>
                        </xsl:if>

                        <xsl:variable name="dateEnd" select="cudl:get-date-end(.)" as="xsd:string*"/>
                        <xsl:if test="exists((@to, @notAfter, @when)[1]) or $dateEnd !=''"><!-- SHIM COMPAT -->
                           <string key="dateEnd" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:value-of select="$dateEnd"/>
                           </string>
                        </xsl:if>
                        <map key="dateDisplay" xmlns="http://www.w3.org/2005/xpath-functions">
                           <xsl:copy-of select="cudl:display(true())"/>
                           <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:value-of select="normalize-space(.)"/>
                           </string>
                           <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:value-of select="1"/>
                           </number>
                           <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:value-of select="'Date of Acquisition'"/>
                           </string>
                        </map>
                     </xsl:for-each>
                  </map>
            </xsl:for-each>
            </array>
         </map>
      </xsl:if>
   </xsl:template>

   <xsl:template match="tei:editor[@role='pbl']" mode="publisher">
      <map xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:copy-of select="cudl:display(true())"/>
         <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="normalize-space(.)"/>
         </string>
         <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="1"/>
         </number>
      </map>
   </xsl:template>

   <xsl:template name="get-doc-physloc">
      <xsl:if test="tei:msIdentifier/tei:repository[normalize-space(.)]">
         <map key="physicalLocation" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:copy-of select="cudl:display(true())"/>
            <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="normalize-space(tei:msIdentifier/tei:repository)"/>
            </string>
            <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:text>Physical Location</xsl:text>
            </string>
            <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="1"/>
            </number>
         </map>
      </xsl:if>

      <xsl:variable name="shelfLocator_elem" as="item()*">
         <xsl:choose>
            <xsl:when test="ancestor-or-self::tei:teiHeader[1]/tei:fileDesc/tei:sourceDesc/tei:bibl[normalize-space(.)]">
               <xsl:copy-of select="(ancestor-or-self::tei:teiHeader[1]/tei:fileDesc/tei:sourceDesc/tei:bibl[normalize-space(.)])[1]"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:copy-of select="tei:msIdentifier/tei:idno"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:if test="$shelfLocator_elem[normalize-space(.)]">
         <map key="shelfLocator" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:copy-of select="cudl:display(true())"/>
            <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="normalize-space($shelfLocator_elem)"/>
            </string>
            <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:text>Classmark</xsl:text>
            </string>
            <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="1"/>
            </number>
         </map>
      </xsl:if>
   </xsl:template>

   <xsl:template name="get-doc-alt-ids">
      <xsl:if test="normalize-space(tei:msIdentifier/tei:altIdentifier[not(@type='internal')][1]/tei:idno)">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'altIdentifiers'"/>
            <xsl:with-param name="displayFormIter" select="tei:msIdentifier/tei:altIdentifier[not(@type='internal')]/tei:idno"/>
            <xsl:with-param name="label" select="'Alternative Identifier(s)'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="seq2" select="2"/>
         </xsl:call-template>
      </xsl:if>
   </xsl:template>

   <xsl:template name="get-doc-thumbnail">

      <xsl:if test="count(//tei:graphic[@decls='#document-thumbnail']) gt 1">
         <xsl:message select="concat('WARN: More than one #document-thumbnail block in ', tokenize(document-uri(/), '/')[last()])"/>
      </xsl:if>

      <xsl:variable name="graphic" select="(//tei:graphic[@decls='#document-thumbnail'])[1]"/>

      <xsl:if test="$graphic">
         <string key="thumbnailUrl" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="normalize-space($graphic/@url)"/>
         </string>
         <string key="thumbnailOrientation" xmlns="http://www.w3.org/2005/xpath-functions">
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
         </string>
      </xsl:if>
   </xsl:template>

   <xsl:template name="get-doc-image-rights">
      <string key="displayImageRights" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:value-of select="normalize-space(//tei:publicationStmt/tei:availability[@xml:id='displayImageRights'])" />
      </string>
      <string key="downloadImageRights" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:value-of select="normalize-space(//tei:publicationStmt/tei:availability[@xml:id='downloadImageRights'])" />
      </string>
      <string key="imageReproPageURL" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:value-of select="cudl:get-imageReproPageURL(normalize-space(tei:msIdentifier/tei:repository), normalize-space(tei:msIdentifier/tei:idno))" />
      </string>
   </xsl:template>

   <xsl:template name="get-doc-metadata-rights">
      <string key="metadataRights" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:value-of select="normalize-space(//tei:publicationStmt/tei:availability[@xml:id='metadataRights'])"/>
      </string>
   </xsl:template>

   <xsl:template name="get-doc-transcription-rights">
      <string key="transcriptionRights" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:value-of select="normalize-space(//tei:publicationStmt/tei:availability[@xml:id='transcriptionRights'])"/>
      </string>
   </xsl:template>

   <xsl:template name="get-doc-pdf-rights">
      <string key="pdfRights" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:value-of select="normalize-space(//tei:publicationStmt/tei:availability[@xml:id='pdfRights'])"/>
      </string>
   </xsl:template>

   <xsl:template name="get-doc-watermark-statement">
      <string key="watermarkStatement" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:value-of select="normalize-space((//tei:publicationStmt/tei:availability[@xml:id='watermark'])[normalize-space(.)][1])"/>
      </string>
   </xsl:template>

   <xsl:template name="get-doc-authority">
      <string key="docAuthority" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:variable name="authority">
            <xsl:apply-templates select="//tei:publicationStmt/tei:authority" mode="html"/>
         </xsl:variable>
         <xsl:value-of select="normalize-space($authority)"/>
      </string>
   </xsl:template>

   <xsl:template match="tei:note[@type='completeness']"><!-- NB: This does not apperar to be used. Delete? -->
      <completeness>
         <xsl:value-of select="normalize-space(.)"/>
      </completeness>
   </xsl:template>

   <xsl:template name="get-doc-funding">
      <xsl:variable name="funding">
         <xsl:apply-templates select="//tei:titleStmt/tei:funder" mode="html"/>
      </xsl:variable>

      <xsl:call-template name="write-container-lg">
         <xsl:with-param name="type" select="'fundings'"/>
         <xsl:with-param name="displayFormIter" select="$funding"/>
         <xsl:with-param name="label" select="'Funding'"/>
         <xsl:with-param name="seq" select="1"/>
         <xsl:with-param name="seq2" select="2"/>
         <xsl:with-param name="displayNullItems" select="true()"/>
      </xsl:call-template>
   </xsl:template>

   <xsl:template name="write-data-obj-flat" xmlns="http://www.w3.org/2005/xpath-functions">
      <xsl:param name="display" select="true()"/>
      <xsl:param name="seq" select="1"/>
      <xsl:param name="listDisplay"/>
      <xsl:param name="label"/>
      <xsl:param name="displayForm"/>
      <xsl:param name="displayNull" select="false()"/>

      <xsl:copy-of select="cudl:display($display)"/>
      <xsl:choose>
         <xsl:when test="not(normalize-space($displayForm)) and $displayNull"><!-- SHIM: Entire clause  to print displayForm and others in correct order -->
            <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="$displayForm"/>
            </string>
            <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="$label"/>
            </string>
            <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="$seq"/>
            </number>
         </xsl:when>
         <xsl:when test="normalize-space($displayForm)">
            <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="$displayForm"/>
            </string>
            <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="$label"/>
            </string>
            <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="$seq"/>
            </number>
         </xsl:when>
         <xsl:otherwise>
            <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="$seq"/>
            </number>
            <xsl:if test="normalize-space($listDisplay) != ''">
               <string key="listDisplay" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="$listDisplay"/>
               </string>
            </xsl:if>
            <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="$label"/>
            </string>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template name="write-metadata-block-header" xmlns="http://www.w3.org/2005/xpath-functions">
      <xsl:param name="display" select="true()"/>
      <xsl:param name="seq" select="1"/>
      <xsl:param name="listDisplay"/>
      <xsl:param name="label"/>
      <xsl:param name="displayForm"/>
      <xsl:param name="displayNull" select="false()"/>

      <xsl:copy-of select="cudl:display($display)"/>
      <xsl:choose>
         <xsl:when test="not(normalize-space($displayForm)) and $displayNull"><!-- SHIM: Entire clause  to print displayForm and others in correct order -->
            <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="$displayForm"/>
            </string>
            <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="$label"/>
            </string>
            <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="$seq"/>
            </number>
         </xsl:when>
         <xsl:when test="normalize-space($displayForm)">
            <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="$displayForm"/>
            </string>
            <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="$label"/>
            </string>
            <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="$seq"/>
            </number>
         </xsl:when>
         <xsl:otherwise>
            <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="$seq"/>
            </number>
            <xsl:if test="normalize-space($listDisplay) != ''">
               <string key="listDisplay" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="$listDisplay"/>
               </string>
            </xsl:if>
            <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="$label"/>
            </string>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template name="write-container-lg" as="item()*">
      <xsl:param name="type"/>
      <xsl:param name="display" select="true()"/>
      <xsl:param name="displayForm"/>
      <xsl:param name="displayFormIter"/>
      <xsl:param name="label"/>
      <xsl:param name="seq"/>
      <xsl:param name="seq2"/>
      <xsl:param name="displayNullItems" select="false()"/>

      <map key="{$type}" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:choose>
            <xsl:when test="string($seq2) = ''">
               <xsl:call-template name="write-data-obj-flat">
                  <xsl:with-param name="display" select="$display"/>
                  <xsl:with-param name="displayForm" select="$displayForm"/>
                  <xsl:with-param name="label" select="$label"/>
                  <xsl:with-param name="seq" select="$seq"/>
                  <xsl:with-param name="displayNull" select="$displayNullItems"/>
               </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
               <xsl:copy-of select="cudl:display($display)"/>
               <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="$seq"/>
               </number>
               <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="$label"/>
               </string>
               <array key="value" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:choose>
                     <xsl:when test="not($displayNullItems) and empty($displayFormIter[normalize-space(.)])"/>
                     <xsl:when test="$displayNullItems or (not($displayNullItems) and not(empty($displayFormIter[normalize-space(.)])))">
                        <xsl:variable name="iterItems" as="item()*">
                           <xsl:choose>
                              <xsl:when test="empty($displayFormIter[normalize-space(.)]) or $type = 'notes'">
                                 <xsl:copy-of select="$displayFormIter"/>
                              </xsl:when>
                              <xsl:otherwise>
                                 <xsl:copy-of select="$displayFormIter[normalize-space(.)]"/>
                              </xsl:otherwise>
                           </xsl:choose>
                        </xsl:variable>
                        <xsl:for-each select="$iterItems">
                           <map xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:copy-of select="cudl:display($display)"/>
                              <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
                                 <xsl:value-of select="normalize-space(.)"/>
                              </string>
                              <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
                                 <xsl:value-of select="$seq2"/>
                              </number>
                           </map>
                        </xsl:for-each>
                     </xsl:when>
                     <xsl:otherwise>
                        <map xmlns="http://www.w3.org/2005/xpath-functions">
                           <xsl:copy-of select="cudl:display($display)"/>
                           <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:value-of select="$displayForm"/>
                           </string>
                           <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:value-of select="$seq2"/>
                           </number>
                        </map>
                     </xsl:otherwise>
                  </xsl:choose>
               </array>
            </xsl:otherwise>
         </xsl:choose>
      </map>
   </xsl:template>

   <xsl:template name="get-doc-physdesc">
      <xsl:if test="exists(tei:physDesc/tei:p|tei:physDesc/tei:list)">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'physdesc'"/>
            <xsl:with-param name="displayForm">
               <xsl:variable name="physdesc">
                  <xsl:apply-templates select="tei:physDesc/tei:p|tei:physDesc/tei:list" mode="html"/>
               </xsl:variable>
               <xsl:value-of select="normalize-space($physdesc)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Physical Description'"/>
            <xsl:with-param name="seq" select="1"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="normalize-space(tei:physDesc/tei:objectDesc/@form)">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'form'"/>
            <xsl:with-param name="displayForm">
               <xsl:variable name="t">
                  <xsl:apply-templates select="tei:physDesc/tei:objectDesc/@form" mode="html"/>
               </xsl:variable>
               <xsl:value-of select="normalize-space($t)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Format'"/>
            <xsl:with-param name="seq" select="1"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="normalize-space(tei:physDesc/tei:objectDesc/tei:supportDesc/tei:support)">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'material'"/>
            <xsl:with-param name="displayForm">
               <xsl:variable name="t">
                  <xsl:apply-templates select="tei:physDesc/tei:objectDesc/tei:supportDesc/tei:support"
                     mode="html"/>
               </xsl:variable>
               <xsl:value-of select="normalize-space($t)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Material'"/>
            <xsl:with-param name="seq" select="1"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="normalize-space(tei:physDesc/tei:objectDesc/tei:supportDesc/tei:extent)">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'extent'"/>
            <xsl:with-param name="displayForm">
               <xsl:variable name="t">
                  <xsl:apply-templates select="tei:physDesc/tei:objectDesc/tei:supportDesc/tei:extent" mode="html"/>
               </xsl:variable>
               <xsl:value-of select="normalize-space($t)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Extent'"/>
            <xsl:with-param name="seq" select="1"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:physDesc/tei:objectDesc/tei:supportDesc/tei:foliation">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'foliation'"/>
            <xsl:with-param name="displayForm">
               <xsl:variable name="t">
                  <xsl:apply-templates select="tei:physDesc/tei:objectDesc/tei:supportDesc/tei:foliation" mode="html"/>
               </xsl:variable>
               <xsl:value-of select="normalize-space($t)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Foliation'"/>
            <xsl:with-param name="seq" select="1"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:physDesc/tei:objectDesc/tei:supportDesc/tei:collation">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'collation'"/>
            <xsl:with-param name="displayForm">
               <xsl:variable name="t">
                  <xsl:apply-templates select="tei:physDesc/tei:objectDesc/tei:supportDesc/tei:collation" mode="html"/>
               </xsl:variable>
               <xsl:value-of select="normalize-space($t)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Collation'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="displayNullItems" select="true()"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="normalize-space(tei:physDesc/tei:objectDesc/tei:supportDesc/tei:condition)">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'conditions'"/>
            <xsl:with-param name="displayFormIter">
               <xsl:variable name="t">
                  <xsl:apply-templates select="tei:physDesc/tei:objectDesc/tei:supportDesc/tei:condition" mode="html"/>
               </xsl:variable>
               <xsl:value-of select="normalize-space($t)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Condition'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="seq2" select="1"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:physDesc/tei:objectDesc/tei:layoutDesc">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'layouts'"/>
            <xsl:with-param name="displayFormIter">
               <xsl:variable name="t">
                  <xsl:apply-templates select="tei:physDesc/tei:objectDesc/tei:layoutDesc" mode="html"/>
               </xsl:variable>
               <xsl:value-of select="normalize-space($t)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Layout'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="seq2" select="2"/>
            <xsl:with-param name="displayNullItems" select="true()"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:physDesc/tei:handDesc">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'scripts'"/>
            <xsl:with-param name="displayFormIter">
               <xsl:variable name="t">
                  <xsl:apply-templates select="tei:physDesc/tei:handDesc" mode="html"/>
               </xsl:variable>
               <xsl:value-of select="normalize-space($t)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Script'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="seq2" select="2"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:physDesc/tei:musicNotation">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'musicNotations'"/>
            <xsl:with-param name="displayFormIter">
               <xsl:variable name="t">
                  <xsl:apply-templates select="tei:physDesc/tei:musicNotation" mode="html"/>
               </xsl:variable>
               <xsl:value-of select="normalize-space($t)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Music notation'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="seq2" select="2"/>
            <xsl:with-param name="displayNullItems" select="true()"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:physDesc/tei:decoDesc">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'decorations'"/>
            <xsl:with-param name="displayFormIter">
               <xsl:variable name="t">
                  <xsl:apply-templates select="tei:physDesc/tei:decoDesc" mode="html"/>
               </xsl:variable>
               <xsl:value-of select="normalize-space($t)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Decoration'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="seq2" select="2"/>
            <xsl:with-param name="displayNullItems" select="true()"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:physDesc/tei:additions">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'additions'"/>
            <xsl:with-param name="displayFormIter">
               <xsl:variable name="t">
                  <xsl:apply-templates select="tei:physDesc/tei:additions" mode="html"/>
               </xsl:variable>
               <xsl:value-of select="normalize-space($t)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Additions'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="seq2" select="2"/>
            <xsl:with-param name="displayNullItems" select="true()"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:physDesc/tei:bindingDesc">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'bindings'"/>
            <xsl:with-param name="displayFormIter">
               <xsl:variable name="t">
                  <xsl:apply-templates select="tei:physDesc/tei:bindingDesc" mode="html"/>
               </xsl:variable>
               <xsl:value-of select="normalize-space($t)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Binding'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="seq2" select="2"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:physDesc/tei:accMat">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'accMats'"/>
            <xsl:with-param name="displayFormIter">
               <xsl:variable name="t">
                  <xsl:apply-templates select="tei:physDesc/tei:accMat" mode="html"/>
               </xsl:variable>
               <xsl:value-of select="normalize-space($t)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Accompanying Material'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="seq2" select="2"/>
            <xsl:with-param name="displayNullItems" select="true()"/>
         </xsl:call-template>
      </xsl:if>
   </xsl:template>

   <xsl:template match="tei:objectDesc/@form" mode="html">
      <xsl:value-of select="concat(upper-case(substring(., 1, 1)), substring(., 2))"/>
   </xsl:template>

   <xsl:template match="tei:supportDesc/tei:foliation" mode="html">
      <xsl:text>&lt;p&gt;</xsl:text>

      <xsl:if test="@n">
         <xsl:value-of select="@n"/>
         <xsl:text>. </xsl:text>
      </xsl:if>

      <xsl:if test="@type">
         <xsl:value-of select="cudl:capitalise-first(@type)"/>
         <xsl:text>: </xsl:text>
      </xsl:if>

      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/p&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:dimensions" mode="html">
      <xsl:if test="@subtype">
         <xsl:text>&lt;b&gt;</xsl:text>
         <xsl:value-of select="cudl:capitalise-first(translate(@subtype, '_', ' '))"/>
         <xsl:text>:</xsl:text>
         <xsl:text>&lt;/b&gt;</xsl:text>
         <xsl:text> </xsl:text>
      </xsl:if>

      <xsl:text> </xsl:text>
      <xsl:value-of select="cudl:capitalise-first(@type)"/>
      <xsl:text> </xsl:text>
      <xsl:for-each select="*">
         <xsl:choose>
            <xsl:when test="self::tei:dim">
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
            <xsl:otherwise/>
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

   <xsl:template match="tei:commentaryForm" mode="html">
      <xsl:text>&lt;div&gt;</xsl:text>
      <xsl:text>&lt;b&gt;Commentary form:&lt;/b&gt; </xsl:text>
      <xsl:value-of select="@type"/>
      <xsl:text>. </xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:handDesc" mode="html">
      <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:handNote" mode="html">
      <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:decoNote" mode="html">
      <xsl:apply-templates mode="html"/>
      <xsl:if test="exists(following-sibling::*)">
         <xsl:text>&lt;br /&gt;</xsl:text>
      </xsl:if>
   </xsl:template>

   <xsl:template match="tei:additions|tei:bindingDesc|tei:accMat|tei:decoDesc|tei:stringHole|tei:layout|tei:layoutDesc|tei:supportDesc/tei:condition|tei:supportDesc/tei:support|tei:supportDesc/tei:extent|tei:recordHist/tei:source|tei:revisionDesc|tei:note|tei:abstract|tei:authority" mode="html">
      <xsl:apply-templates mode="html"/>
   </xsl:template>

   <xsl:template match="tei:history/tei:provenance|tei:history/tei:origin|tei:history/tei:acquisition" mode="html">
      <xsl:if test="normalize-space(.)">
         <xsl:apply-templates mode="html"/>
      </xsl:if>
   </xsl:template>

   <xsl:template match="tei:msItem/tei:colophon|tei:msItem/tei:div/tei:colophon" mode="html">
      <xsl:text>&lt;div&gt;</xsl:text>
      <xsl:text>&lt;b&gt;Colophon</xsl:text>

      <xsl:if test="normalize-space(@type)">
         <xsl:value-of select="concat(', ', normalize-space(@type))"/>
      </xsl:if>

      <xsl:text>:&lt;/b&gt; </xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:msItem/tei:explicit|tei:msItem/tei:div/tei:explicit" mode="html">
      <xsl:text>&lt;div&gt;</xsl:text>
      <xsl:text>&lt;b&gt;Explicit</xsl:text>

      <xsl:if test="normalize-space(@type)">
         <xsl:value-of select="concat(', ', normalize-space(@type))"/>
      </xsl:if>

      <xsl:text>:&lt;/b&gt; </xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:msItem/tei:incipit|tei:msItem/tei:div/tei:incipit" mode="html">
      <xsl:text>&lt;div&gt;</xsl:text>
      <xsl:text>&lt;b&gt;Incipit</xsl:text>

      <xsl:if test="normalize-space(@type)">
         <xsl:value-of select="concat(', ', normalize-space(@type))"/>
      </xsl:if>

      <xsl:text>:&lt;/b&gt; </xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:summary" mode="html">
      <!--we need to put this in a paragraph if the summary itself contains no paragraphs-->
      <xsl:choose>
         <xsl:when test=".//tei:seg[@type='para']">
            <xsl:apply-templates mode="html"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:text>&lt;p style=&apos;text-align: justify;&apos;&gt;</xsl:text>
            <xsl:apply-templates mode="html"/>
            <xsl:text>&lt;/p&gt;</xsl:text>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="tei:msItem/tei:rubric|tei:msItem/tei:div/tei:rubric" mode="html">
      <xsl:text>&lt;div&gt;</xsl:text>
      <xsl:text>&lt;b&gt;Rubric</xsl:text>

      <xsl:if test="normalize-space(@type)">
         <xsl:value-of select="concat(', ', normalize-space(@type))"/>
      </xsl:if>

      <xsl:text>:&lt;/b&gt; </xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:msItem/tei:finalRubric|tei:msItem/tei:div/tei:finalRubric" mode="html">
      <xsl:text>&lt;div&gt;</xsl:text>
      <xsl:text>&lt;b&gt;Final Rubric</xsl:text>

      <xsl:if test="normalize-space(@type)">
         <xsl:value-of select="concat(', ', normalize-space(@type))"/>
      </xsl:if>

      <xsl:text>:&lt;/b&gt; </xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:msItem//tei:decoNote" mode="html">
      <xsl:choose>
         <xsl:when test="tei:p">
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

   <xsl:template match="tei:filiation" mode="html">
      <xsl:text>&lt;div&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:revisionDesc/tei:change" mode="html">
      <xsl:apply-templates mode="html"/>

      <xsl:if test="not(position()=last())">
         <xsl:text>&lt;br /&gt;</xsl:text>
      </xsl:if>
   </xsl:template>

   <xsl:template match="tei:incipit" mode="title">
      <xsl:apply-templates select="node() except tei:locus" mode="html"/>
   </xsl:template>

   <xsl:template match="tei:rubric" mode="title">
      <xsl:apply-templates select="node() except tei:locus" mode="html"/>
   </xsl:template>

   <xsl:template name="get-doc-history">
      <xsl:if test="tei:history/tei:provenance">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'provenances'"/>
            <xsl:with-param name="displayFormIter">
               <xsl:variable name="t">
                  <xsl:apply-templates select="tei:history/tei:provenance" mode="html"/>
               </xsl:variable>
               <xsl:value-of select="normalize-space($t)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Provenance'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="seq2" select="2"/>
            <xsl:with-param name="displayNullItems" select="true()"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:history/tei:origin/text()|tei:history/tei:origin/tei:p">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'origins'"/>
            <xsl:with-param name="displayFormIter">
               <xsl:variable name="t">
                  <xsl:apply-templates select="tei:history/tei:origin" mode="html"/>
               </xsl:variable>
               <xsl:value-of select="normalize-space($t)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Origin'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="seq2" select="2"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:history/tei:acquisition/text()|tei:history/tei:acquisition/tei:p">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'acquisitionTexts'"/>
            <xsl:with-param name="displayFormIter">
               <xsl:variable name="t">
                  <xsl:apply-templates select="tei:history/tei:acquisition" mode="html"/>
               </xsl:variable>
               <xsl:value-of select="normalize-space($t)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Acquisition'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="seq2" select="2"/>
         </xsl:call-template>
      </xsl:if>
   </xsl:template>

   <xsl:template name="get-item-excerpts">
      <xsl:if test="tei:head|tei:div/tei:head|tei:p|tei:div/tei:p|tei:div/tei:note|tei:colophon|tei:div/tei:colophon|tei:decoNote|tei:div/tei:decoNote|tei:explicit|tei:div/tei:explicit|tei:finalRubric|tei:div/tei:finalRubric|tei:incipit|tei:div/tei:incipit|tei:rubric|tei:div/tei:rubric">
         <xsl:variable name="excerpts">
            <xsl:apply-templates select="tei:head|tei:div/tei:head|tei:p|tei:div/tei:p|tei:div/tei:note|tei:colophon|tei:div/tei:colophon|tei:decoNote|tei:div/tei:decoNote|tei:explicit|tei:div/tei:explicit|tei:finalRubric|tei:div/tei:finalRubric|tei:incipit|tei:div/tei:incipit|tei:rubric|tei:div/tei:rubric" mode="html"/>
         </xsl:variable>

         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'excerpts'"/>
            <xsl:with-param name="displayForm" select="normalize-space($excerpts)"/>
            <xsl:with-param name="label" select="'Excerpts'"/>
            <xsl:with-param name="seq" select="1"/>
         </xsl:call-template>
      </xsl:if>
   </xsl:template>

   <xsl:template name="get-item-notes">
      <xsl:if test="tei:note">
         <xsl:variable name="notes" as="item()*">
            <xsl:for-each select="tei:note">
               <xsl:variable name="note">
                  <xsl:apply-templates mode="html"/>
               </xsl:variable>
               <xsl:sequence select="normalize-space($note)"/>
            </xsl:for-each>
         </xsl:variable>
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'notes'"/>
            <xsl:with-param name="displayFormIter" select="$notes"/>
            <xsl:with-param name="label" select="'Note(s)'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="seq2" select="2"/>
            <xsl:with-param name="displayNullItems" select="true()"/>
         </xsl:call-template>
      </xsl:if>
   </xsl:template>

   <xsl:template name="get-item-filiation">
      <xsl:if test="tei:filiation">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'filiations'"/>
            <xsl:with-param name="displayForm">
               <xsl:variable name="filiation">
                  <xsl:text>&lt;div&gt;</xsl:text>
                  <xsl:apply-templates select="tei:filiation" mode="html"/>
                  <xsl:text>&lt;/div&gt;</xsl:text>
               </xsl:variable>
               <xsl:value-of select="normalize-space($filiation)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Filiations'"/>
            <xsl:with-param name="seq" select="1"/>
         </xsl:call-template>
      </xsl:if>
   </xsl:template>

   <xsl:template name="write-named-entity-object">
      <xsl:param name="map_key"/>
      <xsl:param name="display" select="true()"/>
      <xsl:param name="seq" select="1"/>
      <xsl:param name="listDisplay" select="'unordered'"/>
      <xsl:param name="label"/>
      <xsl:param name="array_nodes"/>
      <xsl:param name="processing_mode" select="'default'"/>

      <map key="{$map_key}" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:copy-of select="cudl:display($display)"/>
         <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="$seq"/>
         </number>
         <xsl:if test="$listDisplay">
            <string key="listDisplay" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="$listDisplay"/>
            </string>
         </xsl:if>
         <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="$label"/>
         </string>
         <array key="value" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:variable name="name_obj" as="item()*">
               <xsl:choose>
               <xsl:when test="$processing_mode = 'doc-level'">
                  <xsl:apply-templates select="$array_nodes" mode="doc-level"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:apply-templates select="$array_nodes"/>
               </xsl:otherwise>
            </xsl:choose>
            </xsl:variable>
            <xsl:choose>
               <xsl:when test="$map_key = ('associated', 'formerOwners')">
                  <xsl:for-each-group select="$name_obj" group-by="json:string[@key='displayForm']">
                     <xsl:copy-of select="current-group()[1]"/>
                  </xsl:for-each-group>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:copy-of select="$name_obj"/>
               </xsl:otherwise>
            </xsl:choose>
         </array>
      </map>
   </xsl:template>

   <xsl:variable name="rolemap">
      <cudl:role code="aut" name="authors"/>
      <cudl:role code="dnr" name="donors"/>
      <cudl:role code="fmo" name="formerOwners"/>
      <cudl:role code="pbl" name="publishers"/>
      <cudl:role code="rcp" name="recipients"/>
      <cudl:role code="scr" name="scribes"/>
   </xsl:variable>

   <xsl:template name="get-doc-names">
      <xsl:if test="tei:msContents/tei:summary//tei:name[@role='aut']|tei:physDesc//tei:name[@role='aut']|tei:history//tei:name[@role='aut']">
         <xsl:call-template name="write-named-entity-object">
            <xsl:with-param name="map_key" select="'authors'"/>
            <xsl:with-param name="label" select="'Author(s)'"/>
            <xsl:with-param name="seq" select="42"></xsl:with-param>
            <xsl:with-param name="array_nodes" select="(
               tei:msContents/tei:summary//tei:name[@role='aut'],
               tei:physDesc//tei:name[@role='aut'],
               tei:history//tei:name[@role='aut']
               )"/>
            <xsl:with-param name="processing_mode" select="'doc-level'"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:msContents/tei:summary//tei:name[@role='dnr']|tei:physDesc//tei:name[@role='dnr']|tei:history//tei:name[@role='dnr']">
         <xsl:call-template name="write-named-entity-object">
            <xsl:with-param name="map_key" select="'donors'"/>
            <xsl:with-param name="label" select="'Donor(s)'"/>
            <xsl:with-param name="listDisplay" select="false()"/>
            <xsl:with-param name="seq" select="42"></xsl:with-param>
            <xsl:with-param name="array_nodes" select="(
               tei:msContents/tei:summary//tei:name[@role='dnr'],
               tei:physDesc//tei:name[@role='dnr'],
               tei:history//tei:name[@role='dnr']
               )"/>
            <xsl:with-param name="processing_mode" select="'doc-level'"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:msContents/tei:summary//tei:name[@role='fmo']|tei:physDesc//tei:name[@role='fmo']|tei:history//tei:name[@role='fmo']">
         <xsl:call-template name="write-named-entity-object">
            <xsl:with-param name="map_key" select="'formerOwners'"/>
            <xsl:with-param name="label" select="'Former Owner(s)'"/>
            <xsl:with-param name="listDisplay" select="false()"/>
            <xsl:with-param name="seq" select="42"></xsl:with-param>
            <xsl:with-param name="array_nodes" select="(
               tei:msContents/tei:summary//tei:name[@role='fmo'],
               tei:physDesc//tei:name[@role='fmo'],
               tei:history//tei:name[@role='fmo']
               )"/>
            <xsl:with-param name="processing_mode" select="'doc-level'"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:msContents/tei:summary//tei:name[@role='rcp']|tei:physDesc//tei:name[@role='rcp']|tei:history//tei:name[@role='rcp']">
         <xsl:call-template name="write-named-entity-object">
            <xsl:with-param name="map_key" select="'recipients'"/>
            <xsl:with-param name="label" select="'Recipient(s)'"/>
            <xsl:with-param name="seq" select="42"></xsl:with-param>
            <xsl:with-param name="array_nodes" select="(
               tei:msContents/tei:summary//tei:name[@role='rcp'],
               tei:physDesc//tei:name[@role='rcp'],
               tei:history//tei:name[@role='rcp']
               )"/>
            <xsl:with-param name="processing_mode" select="'doc-level'"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:msContents/tei:summary//tei:name[@role='scr']|tei:physDesc//tei:name[@role='scr']|tei:history//tei:name[@role='scr']">
         <xsl:call-template name="write-named-entity-object">
            <xsl:with-param name="map_key" select="'scribes'"/>
            <xsl:with-param name="label" select="'Scribe(s)'"/>
            <xsl:with-param name="seq" select="42"></xsl:with-param>
            <xsl:with-param name="array_nodes" select="(
               tei:msContents/tei:summary//tei:name[@role='scr'],
               tei:physDesc//tei:name[@role='scr'],
               tei:history//tei:name[@role='scr']
               )"/>
            <xsl:with-param name="processing_mode" select="'doc-level'"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:msContents/tei:summary//tei:name[@role='oth' or not(@role) or not(@role=$rolemap/cudl:role/@code)]|tei:physDesc//tei:name[@role='oth' or not(@role) or not(@role=$rolemap/cudl:role/@code)]|tei:history//tei:name[@role='oth' or not(@role) or not(@role=$rolemap/cudl:role/@code)]">
         <xsl:call-template name="write-named-entity-object">
            <xsl:with-param name="map_key" select="'associated'"/>
            <xsl:with-param name="label" select="'Associated Name(s)'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="array_nodes" select="(
               tei:msContents/tei:summary//tei:name[@role='oth' or not(@role) or not(@role=$rolemap/cudl:role/@code)],
               tei:physDesc//tei:name[@role='oth' or not(@role) or not(@role=$rolemap/cudl:role/@code)],
               tei:history//tei:name[@role='oth' or not(@role) or not(@role=$rolemap/cudl:role/@code)]
               )"/>
            <xsl:with-param name="processing_mode" select="'doc-level'"/>
         </xsl:call-template>
      </xsl:if>
   </xsl:template>

   <xsl:template name="get-doc-and-item-names">
      <xsl:if test="ancestor-or-self::tei:teiHeader//tei:correspDesc//tei:correspAction[@type=('sent','received')]">
         <xsl:apply-templates  select="ancestor-or-self::tei:teiHeader//tei:correspDesc//tei:correspAction[@type=('sent','received')]"/>
      </xsl:if>

      <xsl:if test="tei:msContents/tei:summary//tei:name[@role='aut']|//tei:physDesc//tei:name[@role='aut']|tei:history//tei:name[@role='aut']|//tei:msContents/tei:msItem[1]/tei:author">
         <xsl:call-template name="write-named-entity-object">
            <xsl:with-param name="map_key" select="'authors'"/>
            <xsl:with-param name="label" select="'Author(s)'"/>
            <xsl:with-param name="seq" select="420"/>
            <xsl:with-param name="array_nodes" select="(
               tei:msContents/tei:summary//tei:name[@role='aut'],
               tei:physDesc//tei:name[@role='aut'],
               tei:history//tei:name[@role='aut'],
               tei:msContents/tei:msItem[1]/tei:author
               )"/>
            <xsl:with-param name="processing_mode" select="'doc-level'"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:msContents/tei:summary//tei:name[@role='dnr']|tei:physDesc//tei:name[@role='dnr']|tei:history//tei:name[@role='dnr']|tei:msContents/tei:msItem[1]/tei:editor[@role='dnr']">
         <xsl:call-template name="write-named-entity-object">
            <xsl:with-param name="map_key" select="'donors'"/>
            <xsl:with-param name="listDisplay" select="false()"/>
            <xsl:with-param name="label" select="'Donor(s)'"/>
            <xsl:with-param name="seq" select="420"></xsl:with-param>
            <xsl:with-param name="array_nodes" select="(
               tei:msContents/tei:summary//tei:name[@role='dnr'],
               tei:physDesc//tei:name[@role='dnr'],
               tei:history//tei:name[@role='dnr'],
               tei:msContents/tei:msItem[1]/tei:editor[@role='dnr']
               )"/>
            <xsl:with-param name="processing_mode" select="'doc-level'"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:msContents/tei:summary//tei:name[@role='fmo']|tei:physDesc//tei:name[@role='fmo']|tei:history//tei:name[@role='fmo']|tei:msContents/tei:msItem[1]/tei:editor[@role='fmo']">
         <xsl:call-template name="write-named-entity-object">
            <xsl:with-param name="map_key" select="'formerOwners'"/>
            <xsl:with-param name="label" select="'Former Owner(s)'"/>
            <xsl:with-param name="listDisplay" select="false()"/>
            <xsl:with-param name="seq" select="420"></xsl:with-param>
            <xsl:with-param name="array_nodes" select="(
               tei:msContents/tei:summary//tei:name[@role='fmo'],
               tei:physDesc//tei:name[@role='fmo'],
               tei:history//tei:name[@role='fmo'],
               tei:msContents/tei:msItem[1]/tei:editor[@role='fmo']
               )"/>
            <xsl:with-param name="processing_mode" select="'doc-level'"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:msContents/tei:summary//tei:name[@role='rcp']|tei:physDesc//tei:name[@role='rcp']|tei:history//tei:name[@role='rcp']|tei:msContents/tei:msItem[1]/tei:editor[@role='rcp']">
         <xsl:call-template name="write-named-entity-object">
            <xsl:with-param name="map_key" select="'recipients'"/>
            <xsl:with-param name="label" select="'Recipient(s)'"/>
            <xsl:with-param name="seq" select="420"></xsl:with-param>
            <xsl:with-param name="array_nodes" select="(
               tei:msContents/tei:summary//tei:name[@role='rcp'],
               tei:physDesc//tei:name[@role='rcp'],
               tei:history//tei:name[@role='rcp'],
               tei:msContents/tei:msItem[1]/tei:editor[@role='rcp']
               )"/>
            <xsl:with-param name="processing_mode" select="'doc-level'"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:msContents/tei:summary//tei:name[@role='scr']|tei:physDesc//tei:name[@role='scr']|tei:history//tei:name[@role='scr']|tei:msContents/tei:msItem[1]/tei:editor[@role='scr']">
         <xsl:call-template name="write-named-entity-object">
            <xsl:with-param name="map_key" select="'scribes'"/>
            <xsl:with-param name="label" select="'Scribe(s)'"/>
            <xsl:with-param name="seq" select="420"></xsl:with-param>
            <xsl:with-param name="array_nodes" select="(
               tei:msContents/tei:summary//tei:name[@role='scr'],
               tei:physDesc//tei:name[@role='scr'],
               tei:history//tei:name[@role='scr'],
               tei:msContents/tei:msItem[1]/tei:editor[@role='scr']
               )"/>
            <xsl:with-param name="processing_mode" select="'doc-level'"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="tei:msContents/tei:summary//tei:name[@role='oth' or not(@role) or not(@role=$rolemap/cudl:role/@code)]|tei:physDesc//tei:name[@role='oth' or not(@role) or not(@role=$rolemap/cudl:role/@code)]|tei:history//tei:name[@role='oth' or not(@role) or not(@role=$rolemap/cudl:role/@code)]|tei:msContents/tei:msItem[1]/tei:editor[@role='oth' or not(@role) or not(@role=$rolemap/cudl:role/@code)]">
         <xsl:call-template name="write-named-entity-object">
            <xsl:with-param name="map_key" select="'associated'"/>
            <xsl:with-param name="label" select="'Associated Name(s)'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="array_nodes" select="(
               tei:msContents/tei:summary//tei:name[@role='oth' or not(@role) or not(@role=$rolemap/cudl:role/@code)],
               tei:physDesc//tei:name[@role='oth' or not(@role) or not(@role=$rolemap/cudl:role/@code)],
               tei:history//tei:name[@role='oth' or not(@role) or not(@role=$rolemap/cudl:role/@code)],
               tei:msContents/tei:msItem[1]/tei:editor[@role='oth' or not(@role) or not(@role=$rolemap/cudl:role/@code)]
               )"/>
            <xsl:with-param name="processing_mode" select="'doc-level'"/>
         </xsl:call-template>
      </xsl:if>
   </xsl:template>

   <xsl:template name="get-item-names">
      <xsl:choose>
         <xsl:when test="ancestor-or-self::tei:teiHeader//tei:correspDesc//tei:correspAction[@type=('sent','received')]">
            <xsl:apply-templates select="ancestor-or-self::tei:teiHeader//tei:correspDesc//tei:correspAction[@type=('sent','received')]" />
         </xsl:when>
         <xsl:otherwise>
            <xsl:if test="tei:author">
               <xsl:call-template name="write-named-entity-object">
                  <xsl:with-param name="map_key" select="'authors'"/>
                  <xsl:with-param name="label" select="'Author(s)'"/>
                  <xsl:with-param name="seq" select="4200"></xsl:with-param>
                  <xsl:with-param name="array_nodes" select="tei:author"/>
               </xsl:call-template>
            </xsl:if>

            <xsl:if test="tei:editor[@role='dnr']">
               <xsl:call-template name="write-named-entity-object">
                  <xsl:with-param name="map_key" select="'donors'"/>
                  <xsl:with-param name="label" select="'Donor(s)'"/>
                  <xsl:with-param name="listDisplay" select="false()"/>
                  <xsl:with-param name="seq" select="4200"></xsl:with-param>
                  <xsl:with-param name="array_nodes" select="tei:editor[@role='dnr']"/>
               </xsl:call-template>
            </xsl:if>

            <xsl:if test="tei:editor[@role='fmo']">
               <xsl:call-template name="write-named-entity-object">
                  <xsl:with-param name="map_key" select="'formerOwners'"/>
                  <xsl:with-param name="label" select="'Former Owner(s)'"/>
                  <xsl:with-param name="seq" select="4200"></xsl:with-param>
                  <xsl:with-param name="array_nodes" select="tei:editor[@role='fmo']"/>
               </xsl:call-template>
            </xsl:if>

            <xsl:if test="tei:editor[@role='rcp']">
               <xsl:call-template name="write-named-entity-object">
                  <xsl:with-param name="map_key" select="'recipients'"/>
                  <xsl:with-param name="label" select="'Recipient(s)'"/>
                  <xsl:with-param name="seq" select="4200"></xsl:with-param>
                  <xsl:with-param name="array_nodes" select="tei:editor[@role='rcp']"/>
               </xsl:call-template>
            </xsl:if>

            <xsl:if test="tei:editor[@role='scr']">
               <xsl:call-template name="write-named-entity-object">
                  <xsl:with-param name="map_key" select="'scribes'"/>
                  <xsl:with-param name="label" select="'Scribe(s)'"/>
                  <xsl:with-param name="seq" select="4200"></xsl:with-param>
                  <xsl:with-param name="array_nodes" select="tei:editor[@role='scr']"/>
               </xsl:call-template>
            </xsl:if>

            <xsl:if test="tei:editor[@role='oth' or not(@role) or not(@role=$rolemap/cudl:role/@code)]">
               <xsl:call-template name="write-named-entity-object">
                  <xsl:with-param name="map_key" select="'associated'"/>
                  <xsl:with-param name="label" select="'Associated Name(s)'"/>
                  <xsl:with-param name="seq" select="1"/>
                  <xsl:with-param name="array_nodes" select="tei:editor[@role='oth' or not(@role) or not(@role=$rolemap/cudl:role/@code)]"/>
               </xsl:call-template>
            </xsl:if>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="tei:correspAction[@type='received']|tei:correspAction[@type='sent'][normalize-space(.)]">
      <xsl:variable name="object_name">
         <xsl:choose>
            <xsl:when test="@type=('recieved', 'received')"><!-- SHIM on mispelling -->
               <xsl:text>recipients</xsl:text>
            </xsl:when>
            <xsl:otherwise>authors</xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:variable name="object_label">
         <xsl:choose>
            <xsl:when test="@type=('recieved', 'received')"><!-- SHIM on mispelling -->
               <xsl:text>Recipient(s)</xsl:text>
            </xsl:when>
            <xsl:otherwise>Author(s)</xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <map key="{$object_name}" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:copy-of select="cudl:display(true())"/>
         <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="1"/>
         </number>
         <string key="listDisplay" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:text>unordered</xsl:text>
         </string>
         <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="$object_label"/>
         </string>
         <array key="value" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:apply-templates select="(tei:persName|tei:orgName|tei:name)[normalize-space(.)]"/>
         </array>
      </map>
   </xsl:template>

   <xsl:template match="tei:name[not(tei:persName)]" mode="#default doc-level"/>

   <xsl:template match="tei:name[tei:persName]" mode="#default" priority="2">
      <string key="linktype" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:text>keyword search</xsl:text>
      </string>
   </xsl:template>

   <xsl:template match="tei:name[tei:persName]" mode="doc-level" priority="2">
      <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:value-of select="1"/>
      </number>
      <string key="linktype" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:text>keyword search</xsl:text>
      </string>
   </xsl:template>

   <xsl:template match="tei:name[tei:persName]" mode="#default doc-level" priority="3">
      <map xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:copy-of select="cudl:display(true())"/>
         <xsl:variable name="additional-doc-level-items" as="item()*">
            <xsl:next-match/>
         </xsl:variable>
         <xsl:choose>
            <xsl:when test="tei:persName[@type='standard']">
               <xsl:for-each select="tei:persName[@type='standard']">
                  <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
                     <xsl:value-of select="normalize-space(.)"/>
                  </string>
                  <xsl:copy-of select="$additional-doc-level-items"/>
                  <string key="fullForm" xmlns="http://www.w3.org/2005/xpath-functions">
                     <xsl:value-of select="normalize-space(.)"/>
                  </string>
               </xsl:for-each>
               <xsl:choose>
                  <!-- if separate display form exists, use as short form -->
                  <xsl:when test="tei:persName[@type='display']">
                     <xsl:for-each select="tei:persName[@type='display']">
                        <string key="shortForm" xmlns="http://www.w3.org/2005/xpath-functions">
                           <xsl:value-of select="normalize-space(.)"/>
                        </string>
                     </xsl:for-each>
                  </xsl:when>
                  <!-- if no separate display form exists, use standard form as short form -->
                  <xsl:otherwise>
                     <xsl:for-each select="tei:persName[@type='standard']">
                        <string key="shortForm" xmlns="http://www.w3.org/2005/xpath-functions">
                           <xsl:value-of select="normalize-space(.)"/>
                        </string>
                     </xsl:for-each>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:when>
            <xsl:when test="tei:persName[@type='display']">
               <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="normalize-space(tei:persName[@type='display'][1])"/>
               </string>
               <xsl:copy-of select="$additional-doc-level-items"/>
               <string key="shortForm" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="normalize-space(tei:persName[@type='display'][1])"/>
               </string>
            </xsl:when>
            <xsl:otherwise>
               <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="normalize-space(tei:persName[1])"/>
               </string>
               <xsl:copy-of select="$additional-doc-level-items"/>
               <string key="shortForm" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="normalize-space(tei:persName[1])"/>
               </string>
            </xsl:otherwise>
         </xsl:choose>

         <xsl:for-each select="@type">
            <string key="type" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="normalize-space(.)"/>
            </string>
         </xsl:for-each>

         <xsl:for-each select="@role">
            <string key="role" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="normalize-space(.)"/>
            </string>
         </xsl:for-each>

         <xsl:for-each select="@key[contains(., 'person_v')]">
            <string key="authority" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:text>VIAF</xsl:text>
            </string>
            <string key="authorityURI" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:text>http://viaf.org/</xsl:text>
            </string>

            <!-- NB: Some files, like Sanskrit MS-OR-02339, might have multiple VIAF_* tokens. For now, just use first, but should maybe handle multiple -->
            <xsl:for-each select="tokenize(normalize-space(.), ' ')[starts-with(., 'person_v')][1]">
               <string key="valueURI" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="concat('http://viaf.org/viaf/', substring-after(.,'person_v'))"/>
               </string>
            </xsl:for-each>
         </xsl:for-each>
      </map>
   </xsl:template>

   <xsl:template
      match="tei:author|tei:correspAction/tei:*[self::tei:persName|self::tei:orgName|self::tei:name]|tei:editor" mode="#default doc-level">
      <map xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:copy-of select="cudl:display(true())"/>
         <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="normalize-space(.)"/>
         </string>
         <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="1"/>
         </number>
         <string key="linktype" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:text>keyword search</xsl:text>
         </string>
         <string key="fullForm" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="normalize-space(.)"/>
         </string>
         <string key="shortForm" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="normalize-space(.)"/>
         </string>

         <xsl:for-each select="@type">
            <string key="type" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="normalize-space(.)"/>
            </string>
         </xsl:for-each>

         <xsl:variable name="role" as="xsd:string*">
            <xsl:choose>
               <xsl:when test="self::tei:editor[@role]">
                  <xsl:value-of select="normalize-space(@role)"/>
               </xsl:when>
               <xsl:when test="self::tei:editor[not(@role)]"/>
               <xsl:when test="ancestor::tei:correspAction[@type='received']">
                  <xsl:text>rcp</xsl:text>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:text>aut</xsl:text>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>

         <xsl:if test="$role != ''">
            <string key="role" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:value-of select="$role"/>
            </string>
         </xsl:if>

         <xsl:for-each select="@key[contains(., 'person_v')]">
            <string key="authority" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:text>VIAF</xsl:text>
            </string>
            <string key="authorityURI" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:text>http://viaf.org/</xsl:text>
            </string>

            <!-- NB: Some files, like Sanskrit MS-OR-02339, might have multiple VIAF_* tokens. For now, just use first, but should maybe handle multiple -->
            <xsl:for-each select="tokenize(normalize-space(.), ' ')[starts-with(., 'person_v')][1]">
               <string key="valueURI" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="concat('http://viaf.org/viaf/', substring-after(.,'person_v'))"/>
               </string>
            </xsl:for-each>
         </xsl:for-each>
      </map>
   </xsl:template>

   <xsl:template name="get-languages">
      <xsl:param name="level" select="'doc'"/>

      <xsl:variable name="language-elems" as="item()*">
         <xsl:choose>
            <xsl:when test="not($level = ('doc', 'item'))"/>
            <xsl:when test="$level = 'doc' and tei:msContents/tei:textLang">
               <xsl:copy-of select="tei:msContents/tei:textLang"/>
            </xsl:when>
            <xsl:when test="$level = 'item' and tei:textLang">
               <xsl:copy-of select="tei:textLang"/>
            </xsl:when>
            <xsl:otherwise>
               <!-- If doc or item doesn't have required node, take the following -->
               <xsl:copy-of select="ancestor-or-self::tei:teiHeader[1]//tei:langUsage/tei:language"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:if test="$language-elems[exists((@mainLang,@ident)[normalize-space(.)])]">
         <array key="languageCodes" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:for-each select="$language-elems[exists((@mainLang,@ident)[normalize-space(.)])]">
               <xsl:variable name="lang_code" select="(@mainLang,@ident)[normalize-space(.)][1]"/>
               <string xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="normalize-space($lang_code)"/>
               </string>
            </xsl:for-each>
         </array>
      </xsl:if>

      <xsl:if test="if ($level eq 'doc') then $language-elems else $language-elems[normalize-space(.)]">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'languageStrings'"/>
            <xsl:with-param name="displayFormIter" select="$language-elems[normalize-space(.)]"/>
            <xsl:with-param name="label" select="'Language(s)'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="seq2" select="2"/>
         </xsl:call-template>
      </xsl:if>
   </xsl:template>

   <xsl:template name="get-doc-metadata">
      <xsl:if test="normalize-space(tei:additional/tei:adminInfo/tei:recordHist/tei:source)">
         <xsl:variable name="dataSource">
            <xsl:apply-templates select="tei:additional/tei:adminInfo/tei:recordHist/tei:source" mode="html"/>
         </xsl:variable>

         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'dataSources'"/>
            <xsl:with-param name="displayFormIter" select="normalize-space($dataSource)"/>
            <xsl:with-param name="label" select="'Data Source(s)'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="seq2" select="1"/>
         </xsl:call-template>
      </xsl:if>

      <xsl:if test="normalize-space(//tei:revisionDesc)">
         <map key="dataRevisions" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:variable name="dataRevisions">
               <xsl:value-of select="distinct-values(//tei:revisionDesc/tei:change/tei:*[self::tei:persName|self::tei:name|self::tei:orgName][normalize-space(.)])" separator=", "/>
            </xsl:variable>

            <xsl:call-template name="write-data-obj-flat">
               <xsl:with-param name="seq" select="1"/>
               <xsl:with-param name="displayForm" select="normalize-space($dataRevisions)"/>
               <xsl:with-param name="label" select="'Author(s) of the Record'"/>
               <xsl:with-param name="displayNull" select="true()"/>
            </xsl:call-template>
         </map>
      </xsl:if>
   </xsl:template>

   <xsl:template match="tei:facsimile/tei:surface" mode="count">
      <xsl:number format="1" level="any" count="tei:facsimile/tei:surface"/>
   </xsl:template>

   <xsl:template name="make-pages">
      <xsl:variable name="html_dir" select="string-join(tokenize(cudl:construct-output-filename-path(.,'',concat('i',position()), ''), '/')[position() lt last()], '/')"/>

      <array key="pages" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:choose>
            <xsl:when test="//tei:facsimile/tei:surface">
               <xsl:for-each select="//tei:facsimile/tei:surface">
                     <xsl:variable name="surface-elem" select="."/>
                     <xsl:variable name="label" select="normalize-space(@n)"/>
                  <map xmlns="http://www.w3.org/2005/xpath-functions">
                     <string key="id" xmlns="http://www.w3.org/2005/xpath-functions">
                        <xsl:value-of select="concat($fileID, '-', string(position()))"/>
                     </string>
                     <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
                        <xsl:value-of select="$label"/>
                     </string>

                     <string key="physID" xmlns="http://www.w3.org/2005/xpath-functions">
                        <xsl:value-of select="concat('PHYS-',position())"/>
                     </string>

                     <number key="sequence" xmlns="http://www.w3.org/2005/xpath-functions">
                        <xsl:value-of select="position()"/>
                     </number>
                     <string key="itemURL" xmlns="http://www.w3.org/2005/xpath-functions">
                        <xsl:value-of select="string-join(($fileID, string(position()))[normalize-space(.)], '/')"/>
                     </string>

                     <xsl:variable name="imageUrl" select="normalize-space(tei:graphic[contains(@decls, '#download')]/@url)"/>
                     <xsl:variable name="thumbnailOrientation" select="normalize-space(tei:graphic[contains(@decls, '#download')]/@rend)"/>

                     <xsl:variable name="imageWidth" select="replace(normalize-space(tei:graphic[contains(@decls, '#download')]/@width), 'px', '')"/>

                     <xsl:variable name="imageHeight" select="replace(normalize-space(tei:graphic[contains(@decls, '#download')]/@height), 'px', '')"/>

                     <string key="IIIFImageURL" xmlns="http://www.w3.org/2005/xpath-functions">
                        <xsl:value-of select="$imageUrl"/>
                     </string>

                     <string key="thumbnailImageOrientation" xmlns="http://www.w3.org/2005/xpath-functions">
                        <xsl:value-of select="$thumbnailOrientation"/>
                     </string>

                     <number key="imageWidth" xmlns="http://www.w3.org/2005/xpath-functions">
                        <xsl:choose>
                           <xsl:when test="normalize-space($imageWidth)">
                              <xsl:value-of select="$imageWidth"/>
                           </xsl:when>
                           <xsl:otherwise>
                              <xsl:text>0</xsl:text>
                           </xsl:otherwise>
                        </xsl:choose>
                     </number>

                     <number key="imageHeight" xmlns="http://www.w3.org/2005/xpath-functions">
                        <xsl:choose>
                           <xsl:when test="normalize-space($imageHeight)">
                              <xsl:value-of select="$imageHeight"/>
                           </xsl:when>
                           <xsl:otherwise>
                              <xsl:text>0</xsl:text>
                           </xsl:otherwise>
                        </xsl:choose>
                     </number>

                     <xsl:if test="normalize-space(tei:media[@mimeType='transcription_diplomatic']/@url)">
                        <string key="transcriptionDiplomaticURL" xmlns="http://www.w3.org/2005/xpath-functions">
                           <xsl:value-of select="normalize-space(replace(tei:media[@mimeType='transcription_diplomatic']/@url, 'http://services.cudl.lib.cam.ac.uk',''))"/>
                        </string>
                     </xsl:if>

                     <xsl:if test="normalize-space(tei:media[@mimeType='transcription_normalised']/@url)">
                        <string key="transcriptionNormalisedURL" xmlns="http://www.w3.org/2005/xpath-functions">
                           <xsl:value-of select="replace(tei:media[@mimeType='transcription_normalised']/@url, 'http://services.cudl.lib.cam.ac.uk','')"/>
                        </string>
                     </xsl:if>

                     <xsl:if test="normalize-space(tei:media[@mimeType='translation']/@url)">
                        <string key="translationURL" xmlns="http://www.w3.org/2005/xpath-functions">
                           <xsl:value-of select="replace(tei:media[@mimeType='translation']/@url, 'http://services.cudl.lib.cam.ac.uk','')"/>
                        </string>
                     </xsl:if>

                     <xsl:variable name="isLast" select="string(position()=last())"/>

                     <xsl:choose>
                        <xsl:when test="tei:media[contains(@mimeType,'transcription')]">
                           <!-- TODO Transcription not embeded because it's only available via API
                                     Convert to in-house TEI and remove all these shims?
                           -->
                           <map key="transcription_content" xmlns="http://www.w3.org/2005/xpath-functions">
                              <boolean key="pageHasTranscription" xmlns="http://www.w3.org/2005/xpath-functions">
                                 <xsl:value-of select="true()"/>
                              </boolean>
                           </map>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:variable name="transcription_container" select="//tei:text/tei:body/tei:div[not(@type)]" as="item()*" />

                           <!--<xsl:if test="exists($transcription_container)">-->
                              <xsl:variable name="transcription_pb" select="(
                                 key('pbNs', $label)[@type='pageBoundary'][ancestor::tei:div[not(@type)]/parent::tei:body],
                                 key('pbNs', $label)[ancestor::tei:div[not(@type)]/parent::tei:body][lambda:has-valid-context(.)]
                                 )[1]" as="item()*"/>
                              <xsl:if test="exists($transcription_pb[ancestor::tei:div[@decls='#unpaginated']]) and exists($transcription_pb/ancestor::tei:div[@decls='#unpaginated']//tei:pb[lambda:has-valid-context(.)][position() gt 1][. is $transcription_pb ])">
                                 <boolean key="unpaginatedAdditionalPb" xmlns="http://www.w3.org/2005/xpath-functions">
                                    <xsl:value-of select="false()"/>
                                 </boolean>
                              </xsl:if>
                           <xsl:choose>
                              <xsl:when test="exists($transcription_pb)">
                                 <xsl:for-each select="$transcription_pb">
                                    <xsl:call-template name="output-html-link">
                                       <xsl:with-param name="current_pb" select="."/>
                                       <xsl:with-param name="isLast" select="$isLast"/>
                                       <xsl:with-param name="label" select="$label"/>
                                       <xsl:with-param name="type" select="'transcription'"/>
                                       <xsl:with-param name="html_dir" select="$html_dir"/>
                                    </xsl:call-template>
                                 </xsl:for-each>
                              </xsl:when>
                              <xsl:otherwise>

                                 <map key="transcription_content" xmlns="http://www.w3.org/2005/xpath-functions">
                                    <boolean key="pageHasTranscription" xmlns="http://www.w3.org/2005/xpath-functions">
                                       <xsl:value-of select="false()"/>
                                    </boolean>
                                 </map>
                              </xsl:otherwise>
                           </xsl:choose>
                           <!--</xsl:if>-->
                        </xsl:otherwise>
                     </xsl:choose>

                     <xsl:variable name="translation_container" select="//tei:text/tei:body/tei:div[@type='translation']" as="item()*"/>

                     <!--<xsl:if test="exists($translation_container)">-->
                        <xsl:variable name="translation_pb" select="(
                           key('pbNs', $label)[@type='pageBoundary'][ancestor::tei:div[@type='translation']/parent::tei:body],
                           key('pbNs', $label)[ancestor::tei:div[@type='translation']/parent::tei:body][not(@type='pageBoundary')]
                           )[1]" as="item()*"/>
                     <xsl:choose>
                        <xsl:when test="exists($translation_pb)">
                           <xsl:for-each select="$translation_pb">
                              <xsl:call-template name="output-html-link">
                                 <xsl:with-param name="current_pb" select="."/>
                                 <xsl:with-param name="isLast" select="$isLast"/>
                                 <xsl:with-param name="label" select="$label"/>
                                 <xsl:with-param name="type" select="'translation'"/>
                                 <xsl:with-param name="html_dir" select="$html_dir"/>
                              </xsl:call-template>
                           </xsl:for-each>
                        </xsl:when>
                        <xsl:otherwise>
                           <map key="translation_content" xmlns="http://www.w3.org/2005/xpath-functions">
                              <xsl:message select="parent::tei:surface"></xsl:message>
                              <boolean key="pageHasTranslation" xmlns="http://www.w3.org/2005/xpath-functions">
                                 <xsl:choose>
                                    <xsl:when test="tei:media[@mimeType='translation']">
                                       <xsl:value-of select="true()"/>

                                    </xsl:when>
                                    <xsl:otherwise>
                                       <xsl:value-of select="false()"/>
                                    </xsl:otherwise>
                                 </xsl:choose>
                              </boolean>
                           </map>
                        </xsl:otherwise>
                     </xsl:choose>
                     <!--</xsl:if>-->
                  </map>
                  </xsl:for-each>
               </xsl:when>
            <xsl:otherwise>
               <map xmlns="http://www.w3.org/2005/xpath-functions">
                  <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
                     <xsl:text>cover</xsl:text>
                  </string>

                  <string key="physID" xmlns="http://www.w3.org/2005/xpath-functions">
                     <xsl:text>PHYS-1</xsl:text>
                  </string>

                  <number key="sequence" xmlns="http://www.w3.org/2005/xpath-functions">
                     <xsl:value-of select="1"/>
                  </number>
               </map>
            </xsl:otherwise>
         </xsl:choose>
      </array>
   </xsl:template>

   <xsl:template name="output-html-link">
      <xsl:param name="current_pb" as="item()*"/>
      <xsl:param name="isLast"/>
      <xsl:param name="label"/>
      <xsl:param name="type" as="xsd:string*"/>
      <xsl:param name="html_dir"/>


      <xsl:variable name="filename" select="lambda:construct-output-filename-path($current_pb, 'filename', $type)"/>
      <xsl:variable name="html_file" select="concat(string-join(($html_dir, $filename),'/'), '.html')"/>

      <xsl:variable name="surface_number">
         <xsl:apply-templates select="key('surfaceIDs', $current_pb/@facs)" mode="count"/>
      </xsl:variable>

      <!-- Do not ouput if pb[position() gt 1][ancestor::div[@decls='#unpaginated']] -->
      <!-- not($current_pb is (tei:div[@decls='unpaginated']//tei:pb)[position() gt 1]) -->

      <xsl:choose>
         <xsl:when test="unparsed-text-available($html_file)">
            <map key="{$type}_content" xmlns="http://www.w3.org/2005/xpath-functions">
               <boolean key="pageHas{cudl:capitalise-first($type)}" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="true()"/>
               </boolean>
               <string key="filename" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="replace(tokenize($html_file,'/')[last()],'\.html$','')"/>
               </string>
               <string key="fullpath" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="replace($html_file, concat($clean_dest_dir, '/*'), '')"/>
               </string>
               <string key="surfaceID" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="concat('i',$surface_number)"/>
               </string>
               <string key="text" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="unparsed-text($html_file)"/>
               </string>
            </map>
            <xsl:choose>
               <xsl:when test="$isLast = 'true' and count(following::*) = 0"/>
               <!--when there's no content between here and the next pb element do nothing-->
               <xsl:when test="not(key('surfaceIDs', $current_pb/@facs))">
                  <xsl:message select="concat('ERROR: ', $fileID, ' has invalid pb/@facs or surface/@xml:id: ''', $current_pb/@facs, '''')"/>
               </xsl:when>
               <xsl:when test="local-name(following-sibling::*[1]) = 'pb' and not(ancestor::tei:div[tokenize(normalize-space(@decls), '\s+')[. = '#unpaginated']])"/>
               <xsl:otherwise>
                  <xsl:choose>
                     <xsl:when test="$type='transcription'">
                        <xsl:variable name="encoded-label" select="replace($label, ' ', '%20')"/>

                        <string key="transcriptionDiplomaticURL" xmlns="http://www.w3.org/2005/xpath-functions">
                           <xsl:value-of select="lambda:write-tei-services-link(., 'html_transcription')"/>
                        </string>
                        <string key="pageXMLTranscriptionURL" xmlns="http://www.w3.org/2005/xpath-functions">
                           <xsl:value-of select="lambda:write-tei-services-link(., 'page_xml_transcription')"/>
                        </string>
                     </xsl:when>
                     <xsl:when test="$type='translation'">
                        <string key="translationURL" xmlns="http://www.w3.org/2005/xpath-functions">
                           <xsl:value-of select="lambda:write-tei-services-link(.,'html_translation')"/>
                        </string>
                        <string key="pageXMLTranslationURL" xmlns="http://www.w3.org/2005/xpath-functions">
                           <xsl:value-of select="lambda:write-tei-services-link(., 'page_xml_translation')"/>
                        </string>
                     </xsl:when>
                  </xsl:choose>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:when>
         <xsl:otherwise>
            <map key="{$type}_content" xmlns="http://www.w3.org/2005/xpath-functions">
               <boolean key="pageHas{cudl:capitalise-first($type)}" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="false()"/>
               </boolean>
            </map>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <!--LIST ITEM PAGES - passing through for indexing-->
   <xsl:template name="make-list-item-pages">
      <array key="listItemPages" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:for-each select="//tei:list/tei:item[tei:locus]">
            <map xmlns="http://www.w3.org/2005/xpath-functions">
               <string key="fileID" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="$fileID"/>
               </string>
               <string key="dmdID" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:text>DOCUMENT</xsl:text>
               </string>

               <xsl:variable name="startPageLabel" select="tei:locus[1]/@from"/>

               <xsl:variable name="startPagePosition">
                  <xsl:choose>
                      <xsl:when test="key('surfaceNs', $startPageLabel)">
                         <xsl:apply-templates select="key('surfaceNs', $startPageLabel)" mode="count"/>
                      </xsl:when>
                     <xsl:otherwise>
                        <xsl:value-of select="1"/>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:variable>

               <string key="startPageLabel" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="$startPageLabel"/>
               </string>

               <number key="startPage" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="$startPagePosition"/>
               </number>

               <string key="title" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="$startPageLabel"/>
               </string>

               <string key="listItemText" xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="normalize-space(.)"/>
               </string>
            </map>
         </xsl:for-each>
      </array>
   </xsl:template>

   <xsl:template name="make-logical-structure">
      <array key="logicalStructures" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:apply-templates select="tei:TEI/tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:msDesc" mode="logicalstructure"/>
      </array>
   </xsl:template>

   <xsl:template match="tei:msDesc" mode="logicalstructure">
      <map xmlns="http://www.w3.org/2005/xpath-functions">
         <string key="descriptiveMetadataID" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="'DOCUMENT'"/>
         </string>

         <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:choose>
               <!--general titles take precedence-->
               <xsl:when test="tei:head">
                  <xsl:value-of select="normalize-space(tei:head)"/>
               </xsl:when>
               <xsl:when test="tei:msIdentifier/tei:msName">
                  <xsl:value-of select="normalize-space(tei:msIdentifier/tei:msName)"/>
               </xsl:when><!--then titles in the first msItem-->
               <xsl:when test="normalize-space(tei:msContents/tei:msItem[1]/tei:title[not(@type)][1])">
                  <xsl:value-of select="normalize-space(tei:msContents/tei:msItem[1]/tei:title[not(@type)][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(tei:msContents/tei:msItem[1]/tei:title[@type='general'][1])">
                  <xsl:value-of select="normalize-space(tei:msContents/tei:msItem[1]/tei:title[@type='general'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(tei:msContents/tei:msItem[1]/tei:title[@type='desc'][1])">
                  <xsl:value-of select="normalize-space(tei:msContents/tei:msItem[1]/tei:title[@type='desc'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(tei:msContents/tei:msItem[1]/tei:title[@type='standard'][1])">
                  <xsl:value-of select="normalize-space(tei:msContents/tei:msItem[1]/tei:title[@type='standard'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(tei:msContents/tei:msItem[1]/tei:title[@type='supplied'][1])">
                  <xsl:value-of select="normalize-space(tei:msContents/tei:msItem[1]/tei:title[@type='supplied'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(tei:msContents/tei:msItem[1]/tei:rubric)">
                  <xsl:variable name="rubric_title">
                     <xsl:apply-templates select="tei:msContents/tei:msItem[1]/tei:rubric" mode="title"/>
                  </xsl:variable>
                  <xsl:value-of select="normalize-space($rubric_title)"/>
               </xsl:when>
               <xsl:when test="normalize-space(tei:msContents/tei:msItem[1]/tei:incipit)">
                  <xsl:variable name="incipit_title">
                     <xsl:apply-templates select="tei:msContents/tei:msItem[1]/tei:incipit" mode="title"/>
                  </xsl:variable>
                  <xsl:value-of select="normalize-space($incipit_title)"/>
               </xsl:when>
               <!--then titles from the summary-->
               <xsl:when test="tei:msContents/tei:summary//tei:title[not(@type)]">
                  <xsl:for-each-group select="tei:msContents/tei:summary//tei:title[not(@type)]" group-by="normalize-space(.)">
                     <xsl:value-of select="normalize-space(.)"/>
                     <xsl:if test="not(position()=last())">
                        <xsl:text>, </xsl:text>
                     </xsl:if>
                  </xsl:for-each-group>
               </xsl:when>
               <!--then classmark-->
               <xsl:when test="tei:msIdentifier/tei:idno">
                  <xsl:for-each-group select="tei:msIdentifier/tei:idno" group-by="normalize-space(.)">
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
         </string>

         <string key="startPageLabel" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:choose>
               <xsl:when test="//tei:facsimile/tei:surface">
                  <xsl:value-of select="//tei:facsimile/tei:surface[1]/@n"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:text>cover</xsl:text>
               </xsl:otherwise>
            </xsl:choose>
         </string>

         <number key="startPagePosition" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="1"/>
         </number>

         <string key="startPageID" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="'PHYS-1'"/>
         </string>

         <string key="endPageLabel" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:choose>
               <xsl:when test="//tei:facsimile/tei:surface">
                  <xsl:value-of select="//tei:facsimile/tei:surface[last()]/@n"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:text>cover</xsl:text>
               </xsl:otherwise>
            </xsl:choose>
         </string>

         <number key="endPagePosition" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:choose>
               <xsl:when test="//tei:facsimile/tei:surface">
                  <xsl:value-of select="count(//tei:facsimile/tei:surface)"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:value-of select="1"/>
               </xsl:otherwise>
            </xsl:choose>
         </number>

         <xsl:if test="(count(tei:msContents/tei:msItem) = 1 and tei:msContents/tei:msItem/tei:msItem) or count(tei:msContents/tei:msItem) > 1 or tei:msPart">
            <array key="children" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:choose>
                  <xsl:when test="count(tei:msContents/tei:msItem) = 1">
                     <xsl:apply-templates select="tei:msContents/tei:msItem/tei:msItem" mode="logicalstructure"/>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:apply-templates select="tei:msContents/tei:msItem" mode="logicalstructure"/>
                  </xsl:otherwise>
               </xsl:choose>
               <xsl:apply-templates select="tei:msPart" mode="logicalstructure"/>
            </array>
         </xsl:if>
      </map>
   </xsl:template>


   <xsl:template match="tei:msPart" mode="logicalstructure">
      <map xmlns="http://www.w3.org/2005/xpath-functions">
         <string key="descriptiveMetadataID" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:variable name="n-tree" select="string(sum((count(ancestor-or-self::*[self::tei:msPart]), count(preceding::*[self::tei:msPart]))))"/>
            <xsl:value-of select="concat('PART-', normalize-space($n-tree))"/>
         </string>

         <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:variable name="mspart_title">
               <xsl:choose>
                  <!--general titles take precedence-->
                  <xsl:when test="tei:head">
                     <xsl:value-of select="normalize-space(tei:head)"/>
                  </xsl:when>
                  <xsl:when test="tei:msIdentifier/tei:msName">
                     <xsl:value-of select="normalize-space(tei:msIdentifier/tei:msName)"/>
                  </xsl:when>
                  <!--then titles in the first msItem-->
                  <xsl:when test="normalize-space(tei:msContents/tei:msItem[1]/tei:title[not(@type)][1])">
                     <xsl:value-of select="normalize-space(tei:msContents/tei:msItem[1]/tei:title[not(@type)][1])"/></xsl:when>
                  <xsl:when test="normalize-space(tei:msContents/tei:msItem[1]/tei:title[@type='general'][1])">
                     <xsl:value-of select="normalize-space(tei:msContents/tei:msItem[1]/tei:title[@type='general'][1])"/>
                  </xsl:when>
                  <xsl:when test="normalize-space(tei:msContents/tei:msItem[1]/tei:title[@type='desc'][1])">
                     <xsl:value-of select="normalize-space(tei:msContents/tei:msItem[1]/tei:title[@type='desc'][1])"/>
                  </xsl:when>
                  <xsl:when test="normalize-space(tei:msContents/tei:msItem[1]/tei:title[@type='standard'][1])">
                     <xsl:value-of select="normalize-space(tei:msContents/tei:msItem[1]/tei:title[@type='standard'][1])"/>
                  </xsl:when>
                  <xsl:when test="normalize-space(tei:msContents/tei:msItem[1]/tei:title[@type='supplied'][1])">
                     <xsl:value-of select="normalize-space(tei:msContents/tei:msItem[1]/tei:title[@type='supplied'][1])"/>
                  </xsl:when>
                  <xsl:when test="normalize-space(tei:msContents/tei:msItem[1]/tei:rubric)">
                     <xsl:variable name="rubric_title">
                        <xsl:apply-templates select="tei:msContents/tei:msItem[1]/tei:rubric" mode="title"/>
                     </xsl:variable>
                     <xsl:value-of select="normalize-space($rubric_title)"/>
                  </xsl:when>
                  <xsl:when test="normalize-space(tei:msContents/tei:msItem[1]/tei:incipit)">
                     <xsl:variable name="incipit_title">
                        <xsl:apply-templates select="tei:msContents/tei:msItem[1]/tei:incipit" mode="title"/>
                     </xsl:variable>
                     <xsl:value-of select="normalize-space($incipit_title)"/>
                  </xsl:when>
                  <!--then titles from the summary-->
                  <xsl:when test="tei:msContents/tei:summary//tei:title[not(@type)]">
                     <xsl:for-each-group select="tei:msContents/tei:summary//tei:title[not(@type)]"
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
                  <xsl:value-of select="normalize-space(concat(tei:msIdentifier/tei:idno, ': ', $mspart_title))"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:value-of select="normalize-space(tei:msIdentifier/tei:idno)"/>
               </xsl:otherwise></xsl:choose>
         </string>

         <xsl:variable name="startPageLabel">
               <xsl:choose>
                  <xsl:when test="tei:msContents/tei:msItem[1]/tei:locus[1][normalize-space(@from)]">
                     <xsl:value-of select="tei:msContents/tei:msItem[1]/tei:locus[1]/normalize-space(@from)"/>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:choose>
                        <xsl:when test="//tei:facsimile/tei:surface">
                           <xsl:value-of select="//tei:facsimile/tei:surface[1]/@n"/>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:text>cover</xsl:text>
                        </xsl:otherwise>
                     </xsl:choose>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:variable>

         <string key="startPageLabel" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="$startPageLabel"/>
         </string>

         <xsl:variable name="startPagePosition">
            <xsl:choose>
               <xsl:when test="key('surfaceNs', $startPageLabel)">
                  <xsl:apply-templates select="key('surfaceNs', $startPageLabel)" mode="count"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:value-of select="1"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>

         <number key="startPagePosition" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="$startPagePosition"/>
         </number>

         <string key="startPageID" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="concat('PHYS-',string($startPagePosition))"/>
         </string>

         <xsl:variable name="endPageLabel">
            <xsl:choose>
               <xsl:when test="tei:msContents/tei:msItem[last()]/tei:locus[1][normalize-space(@to)]">
                  <xsl:value-of select="tei:msContents/tei:msItem[last()]/tei:locus[1]/normalize-space(@to)"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:choose>
                     <xsl:when test="//tei:facsimile/tei:surface">
                        <xsl:value-of select="//tei:facsimile/tei:surface[last()]/@n"/>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:text>cover</xsl:text>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>

         <string key="endPageLabel" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="$endPageLabel"/>
         </string>

         <number key="endPagePosition" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:choose>
               <xsl:when test="key('surfaceNs', $endPageLabel)">
                  <xsl:apply-templates select="key('surfaceNs', $endPageLabel)" mode="count"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:value-of select="1"/>
               </xsl:otherwise>
            </xsl:choose>
         </number>

         <array key="children" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:choose>
                  <xsl:when test="count(tei:msContents/tei:msItem) = 1">
                     <xsl:apply-templates select="tei:msContents/tei:msItem/tei:msItem" mode="logicalstructure"/>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:apply-templates select="tei:msContents/tei:msItem" mode="logicalstructure"/>
                  </xsl:otherwise>
               </xsl:choose>
            <xsl:apply-templates select="tei:msPart" mode="logicalstructure"/>
         </array>
      </map>
   </xsl:template>


   <xsl:template match="tei:msItem" mode="logicalstructure">
      <map xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:variable name="n-tree" select="string(sum((count(ancestor-or-self::*[self::tei:msItem]), count(preceding::*[self::tei:msItem]))))"/>

         <string key="descriptiveMetadataID" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="concat('ITEM-', normalize-space($n-tree))"/>
         </string>

         <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:choose>
               <xsl:when test="normalize-space(tei:title[not(@type)][1])">
                  <xsl:value-of select="normalize-space(tei:title[not(@type)][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(tei:title[@type='general'][1])">
                  <xsl:value-of select="normalize-space(tei:title[@type='general'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(tei:title[@type='desc'][1])">
                  <xsl:value-of select="normalize-space(tei:title[@type='desc'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(tei:title[@type='standard'][1])">
                  <xsl:value-of select="normalize-space(tei:title[@type='standard'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(tei:title[@type='supplied'][1])">
                  <xsl:value-of select="normalize-space(tei:title[@type='supplied'][1])"/>
               </xsl:when>
               <xsl:when test="normalize-space(tei:rubric[1])">
                  <xsl:variable name="rubric_title">
                     <xsl:apply-templates select="tei:rubric[1]" mode="title"/>
                  </xsl:variable>
                  <xsl:value-of select="normalize-space($rubric_title)"/>
               </xsl:when>
               <xsl:when test="normalize-space(tei:incipit[1])">
                  <xsl:variable name="incipit_title">
                     <xsl:apply-templates select="tei:incipit[1]" mode="title"/>
                  </xsl:variable>
                  <xsl:value-of select="normalize-space($incipit_title)"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:text>Untitled Item</xsl:text>
               </xsl:otherwise>
            </xsl:choose>
         </string>

         <xsl:variable name="startPageLabel">
            <xsl:choose>
               <xsl:when test="tei:locus[normalize-space(@from)]">
                  <xsl:value-of select="tei:locus[1]/normalize-space(@from)"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:choose>
                     <xsl:when test="//tei:facsimile/tei:surface">
                        <xsl:value-of select="//tei:facsimile/tei:surface[1]/@n"/>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:text>cover</xsl:text>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>

         <string key="startPageLabel" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="$startPageLabel"/>
         </string>

         <xsl:variable name="startPagePosition">
            <xsl:choose>
               <xsl:when test="key('surfaceNs', $startPageLabel)">
                   <xsl:apply-templates select="key('surfaceNs', $startPageLabel)" mode="count"/>
               </xsl:when>
               <xsl:otherwise>
                   <xsl:message select="concat('ERROR: ', $fileID, ' has invalid locus/@from or surface/@n value: ''', $startPageLabel, '''')"/>
                  <xsl:value-of select="1"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>

         <number key="startPagePosition" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="$startPagePosition"/>
         </number>

         <string key="startPageID" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="concat('PHYS-',$startPagePosition)"/>
         </string>

         <xsl:variable name="endPageLabel">
            <xsl:choose>
               <xsl:when test="tei:locus/@to">
                  <xsl:value-of select="tei:locus[1]/normalize-space(@to)"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:choose>
                     <xsl:when test="//tei:facsimile/tei:surface">
                        <xsl:value-of select="//tei:facsimile/tei:surface[last()]/@n"/>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:text>cover</xsl:text>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>

         <string key="endPageLabel" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="$endPageLabel"/>
         </string>

         <number key="endPagePosition" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:choose>
               <xsl:when test="key('surfaceNs', $endPageLabel)">
                  <xsl:apply-templates select="key('surfaceNs', $endPageLabel)" mode="count"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:message select="concat('ERROR: ', $fileID, ' has invalid locus/@to or surface/@n value: ''', $endPageLabel, '''')"/>
                  <xsl:value-of select="1"/>
               </xsl:otherwise>
            </xsl:choose>
         </number>

         <xsl:if test="tei:msItem">
            <array key="children" xmlns="http://www.w3.org/2005/xpath-functions">
               <xsl:apply-templates select="tei:msItem" mode="logicalstructure"/>
            </array>
         </xsl:if>
      </map>
   </xsl:template>

   <xsl:template match="tei:p" mode="html">
      <xsl:text>&lt;p&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/p&gt;</xsl:text>
   </xsl:template>

   <!--allows creation of paragraphs in summary (a bit of a cheat - TEI doesn't allow p tags here so we use seg and process into p)-->
   <!--this is necessary to allow collapse to first paragraph in interface-->
   <xsl:template match="tei:seg[@type='para']|tei:abstract/tei:p" mode="html">
      <xsl:text>&lt;p style=&apos;text-align: justify;&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="#current"/>
      <xsl:text>&lt;/p&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:table" mode="html">
      <xsl:text>&lt;table border='1'&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/table&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:table/tei:head" mode="html">
      <xsl:text>&lt;caption&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/caption&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:table/tei:row" mode="html">
      <xsl:text>&lt;tr&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/tr&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:table/tei:row[@role='label']/tei:cell" mode="html">
      <xsl:text>&lt;th&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/th&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:table/tei:row[@role='data']/tei:cell" mode="html">
      <xsl:text>&lt;td&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/td&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="*[not(self::tei:additions)]/tei:list" mode="html">
      <xsl:text>&lt;ul&gt;</xsl:text>
      <xsl:apply-templates mode="#current"/>
      <xsl:text>&lt;/ul&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="*[not(self::tei:additions)]/tei:list/tei:item" mode="html">
      <xsl:text>&lt;li&gt;</xsl:text>
      <xsl:apply-templates mode="#current"/>
      <xsl:text>&lt;/li&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:additions/tei:list" mode="html">
      <xsl:apply-templates select="tei:head" mode="html"/>
      <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>
      <xsl:apply-templates select="*[not(self::tei:head)]" mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:additions/tei:list/tei:item" mode="html">
      <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:lb" mode="html">
      <xsl:text>&lt;br /&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:title" mode="html">
      <xsl:text>&lt;i&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:term" mode="html">
      <xsl:text>&lt;i&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:q|tei:quote" mode="html">
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

   <xsl:template match="tei:g" mode="html">
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

   <xsl:template match="tei:l" mode="html">
      <xsl:if test="not(local-name(preceding-sibling::*[1]) = 'l')">
         <xsl:text>&lt;br /&gt;</xsl:text>
      </xsl:if>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;br /&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:name" mode="html">
      <xsl:choose>
         <xsl:when test="*[@type='display']">
            <xsl:value-of select="*[@type='display']"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates mode="html"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="tei:ref[@type='biblio']" mode="html">
      <xsl:apply-templates mode="html"/>
   </xsl:template>

   <xsl:template match="tei:ref[@type='extant_mss']" mode="html">
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

   <xsl:template match="tei:ref[@type='cudl_link']" mode="html">
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

   <xsl:template match="tei:ref[@type='nmm_link']" mode="html">
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

   <xsl:template match="tei:ref[not(@type)]" mode="html">
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

   <xsl:template match="tei:ref[@type='popup']" mode="html">
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

   <xsl:template match="tei:locus" mode="html">
      <xsl:variable name="from" select="normalize-space(@from)"/>
      <xsl:variable name="page">
         <xsl:variable name="context-root" select="ancestor::*[last()]"/>
         <xsl:choose>
            <xsl:when test="$context-root[not(self::tei:TEI|self::tei:teiCorpus)]">
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

   <xsl:template match="tei:graphic[not(@url)]" mode="html">
      <xsl:text>&lt;i class=&apos;graphic&apos; style=&apos;font-style:italic;&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:graphic[@url]" mode="html">
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

   <xsl:template match="tei:damage" mode="html">
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

   <xsl:template match="tei:sic" mode="html">
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

   <xsl:template match="tei:term/tei:sic" mode="html">
      <xsl:text>&lt;i class=&apos;error&apos;</xsl:text>
      <xsl:text> title=&apos;This text in error in source&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>
      <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
      <xsl:text> style=&apos;color:red&apos;&gt;</xsl:text>
      <xsl:text>(!)</xsl:text>
      <xsl:text>&lt;/i&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:unclear" mode="html">
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

   <xsl:template match="tei:supplied" mode="html">
      <xsl:text>&lt;i class=&apos;supplied&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal;&apos;</xsl:text>
      <xsl:text> title=&apos;This text supplied by transcriber&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:add" mode="html">
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

   <xsl:template match="tei:del[@type='illegible']" mode="html">
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

   <xsl:template match="tei:del" mode="html">
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

   <xsl:template match="tei:subst" mode="html">
      <xsl:apply-templates mode="html"/>
   </xsl:template>

   <xsl:template match="tei:gap" mode="html">
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

   <xsl:template match="tei:desc" mode="html">
      <xsl:apply-templates mode="html"/>
   </xsl:template>

   <xsl:template match="tei:choice[tei:orig][tei:reg[@type='hyphenated']]" mode="html">
      <xsl:text>&lt;i class=&apos;reg&apos;</xsl:text>
      <xsl:text> style=&apos;font-style:normal;&apos;</xsl:text>
      <xsl:text> title=&apos;String hyphenated for display. Original: </xsl:text>
      <xsl:value-of select="normalize-space(tei:orig)"/>
      <xsl:text>&apos;&gt;</xsl:text>
      <xsl:apply-templates select="tei:reg[@type='hyphenated']" mode="html"/>
      <xsl:text>&lt;/i&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:reg" mode="html">
      <xsl:apply-templates mode="html"/>
   </xsl:template>

   <xsl:template match="text()" mode="html">
      <xsl:variable name="translated" select="translate(., '^&#x00A7;', '&#x00A0;&#x30FB;')"/>
      <xsl:variable name="replaced"
         select="replace($translated, '_ _ _', '&#x2014;&#x2014;&#x2014;')"/>
      <xsl:value-of select="$replaced"/>
   </xsl:template>

   <xsl:template name="get-biblio">
      <xsl:param name="level" select="'doc'"/>

      <xsl:variable name="target" as="item()*">
         <xsl:choose>
            <xsl:when test="$level = 'item'">
               <xsl:copy-of select="tei:listBibl"/>
            </xsl:when>
            <xsl:when test="$level = 'doc-and-item'">
               <xsl:copy-of select="tei:additional//tei:listBibl|tei:msContents/tei:msItem[1]/tei:listBibl"/>
            </xsl:when>
            <xsl:otherwise>
               <!-- doc -->
               <xsl:copy-of select="tei:additional//tei:listBibl"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:if test="$target">
         <xsl:call-template name="write-container-lg">
            <xsl:with-param name="type" select="'bibliographies'"/>
            <xsl:with-param name="displayFormIter">
               <xsl:variable name="t">
                  <xsl:apply-templates select="$target" mode="html"/>
               </xsl:variable>
               <xsl:value-of select="normalize-space($t)"/>
            </xsl:with-param>
            <xsl:with-param name="label" select="'Bibliography'"/>
            <xsl:with-param name="seq" select="1"/>
            <xsl:with-param name="seq2" select="2"/>
         </xsl:call-template>
      </xsl:if>
   </xsl:template>


   <xsl:template match="tei:head" mode="html">
      <xsl:text>&lt;p&gt;&lt;b&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/b&gt;&lt;/p&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:listBibl" mode="html">
      <xsl:apply-templates select="tei:head" mode="html"/>
      <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>
      <xsl:apply-templates select=".//tei:bibl|.//tei:biblStruct" mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>
      <xsl:text>&lt;br /&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:listBibl//tei:bibl" mode="html">
      <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:listBibl//tei:biblStruct[not(*)]" mode="html">
      <!-- Template to catch biblStruct w no child elements and treat like bibl - shouldn't really happen but frequently does, so prob easiest to handle it -->
      <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>
      <xsl:apply-templates mode="html"/>
      <xsl:text>&lt;/div&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:listBibl//tei:biblStruct[tei:analytic]" mode="html">
      <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;</xsl:text>
      <xsl:choose>
         <xsl:when test="@xml:id">
            <xsl:text> id=&quot;</xsl:text>
            <xsl:value-of select="normalize-space(@xml:id)"/>
            <xsl:text>&quot;</xsl:text>
         </xsl:when>
         <xsl:when test="tei:idno[@type='callNumber']">
            <xsl:text> id=&quot;</xsl:text>
            <xsl:value-of select="normalize-space(tei:idno)"/>
            <xsl:text>&quot;</xsl:text>
         </xsl:when>
      </xsl:choose>
      <xsl:text>&gt;</xsl:text>

      <xsl:choose>
         <xsl:when test="@type='bookSection' or @type='encyclopaediaArticle' or @type='encyclopediaArticle'">
            <xsl:for-each select="tei:analytic">
               <xsl:for-each select="tei:author|tei:editor">
                  <xsl:call-template name="get-names-first-surname-first"/>
               </xsl:for-each>

               <xsl:text>, </xsl:text>

               <xsl:for-each select="tei:title">
                  <xsl:text>&quot;</xsl:text>
                  <xsl:value-of select="normalize-space(.)"/>
                  <xsl:text>&quot;</xsl:text>
               </xsl:for-each>
            </xsl:for-each>

            <xsl:text>, in </xsl:text>

            <xsl:for-each select="tei:monogr">

               <xsl:choose>
                  <xsl:when test="tei:author">
                     <xsl:for-each select="tei:author">
                        <xsl:call-template name="get-names-all-forename-first"/>
                     </xsl:for-each>

                     <xsl:text>, </xsl:text>

                     <xsl:for-each select="tei:title[not (@type='short')]">
                        <xsl:text>&lt;i&gt;</xsl:text>
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:text>&lt;/i&gt;</xsl:text>
                     </xsl:for-each>

                     <xsl:if test="tei:editor">
                        <xsl:text>, ed. </xsl:text>
                        <xsl:for-each select="tei:editor">
                           <xsl:call-template name="get-names-all-forename-first"/>
                        </xsl:for-each>
                     </xsl:if>
                  </xsl:when>

                  <xsl:when test="tei:editor">
                     <xsl:for-each select="tei:editor">
                        <xsl:call-template name="get-names-all-forename-first"/>
                     </xsl:for-each>

                     <xsl:choose>
                        <xsl:when test="(count(tei:editor) &gt; 1)">
                           <xsl:text> (eds)</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:text> (ed.)</xsl:text>
                        </xsl:otherwise>
                     </xsl:choose>
                     <xsl:text>, </xsl:text>

                     <xsl:for-each select="tei:title[not(@type='short')]">
                        <xsl:text>&lt;i&gt;</xsl:text>
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:text>&lt;/i&gt;</xsl:text>
                     </xsl:for-each>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:for-each select="tei:title[not(@type='short')]">
                        <xsl:text>&lt;i&gt;</xsl:text>
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:text>&lt;/i&gt;</xsl:text>
                     </xsl:for-each>
                  </xsl:otherwise>
               </xsl:choose>

               <xsl:if test="tei:edition">
                  <xsl:text> </xsl:text>
                  <xsl:value-of select="tei:edition"/>
               </xsl:if>

               <xsl:if test="tei:respStmt">
                  <xsl:for-each select="tei:respStmt">
                     <xsl:text> </xsl:text>
                     <xsl:call-template name="get-respStmt"/>
                  </xsl:for-each>
               </xsl:if>

               <xsl:if test="../tei:series">
                  <xsl:for-each select="../tei:series">
                     <xsl:text>, </xsl:text>

                     <xsl:for-each select="tei:title">
                        <xsl:value-of select="normalize-space(.)"/>
                     </xsl:for-each>

                     <xsl:if test=".//tei:biblScope">
                        <xsl:for-each select=".//tei:biblScope">
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

               <xsl:if test="tei:imprint">
                  <xsl:text> </xsl:text>

                  <xsl:for-each select="tei:imprint">
                     <xsl:call-template name="get-imprint"/>
                  </xsl:for-each>
               </xsl:if>


               <xsl:if test=".//tei:biblScope">
                  <xsl:for-each select=".//tei:biblScope">
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
            <xsl:for-each select="tei:analytic">
               <xsl:for-each select="tei:author|tei:editor">
                  <xsl:call-template name="get-names-first-surname-first"/>
               </xsl:for-each>

               <xsl:text>, </xsl:text>

               <xsl:for-each select="tei:title">
                  <xsl:text>&quot;</xsl:text>
                  <xsl:value-of select="normalize-space(.)"/>
                  <xsl:text>&quot;</xsl:text>
               </xsl:for-each>
            </xsl:for-each>

            <xsl:text>, </xsl:text>

            <xsl:for-each select="tei:monogr">
               <xsl:for-each select="tei:title[not(@type='short')]">
                  <xsl:text>&lt;i&gt;</xsl:text>
                  <xsl:value-of select="normalize-space(.)"/>
                  <xsl:text>&lt;/i&gt;</xsl:text>
               </xsl:for-each>

               <xsl:if test=".//tei:biblScope">
                  <xsl:for-each select=".//tei:biblScope">
                     <xsl:text> </xsl:text>
                     <xsl:if test="@type">
                        <xsl:value-of select="normalize-space(@type)"/>
                        <xsl:text>. </xsl:text>
                     </xsl:if>

                     <xsl:value-of select="normalize-space(.)"/>
                  </xsl:for-each>
               </xsl:if>

               <xsl:if test="../tei:series">
                  <xsl:for-each select="../tei:series">
                     <xsl:text>, </xsl:text>

                     <xsl:for-each select="tei:title">
                        <xsl:value-of select="normalize-space(.)"/>
                     </xsl:for-each>

                     <xsl:if test=".//tei:biblScope">
                        <xsl:for-each select=".//tei:biblScope">
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

               <xsl:if test="tei:imprint">
                  <xsl:text> </xsl:text>

                  <xsl:for-each select="tei:imprint">
                     <xsl:call-template name="get-imprint"/>
                  </xsl:for-each>
               </xsl:if>
            </xsl:for-each>
            <xsl:text>.</xsl:text>
         </xsl:when>
         <xsl:otherwise/>
      </xsl:choose>

      <xsl:text>&lt;/div&gt;</xsl:text>
   </xsl:template>

   <xsl:template match="tei:listBibl//tei:biblStruct[tei:monogr and not(tei:analytic)]" mode="html">
      <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;</xsl:text>
      <xsl:choose>
         <xsl:when test="@xml:id">
            <xsl:text> id=&quot;</xsl:text>
            <xsl:value-of select="normalize-space(@xml:id)"/>
            <xsl:text>&quot;</xsl:text>
         </xsl:when>
         <xsl:when test="tei:idno[@type='callNumber']">
            <xsl:text> id=&quot;</xsl:text>
            <xsl:value-of select="normalize-space(tei:idno)"/>
            <xsl:text>&quot;</xsl:text>
         </xsl:when>
      </xsl:choose>
      <xsl:text>&gt;</xsl:text>
      <xsl:choose>
         <xsl:when test="@type='book' or @type='document' or @type='thesis' or @type='manuscript' or @type='webpage'">
            <xsl:for-each select="tei:monogr">
               <xsl:choose>
                  <xsl:when test="tei:author">
                     <xsl:for-each select="tei:author">
                        <xsl:call-template name="get-names-first-surname-first"/>
                     </xsl:for-each>
                     <xsl:text>, </xsl:text>
                     <xsl:for-each select="tei:title[not(@type='short')]">
                        <xsl:text>&lt;i&gt;</xsl:text>
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:text>&lt;/i&gt;</xsl:text>
                     </xsl:for-each>

                     <xsl:if test="tei:editor">
                        <xsl:text>, ed. </xsl:text>
                        <xsl:for-each select="tei:editor">
                           <xsl:call-template name="get-names-all-forename-first"/>
                        </xsl:for-each>
                     </xsl:if>
                  </xsl:when>
                  <xsl:when test="tei:editor">
                     <xsl:for-each select="tei:editor">
                        <xsl:call-template name="get-names-first-surname-first"/>
                     </xsl:for-each>
                     <xsl:choose>
                        <xsl:when test="(count(tei:editor) &gt; 1)">
                           <xsl:text> (eds)</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:text> (ed.)</xsl:text>
                        </xsl:otherwise>
                     </xsl:choose>
                     <xsl:text>, </xsl:text>
                     <xsl:for-each select="tei:title[not(@type='short')]">
                        <xsl:text>&lt;i&gt;</xsl:text>
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:text>&lt;/i&gt;</xsl:text>
                     </xsl:for-each>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:for-each select="tei:title[not(@type='short')]">
                        <xsl:text>&lt;i&gt;</xsl:text>
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:text>&lt;/i&gt;</xsl:text>
                     </xsl:for-each>
                  </xsl:otherwise>
               </xsl:choose>

               <xsl:if test="tei:edition">
                  <xsl:text> </xsl:text>
                  <xsl:value-of select="tei:edition"/>
               </xsl:if>

               <xsl:if test="tei:respStmt">
                  <xsl:for-each select="tei:respStmt">
                     <xsl:text> </xsl:text>
                     <xsl:call-template name="get-respStmt"/>
                  </xsl:for-each>
               </xsl:if>

               <xsl:if test="../tei:series">
                  <xsl:for-each select="../tei:series">
                     <xsl:text>, </xsl:text>
                     <xsl:for-each select="tei:title">
                        <xsl:value-of select="normalize-space(.)"/>
                     </xsl:for-each>

                     <xsl:if test=".//tei:biblScope">
                        <xsl:for-each select=".//tei:biblScope">
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

               <xsl:if test="tei:extent">
                  <xsl:for-each select="tei:extent">
                     <xsl:text>, </xsl:text>
                     <xsl:value-of select="normalize-space(.)"/>
                  </xsl:for-each>
               </xsl:if>

               <xsl:if test="tei:imprint">
                  <xsl:for-each select="tei:imprint">
                     <xsl:text> </xsl:text>
                     <xsl:call-template name="get-imprint"/>
                  </xsl:for-each>
               </xsl:if>

               <xsl:if test=".//tei:biblScope">
                  <xsl:for-each select=".//tei:biblScope">
                     <xsl:text> </xsl:text>
                     <xsl:if test="@type">
                        <xsl:value-of select="normalize-space(@type)"/>
                        <xsl:text>. </xsl:text>
                     </xsl:if>
                     <xsl:value-of select="normalize-space(.)"/>
                  </xsl:for-each>
               </xsl:if>
            </xsl:for-each>

            <xsl:if test="tei:idno[@type='ISBN']">
               <xsl:for-each select="tei:idno[@type='ISBN']">
                  <xsl:text> ISBN: </xsl:text>
                  <xsl:value-of select="normalize-space(.)"/>
               </xsl:for-each>
            </xsl:if>

            <xsl:text>.</xsl:text>
         </xsl:when>
         <xsl:otherwise/>
      </xsl:choose>
      <xsl:text>&lt;/div&gt;</xsl:text>
   </xsl:template>

   <!--names processing for bibliography-->
   <xsl:template name="get-names-first-surname-first">
      <xsl:choose>
         <xsl:when test="position() = 1">
            <!-- first author = surname first -->
            <xsl:choose>
               <xsl:when test=".//tei:surname">
                  <!-- surname explicitly present -->
                  <xsl:for-each select=".//tei:surname">
                     <xsl:value-of select="normalize-space(.)"/>
                     <xsl:if test="not(position()=last())">
                        <xsl:text> </xsl:text>
                     </xsl:if>
                  </xsl:for-each>
                  <xsl:if test=".//tei:forename">
                     <xsl:text>, </xsl:text>
                     <xsl:for-each select=".//tei:forename">
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:if test="not(position()=last())">
                           <xsl:text> </xsl:text>
                        </xsl:if>
                     </xsl:for-each>
                  </xsl:if>
               </xsl:when>
               <xsl:when test="tei:name[not(*)]">
                  <!-- just a name, not surname/forename -->
                  <xsl:for-each select=".//tei:name[not(*)]">
                     <xsl:value-of select="normalize-space(.)"/>
                     <xsl:if test="not(position()=last())">
                        <xsl:text> </xsl:text>
                     </xsl:if>
                  </xsl:for-each>
               </xsl:when>
               <xsl:otherwise>
                  <!-- forenames only? not sure what else to do but render them -->
                  <xsl:for-each select=".//tei:forename">
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
               <xsl:when test=".//tei:surname">
                  <!-- surname explicitly present -->
                  <xsl:if test=".//tei:forename">
                     <xsl:for-each select=".//tei:forename">
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:if test="not(position()=last())">
                           <xsl:text> </xsl:text>
                        </xsl:if>
                     </xsl:for-each>
                     <xsl:text> </xsl:text>
                  </xsl:if>

                  <xsl:for-each select=".//tei:surname">
                     <xsl:value-of select="normalize-space(.)"/>
                     <xsl:if test="not(position()=last())">
                        <xsl:text> </xsl:text>
                     </xsl:if>
                  </xsl:for-each>
               </xsl:when>
               <xsl:when test="tei:name[not(*)]">
                  <!-- just a name, not forename/surname -->
                  <xsl:for-each select=".//tei:name[not(*)]">
                     <xsl:value-of select="normalize-space(.)"/>
                     <xsl:if test="not(position()=last())">
                        <xsl:text> </xsl:text>
                     </xsl:if>
                  </xsl:for-each>
               </xsl:when>
               <xsl:otherwise>
                  <!-- forenames only? not sure what else to do but render them -->
                  <xsl:for-each select=".//tei:forename">
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
      <xsl:for-each select=".//tei:name[not(*)]">
         <xsl:value-of select="normalize-space(.)"/>
         <xsl:if test="not(position()=last())">
            <xsl:text> </xsl:text>
         </xsl:if>
      </xsl:for-each>
      <xsl:for-each select=".//tei:forename">
         <xsl:value-of select="normalize-space(.)"/>
         <xsl:if test="not(position()=last())">
            <xsl:text> </xsl:text>
         </xsl:if>
      </xsl:for-each>
      <xsl:text> </xsl:text>
      <xsl:for-each select=".//tei:surname">
         <xsl:value-of select="normalize-space(.)"/>
         <xsl:if test="not(position()=last())">
            <xsl:text> </xsl:text>
         </xsl:if>
      </xsl:for-each>
   </xsl:template>

   <xsl:template name="get-imprint">
      <xsl:variable name="pubText">
         <xsl:if test="tei:note[@type='thesisType']">
            <xsl:for-each select="tei:note[@type='thesisType']">
               <xsl:value-of select="normalize-space(.)"/>
               <xsl:text> thesis</xsl:text>
            </xsl:for-each>
            <xsl:text> </xsl:text>
         </xsl:if>

         <xsl:if test="tei:pubPlace">
            <xsl:for-each select="tei:pubPlace">
               <xsl:value-of select="normalize-space(.)"/>
            </xsl:for-each>
            <xsl:text>: </xsl:text>
         </xsl:if>

         <xsl:if test="tei:publisher">
            <xsl:for-each select="tei:publisher">
               <xsl:value-of select="normalize-space(.)"/>
            </xsl:for-each>
            <xsl:if test="tei:date">
               <xsl:text>, </xsl:text>
            </xsl:if>
         </xsl:if>

         <xsl:if test="tei:date">
            <xsl:for-each select="tei:date">
               <xsl:value-of select="normalize-space(.)"/>
            </xsl:for-each>
         </xsl:if>
      </xsl:variable>

      <xsl:if test="normalize-space($pubText)">
         <xsl:text>(</xsl:text>
         <xsl:value-of select="$pubText"/>
         <xsl:text>)</xsl:text>
      </xsl:if>

      <xsl:if test="tei:note[@type='url']">
         <xsl:text> &lt;a target=&apos;_blank&apos; class=&apos;externalLink&apos; href=&apos;</xsl:text>
         <xsl:value-of select="tei:note[@type='url']"/>
         <xsl:text>&apos;&gt;</xsl:text>
         <xsl:value-of select="tei:note[@type='url']"/>
         <xsl:text>&lt;/a&gt;</xsl:text>
      </xsl:if>

      <xsl:if test="tei:note[@type='accessed']">
         <xsl:text> Accessed: </xsl:text>
         <xsl:for-each select="tei:note[@type='accessed']">
            <xsl:value-of select="normalize-space(.)"/>
         </xsl:for-each>
      </xsl:if>
   </xsl:template>

   <xsl:template name="get-respStmt">
      <xsl:choose>
         <xsl:when test="*">
            <xsl:for-each select="tei:resp">
               <xsl:value-of select="."/>
               <xsl:text>: </xsl:text>
            </xsl:for-each>
            <xsl:for-each select=".//tei:forename">
               <xsl:value-of select="."/>
               <xsl:text> </xsl:text>
            </xsl:for-each>
            <xsl:for-each select=".//tei:surname">
               <xsl:value-of select="."/>
               <xsl:if test="not(position()=last())">
                  <xsl:text> </xsl:text>
               </xsl:if>
            </xsl:for-each>
            <xsl:for-each select=".//tei:name[not(*)]">
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
      <xsl:param name="label" select="'Date of Creation'"/>
      <xsl:param name="output_empty" select="false()"/><!-- SHIM COMPAT -->
      <xsl:param name="output_centuries" select="false()"/>

      <xsl:variable name="dateStart" select="cudl:get-date-start($date_elem)" as="xsd:string*"/>
      <xsl:variable name="yearStart" select="cudl:get-year($date_elem/(@from, @notBefore, @when)[1])"/>
      <xsl:if test="$yearStart castable as xsd:integer and ($dateStart !='' or $output_empty)"><!-- SHIM COMPAT -->
         <string key="dateStart" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="$dateStart"/>
         </string>
         <number key="yearStart" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="$yearStart"/>
         </number>
      </xsl:if>

      <xsl:variable name="dateEnd" select="cudl:get-date-end($date_elem)" as="xsd:string*"/>
      <xsl:variable name="yearEnd" select="cudl:get-year($date_elem/(@to, @notAfter, @when)[1])"/>
      <xsl:if test="$yearEnd castable as xsd:integer and ($dateEnd !='' or $output_empty)"><!-- SHIM COMPAT -->
         <string key="dateEnd" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="$dateEnd"/>
         </string>
         <number key="yearEnd" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="$yearEnd"/>
         </number>
      </xsl:if>

      <xsl:if test="$output_centuries eq true() and $dateStart !=''">
         <array key="century" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:for-each select="cudl:get-century($dateStart, $dateEnd)">
               <string xmlns="http://www.w3.org/2005/xpath-functions">
                  <xsl:value-of select="."/>
               </string>
            </xsl:for-each>
         </array>
      </xsl:if>

      <map key="dateDisplay" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:copy-of select="cudl:display(true())"/>
         <xsl:variable name="dateDisplay">
            <xsl:apply-templates select="$date_elem" mode="html"/>
         </xsl:variable>
         <string key="displayForm" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="normalize-space($dateDisplay)"/>
         </string>
         <string key="linktype" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:text>keyword search</xsl:text>
         </string>
         <string key="label" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="$label"/>
         </string>
         <number key="seq" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:value-of select="1"/>
         </number>
      </map>
   </xsl:template>

   <xsl:template name="get-calendarnum">
      <xsl:variable name="dcpID" select="ancestor-or-self::tei:teiHeader//tei:idno[@type='calendarnum']"/>
      <xsl:if test="$dcpID">
         <map key="calendarnum" xmlns="http://www.w3.org/2005/xpath-functions">
            <xsl:call-template name="write-data-obj-flat">
               <xsl:with-param name="displayForm" select="$dcpID"/>
               <xsl:with-param name="label" select="'Letter Number'"/>
            </xsl:call-template>
         </map>
      </xsl:if>
   </xsl:template>

   <xsl:template match="tei:surface" mode="count">
        <xsl:number count="//tei:facsimile/tei:surface" level="any"/>
    </xsl:template>

   <xsl:function name="cudl:get-date-start" as="xsd:string*">
   <xsl:param name="node"/>

   <xsl:choose>
      <xsl:when test="$node/@from">
         <xsl:value-of select="$node/@from"/>
      </xsl:when>
      <xsl:when test="$node/@notBefore">
         <xsl:value-of select="$node/@notBefore"/>
      </xsl:when>
      <xsl:when test="$node/@when">
         <xsl:value-of select="$node/@when"/>
      </xsl:when>
      <xsl:otherwise/>
   </xsl:choose>
</xsl:function>

   <xsl:function name="cudl:get-date-end" as="xsd:string*">
      <xsl:param name="node"/>

      <xsl:choose>
         <xsl:when test="$node/@to">
            <xsl:value-of select="$node/@to"/>
         </xsl:when>
         <xsl:when test="$node/@notAfter">
            <xsl:value-of select="$node/@notAfter"/>
         </xsl:when>
         <xsl:when test="$node/@when">
            <xsl:value-of select="$node/@when"/>
         </xsl:when>
         <xsl:otherwise/>
      </xsl:choose>
   </xsl:function>

   <xsl:function name="cudl:get-year" as="xsd:integer*">
      <xsl:param name="iso_string"/>

      <xsl:variable name="year_tmp" select="replace($iso_string,'(^-*\d{1,4})(.+)*$', '$1')"/>
      <xsl:if test="$year_tmp castable as xsd:integer">
         <xsl:sequence select="xsd:integer($year_tmp)"/>
      </xsl:if>
   </xsl:function>

   <xsl:function name="cudl:display" as="item()">
      <xsl:param name="bool" as="xsd:boolean"/>

      <boolean key="display" xmlns="http://www.w3.org/2005/xpath-functions">
         <xsl:value-of select="$bool"/>
      </boolean>
   </xsl:function>

   <xsl:template match="*[@key='seq']" priority="1" mode="updateSeq">
      <xsl:variable name="position" select="cudl:get-pos(.)"/>
      <xsl:copy>
         <xsl:copy-of select="@* except @parent"/>
         <xsl:value-of select="$position"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="@*|node()"  mode="updateSeq">
      <xsl:copy>
         <xsl:apply-templates select="@*|node()" mode="#current"/>
      </xsl:copy>
   </xsl:template>

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

   <!-- Calculate cdl seq value -->
   <xsl:key name="test" match="//cudl:element" use="@name"/>

   <xsl:function name="cudl:get-pos" as="xsd:int*">
      <xsl:param name="node" />

      <xsl:variable name="containing_named_object" select="$node/ancestor::json:map[normalize-space(@key)][1]"/>
      <xsl:variable name="offset" select="if (not($node/parent::json:map[normalize-space(@key)])) then 1 else 0"/>

      <xsl:variable name="container_name" select="$containing_named_object/@key"/>

      <xsl:variable name="matches" select="key('test', $container_name, $layout)"/>

      <xsl:choose>
         <xsl:when test="count($matches) eq 1">
            <xsl:for-each select="$matches">
               <xsl:value-of select="sum((count(ancestor::cudl:element), count(preceding::cudl:element))) + $offset" />
            </xsl:for-each>
         </xsl:when>
         <xsl:when test="count($matches) gt 1">
            <xsl:variable name="containing-object" select="$containing_named_object/ancestor::json:map[normalize-space(@key)][1]"/>
            <xsl:variable name="key" select="($node[normalize-space(@parent)]/string(@parent), $containing-object/@key, 'descriptiveMetadata')[normalize-space(.)][1]"/><!-- dscriptive metadata is an array - so add in a trap to catch it -->
            <xsl:variable name="ancestors" select="key('test', $key, $layout)//cudl:element[@name = $container_name]/ancestor::cudl:element[not(@jsontype='object')][not(@name=($key, 'descriptiveMetadata'))]/@name"/>
            <xsl:variable name="proposed_target" select="key('test', $key, $layout)//cudl:element[@name = $container_name][not(ancestor::cudl:element[@name=$ancestors])]"/>
            <xsl:for-each select="$proposed_target">
               <xsl:value-of select="sum((count(ancestor::cudl:element), count(preceding::cudl:element))) + $offset" />
            </xsl:for-each>
         </xsl:when>
      </xsl:choose>

   </xsl:function>

   <xsl:function name="cudl:path-to-directory" as="xsd:string">
      <xsl:param name="dir"/>
      <xsl:param name="build_dir"/>

      <xsl:variable name="directory" select="replace(normalize-space($dir),'/$','')"/>

      <xsl:choose>
         <xsl:when test="normalize-space($build_dir) !=''">
            <xsl:choose>
               <xsl:when test="$directory != ''">
                  <xsl:choose>
                     <xsl:when test="matches($directory,'^/')">
                        <!-- directory is absolute path -->
                        <xsl:value-of select="$directory"/>
                     </xsl:when>
                     <xsl:otherwise>
                        <!-- Directory is set in build file and relative to build file -->
                        <xsl:value-of select="replace(resolve-uri(concat(normalize-space($build_dir),'/',$directory)),'^file:','')"/>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:when>
            </xsl:choose>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="$directory"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>


   <xsl:function name="cudl:construct-output-filename-path" as="xsd:string">
      <xsl:param name="node" as="item()*"/>
      <xsl:param name="type" as="xsd:string*" />
      <xsl:param name="surfaceID" as="xsd:string*"/>
      <xsl:param name="supplemental" as="xsd:string*"/>

      <!-- The only @type value that's accepted into the filename
            at this time is 'translation' -->
      <xsl:variable name="type_cleaned" select="$type[. = 'translation']" as="xsd:string*"/>

      <xsl:variable name="document-uri" select="document-uri(root($node))"/>
      <xsl:variable name="filename-root" select="replace(normalize-space(tokenize(document-uri(root($node)), '/')[last()]),'\..*$','')" as="xsd:string"/>
      <xsl:variable name="path-to-filename" select="string-join(tokenize(replace(document-uri(root($node)),'^file:',''), '/')[position() lt last()],'/')" as="xsd:string"/>
      <xsl:variable name="output-filename" as="xsd:string">
         <xsl:value-of select="concat(string-join(($filename-root,distinct-values(($surfaceID, $supplemental)),$type_cleaned)[.!=''],'-'),'.xml')"/>
      </xsl:variable>


      <xsl:variable name="hierarchy" as="xsd:string">
         <xsl:choose>
            <xsl:when test="$clean_data_dir != ''">
               <xsl:value-of select="replace($path-to-filename,concat('^',$clean_data_dir),'')"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:value-of select="$path-to-filename"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:value-of select="replace(concat(string-join(($clean_dest_dir,$hierarchy)[.!=''],'/'),'/',$output-filename),'//','/')"/>
   </xsl:function>

   <xsl:function name="cudl:get-century">
      <xsl:param name="dateStart"/>
      <xsl:param name="dateEnd"/>

      <xsl:variable name="century-key" as="item()*">
         <cudl:century key="-10">0900s B.C.E.</cudl:century>
         <cudl:century key="-9">0800s B.C.E.</cudl:century>
         <cudl:century key="-8">0700s B.C.E.</cudl:century>
         <cudl:century key="-7">0600s B.C.E.</cudl:century>
         <cudl:century key="-6">0500s B.C.E.</cudl:century>
         <cudl:century key="-5">0400s B.C.E.</cudl:century>
         <cudl:century key="-4">0300s B.C.E.</cudl:century>
         <cudl:century key="-3">0200s B.C.E.</cudl:century>
         <cudl:century key="-2">0100s B.C.E.</cudl:century>
         <cudl:century key="-1">0000s B.C.E.</cudl:century>
         <cudl:century key="0">0000s C.E.</cudl:century>
         <cudl:century key="1">0100s C.E.</cudl:century>
         <cudl:century key="2">0200s C.E.</cudl:century>
         <cudl:century key="3">0300s C.E.</cudl:century>
         <cudl:century key="4">0400s C.E.</cudl:century>
         <cudl:century key="5">0500s C.E.</cudl:century>
         <cudl:century key="6">0600s C.E.</cudl:century>
         <cudl:century key="7">0700s C.E.</cudl:century>
         <cudl:century key="8">0800s C.E.</cudl:century>
         <cudl:century key="9">0900s C.E.</cudl:century>
         <cudl:century key="10">1000s C.E.</cudl:century>
         <cudl:century key="11">1100s C.E.</cudl:century>
         <cudl:century key="12">1200s C.E.</cudl:century>
         <cudl:century key="13">1300s C.E.</cudl:century>
         <cudl:century key="14">1400s C.E.</cudl:century>
         <cudl:century key="15">1500s C.E.</cudl:century>
         <cudl:century key="16">1600s C.E.</cudl:century>
         <cudl:century key="17">1700s C.E.</cudl:century>
         <cudl:century key="18">1800s C.E.</cudl:century>
         <cudl:century key="19">1900s C.E.</cudl:century>
         <cudl:century key="20">2000s C.E.</cudl:century>
         <cudl:century key="21">2100s C.E.</cudl:century>
      </xsl:variable>

      <xsl:variable name="start_num" select="cudl:_get_century_num($dateStart)" as="xsd:integer*"/>
      <xsl:variable name="end_num" select="cudl:_get_century_num($dateEnd)" as="xsd:integer*"/>

      <xsl:if test="$start_num castable as xsd:integer">
         <xsl:variable name="end_num_final" as="xsd:integer">
            <xsl:choose>
               <xsl:when test="$end_num castable as xsd:integer">
                  <xsl:value-of select="$end_num"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:value-of select="$start_num"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>

         <xsl:for-each select="($start_num to $end_num_final)">
            <xsl:variable name="key_num" select="."/>
            <xsl:sequence select="$century-key[@key=$key_num]"/>
         </xsl:for-each>
      </xsl:if>
   </xsl:function>

   <xsl:function name="cudl:_get_century_num" as="xsd:integer*">
      <xsl:param name="date"/>

      <xsl:variable name="tmp">
         <xsl:choose>
            <xsl:when test="starts-with($date, '-')">
               <xsl:value-of select="substring($date, 1,3)"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:value-of select="substring($date, 1,2)"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:choose>
         <xsl:when test="$tmp castable as xsd:integer">
            <xsl:value-of select="number($tmp)"/>
         </xsl:when>
      </xsl:choose>
   </xsl:function>
</xsl:stylesheet>
