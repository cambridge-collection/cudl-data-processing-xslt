<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
   xmlns:date="http://exslt.org/dates-and-times"
   xmlns:parse="http://cdlib.org/xtf/parse"
   xmlns:xtf="http://cdlib.org/xtf"
   xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:cudl="http://cudl.cam.ac.uk/xtf/"
   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
   xmlns="http://www.w3.org/1999/xhtml"
   extension-element-prefixes="date"
   exclude-result-prefixes="#all">

   <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
   
   <xsl:include href="global-var.xsl"/>

   <xsl:template match="/">

      <xsl:element name="html">
         <xsl:element name="head">
           <xsl:element name="title"><xsl:value-of select="concat('Folio ', //*:text/*:body//*:pb[1]/@n)"/></xsl:element>
            <link href="{$services_url}/stylesheets/legacy-cudl/charis-sil.css" rel="stylesheet" type="text/css"/>
         </xsl:element>

         <xsl:element name="body">
            <xsl:attribute name="class" select="'charisSIL'"/>

            <xsl:call-template name="make-header" />

            <xsl:call-template name="make-body" />

            <xsl:call-template name="make-footer" />

         </xsl:element>

      </xsl:element>

   </xsl:template>

   <xsl:template name="make-header">

      <xsl:element name="div">
         <xsl:attribute name="class" select="'header'" />

         <xsl:element name="p">
            <xsl:attribute name="style" select="'text-align: right'"/>
            <xsl:text>Transcription by </xsl:text>
            <xsl:element name="a">
               <xsl:attribute name="href">http://www.corpuscoranicum.de/</xsl:attribute>
               <xsl:attribute name="target">_blank</xsl:attribute>
               <xsl:text>Corpus Coranicum</xsl:text>
            </xsl:element>
         </xsl:element>

         <!--
         <xsl:element name="p">

            <xsl:attribute name="style" select="'color: #3D3D8F'"/>
            <xsl:value-of select="concat('&lt;', //*:text/*:body//*:pb[1]/@n, '&gt;')"/>
         </xsl:element>
         -->

      </xsl:element>

   </xsl:template>

   <xsl:template name="make-body">

      <xsl:apply-templates select="//*:text/*:body" mode="html" />

   </xsl:template>


   <xsl:template match="*:body" mode="html">

      <xsl:element name="div">
         <xsl:attribute name="class" select="'body'" />
         <xsl:attribute name="style" select="'font-size: large'"/>

         <xsl:apply-templates mode="html" />

      </xsl:element>

   </xsl:template>

   <xsl:template match="*:div" mode="html">

      <xsl:element name="div">

         <xsl:apply-templates mode="html" />

      </xsl:element>

   </xsl:template>

   <xsl:function name="cudl:first-upper-case">
      <xsl:param name="text" />

      <xsl:value-of select="concat(upper-case(substring($text,1,1)),substring($text, 2))" />
   </xsl:function>


   <xsl:template match="*:p" mode="html">

      <xsl:element name="p">

         <xsl:if test="@rend='center'">
            <!--<xsl:attribute name="style" select="'text-align: center'"/>-->
            <xsl:attribute name="style" select="'margin-left: 200px;'"/>
         </xsl:if>

         <xsl:apply-templates mode="html" />

      </xsl:element>

   </xsl:template>

   <xsl:template match="*[not(local-name()='additions')]/*:list" mode="html">

      <xsl:element name="div">

         <xsl:if test="ancestor::node()[@rend='center']">
<!--            <xsl:attribute name="style" select="'text-align: center;'"/>-->

            <xsl:attribute name="style" select="'margin-left: 200px;'"/>

         </xsl:if>


         <xsl:apply-templates mode="html" />

      </xsl:element>

   </xsl:template>

   <xsl:template match="*[not(local-name()='additions')]/*:list/*:item" mode="html">

      <xsl:apply-templates mode="html" />
      <xsl:element name="br" />

   </xsl:template>

   <xsl:template match="*:additions/*:list" mode="html">

      <xsl:element name="div">
         <xsl:attribute name="style" select="'list-style-type: disc;'" />

         <xsl:apply-templates mode="html" />

      </xsl:element>

   </xsl:template>

   <xsl:template match="*:additions/*:list/*:item" mode="html">

      <xsl:element name="div">
         <xsl:attribute name="style" select="'display: list-item; margin-left: 20px;'" />

         <xsl:apply-templates mode="html" />

      </xsl:element>

   </xsl:template>

   <xsl:template match="*:lb" mode="html">

      <xsl:element name="br" />

   </xsl:template>

   <xsl:template match="*:title" mode="html">

      <xsl:element name="i">
         <xsl:apply-templates mode="html" />
      </xsl:element>

   </xsl:template>

   <xsl:template match="*:term" mode="html">

      <xsl:element name="i">
         <xsl:apply-templates mode="html" />
      </xsl:element>

   </xsl:template>

   <xsl:template match="*:q|*:quote" mode="html">

      <xsl:text>"</xsl:text>
      <xsl:apply-templates mode="html" />
      <xsl:text>"</xsl:text>

   </xsl:template>

   <xsl:template match="*[@rend='italic']" mode="html">

      <xsl:element name="i">
         <xsl:apply-templates mode="html" />
      </xsl:element>

   </xsl:template>

   <xsl:template match="*[@rend='bold']" mode="html">

      <xsl:element name="b">
         <xsl:apply-templates mode="html" />
      </xsl:element>

   </xsl:template>

   <xsl:template match="*[@rend='superscript']" mode="html">

      <xsl:element name="sup">
         <xsl:apply-templates mode="html" />
      </xsl:element>

   </xsl:template>

   <!--table stuff-->
   <xsl:template match="*:table" mode="html">

      <xsl:element name="table">

         <xsl:apply-templates mode="html"/>

      </xsl:element>

   </xsl:template>

   <xsl:template match="*:row" mode="html">

      <xsl:element name="tr">

         <xsl:apply-templates mode="html"/>

      </xsl:element>

   </xsl:template>

   <xsl:template match="*:cell" mode="html">

      <xsl:element name="td">

         <xsl:choose>

            <xsl:when test="@role='label'">
               <xsl:element name="b">
                  <xsl:apply-templates mode="html"/>
               </xsl:element>
            </xsl:when>
            <xsl:otherwise>
               <xsl:apply-templates mode="html"/>
            </xsl:otherwise>

         </xsl:choose>


      </xsl:element>

   </xsl:template>

   <!--column breaks -  a bit of a fudge!!-->
   <xsl:template match="*:cb" mode="html">

      <xsl:element name="span">
         <!--<xsl:text disable-output-escaping="yes">&amp;nbsp;&amp;nbsp;&amp;nbsp;&amp;nbsp;</xsl:text>-->
         <xsl:text disable-output-escaping="yes">&#160;&#160;&#160;&#160;&#160;</xsl:text>
         <xsl:apply-templates mode="html" />
      </xsl:element>

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
            <xsl:element name="i">
               <xsl:apply-templates mode="html" />
            </xsl:element>
         </xsl:otherwise>
      </xsl:choose>

   </xsl:template>

   <xsl:template match="*:l" mode="html">

      <xsl:if test="not(local-name(preceding-sibling::*[1]) = 'l')">
         <xsl:element name="br" />
      </xsl:if>
      <xsl:apply-templates mode="html" />
      <xsl:element name="br" />

   </xsl:template>

   <xsl:template match="*:name" mode="html">

      <xsl:choose>
         <xsl:when test="*[@type='display']">
            <xsl:value-of select="*[@type='display']" />
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates mode="html" />
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="*:ref[@type='biblio']" mode="html">

      <xsl:apply-templates mode="html" />

   </xsl:template>

   <xsl:template match="*:ref[@type='extant_mss']" mode="html">

      <xsl:choose>
         <xsl:when test="normalize-space(@target)">
            <xsl:element name="a">
               <xsl:attribute name="target" select="'_blank'"/>
               <xsl:attribute name="class" select="'externalLink'"/>
               <xsl:attribute name="href" select="normalize-space(@target)"/>
               <xsl:apply-templates mode="html" />
            </xsl:element>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates mode="html" />
         </xsl:otherwise>
      </xsl:choose>

   </xsl:template>

   <xsl:template match="*:ref[not(@type)]" mode="html">

      <xsl:choose>
         <xsl:when test="normalize-space(@target)">
            <xsl:element name="a">
               <xsl:attribute name="target" select="'_blank'"/>
               <xsl:attribute name="class" select="'externalLink'"/>
               <xsl:attribute name="href" select="normalize-space(@target)"/>
               <xsl:apply-templates mode="html" />
            </xsl:element>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates mode="html" />
         </xsl:otherwise>
      </xsl:choose>

   </xsl:template>

   <xsl:template match="*:locus" mode="html">

      <!-- Don't render locus -->

      <!-- <xsl:apply-templates mode="html" /> -->

   </xsl:template>

   <xsl:template match="*:graphic[not(@url)]" mode="html">

      <xsl:if test="normalize-space(.)">
         <xsl:element name="span">
            <xsl:attribute name="class" select="'graphic'" />
            <xsl:attribute name="style" select="'font-style:italic;'" />
            <xsl:apply-templates mode="html" />
         </xsl:element>
      </xsl:if>

   </xsl:template>

   <xsl:template match="*:damage" mode="html">

      <xsl:element name="span">
         <xsl:attribute name="class" select="'delim'" />
         <xsl:attribute name="style" select="'font-style:normal; color:red'" />
         <xsl:text>[</xsl:text>
      </xsl:element>
      <xsl:element name="span">
         <xsl:attribute name="class" select="'damage'" />
         <xsl:attribute name="style" select="'font-style:normal;'" />
         <xsl:attribute name="title" select="'This text damaged in source'" />
         <xsl:apply-templates mode="html" />
      </xsl:element>
      <xsl:element name="span">
         <xsl:attribute name="class" select="'delim'" />
         <xsl:attribute name="style" select="'font-style:normal; color:red'" />
         <xsl:text>]</xsl:text>
      </xsl:element>

   </xsl:template>

   <xsl:template match="*:sic" mode="html">

      <xsl:element name="span">
         <xsl:attribute name="class" select="'sic'" />
         <xsl:attribute name="style" select="'font-style:normal;'" />
         <xsl:attribute name="title" select="'This text in error in source'" />
         <xsl:apply-templates mode="html" />
      </xsl:element>
      <xsl:element name="span">
         <xsl:attribute name="class" select="'delim'" />
         <xsl:attribute name="style" select="'font-style:normal; color:red'" />
         <xsl:text>(!)</xsl:text>
      </xsl:element>

   </xsl:template>

   <xsl:template match="*:unclear" mode="html">

      <xsl:element name="span">
         <xsl:attribute name="class" select="'delim'" />
         <xsl:attribute name="style" select="'font-style:normal; color:red'" />
         <xsl:text>[</xsl:text>
      </xsl:element>
      <xsl:element name="span">
         <xsl:attribute name="class" select="'unclear'" />
         <xsl:attribute name="style" select="'font-style:normal;'" />
         <xsl:attribute name="title" select="'This text imperfectly legible in source'" />
         <xsl:apply-templates mode="html" />
      </xsl:element>
      <xsl:element name="span">
         <xsl:attribute name="class" select="'delim'" />
         <xsl:attribute name="style" select="'font-style:normal; color:red'" />
         <xsl:text>]</xsl:text>
      </xsl:element>

   </xsl:template>

   <xsl:template match="*:supplied" mode="html">

      <xsl:element name="span">
         <xsl:attribute name="class" select="'supplied'" />
         <xsl:attribute name="style" select="'font-style:normal;'" />
         <xsl:attribute name="title" select="'This text supplied by transcriber'" />
         <xsl:apply-templates mode="html" />
      </xsl:element>

   </xsl:template>

   <xsl:template match="*:add" mode="html">

      <xsl:element name="span">
         <xsl:attribute name="class" select="'delim'" />
         <xsl:attribute name="style" select="'font-style:normal; color:red'" />
         <xsl:text>\</xsl:text>
      </xsl:element>
      <xsl:element name="span">
         <xsl:attribute name="class" select="'add'" />
         <xsl:attribute name="style" select="'font-style:normal;'" />
         <xsl:attribute name="title" select="'This text added'" />
         <xsl:apply-templates mode="html" />
      </xsl:element>
      <xsl:element name="span">
         <xsl:attribute name="class" select="'delim'" />
         <xsl:attribute name="style" select="'font-style:normal; color:red'" />
         <xsl:text>/</xsl:text>
      </xsl:element>

   </xsl:template>


   <xsl:template match="*:del[@type='illegible']" mode="html">

      <xsl:element name="span">
         <xsl:attribute name="class" select="'deleted'" />
         <xsl:attribute name="style" select="'font-style:normal;'" />
         <xsl:attribute name="title" select="'This text deleted and illegible'" />
         <xsl:apply-templates mode="html" />
      </xsl:element>

   </xsl:template>

   <xsl:template match="*:del" mode="html">

      <xsl:element name="span">
         <xsl:attribute name="class" select="'deleted'" />
         <xsl:attribute name="style" select="'font-style:normal; text-decoration:line-through;'" />
         <xsl:attribute name="title" select="'This text deleted'" />
         <xsl:apply-templates mode="html" />
      </xsl:element>

   </xsl:template>

   <xsl:template match="*:subst" mode="html">

      <xsl:apply-templates mode="html" />

   </xsl:template>

   <xsl:template match="*:gap" mode="html">

      <xsl:element name="span">
         <xsl:attribute name="class" select="'delim'" />
         <xsl:attribute name="style" select="'font-style:normal; color:red'" />
         <xsl:text>&gt;-</xsl:text>
      </xsl:element>
      <xsl:element name="span">
         <xsl:attribute name="class" select="'gap'" />
         <xsl:attribute name="style" select="'font-style:normal; color:red'" />
         <xsl:choose>
            <xsl:when test="normalize-space(.)">
               <xsl:apply-templates mode="html" />
            </xsl:when>
            <xsl:otherwise>
               <!-- empty gap -->
               <xsl:text> </xsl:text>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:element>
      <xsl:element name="span">
         <xsl:attribute name="class" select="'delim'" />
         <xsl:attribute name="style" select="'font-style:normal; color:red'" />
         <xsl:text>-&lt;</xsl:text>
      </xsl:element>

   </xsl:template>

   <xsl:template match="*:choice" mode="html">

      <!--
         Various cases possible. Currently handle
         - sic/corr
         - unclear/unclear (as two alternatives)
      -->

      <xsl:choose>
         <xsl:when test="normalize-space(*:corr)">
            <!-- i.e. corr must have content -->
            <xsl:choose>
               <xsl:when test="*:sic">
                  <!-- sic present, so display corr with sic in mouseover content -->
                  <xsl:element name="span">
                     <xsl:attribute name="class" select="'corr'" />
                     <!-- <xsl:attribute name="style" select="'font-style:normal; color:green'" /> -->
                     <xsl:attribute name="style" select="'font-style:normal'" />
                     <xsl:attribute name="title">
                        <xsl:text>This text provided as correction; original text: </xsl:text>
                        <xsl:value-of select="*:sic" />
                     </xsl:attribute>
                     <xsl:apply-templates select="*:corr" mode="html" />
                  </xsl:element>
               </xsl:when>
               <xsl:otherwise>
                  <!-- no sic so just display corr -->
                  <xsl:element name="span">
                     <xsl:attribute name="class" select="'corr'" />
                     <xsl:attribute name="title" select="'This text provided as correction'" />
                     <xsl:apply-templates select="*:corr" mode="html" />
                  </xsl:element>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:when>
         <xsl:when test="count(*:unclear) = 2">
            <!-- two unclears as alternatives, so display first and include second in mouseover -->
            <xsl:element name="span">
               <xsl:attribute name="class" select="'delim'" />
               <xsl:attribute name="style" select="'font-style:normal; color:red'" />
               <xsl:text>[</xsl:text>
            </xsl:element>
            <xsl:element name="span">
               <xsl:attribute name="class" select="'unclear'" />
               <xsl:attribute name="style" select="'font-style:normal;'" />
               <xsl:attribute name="title">
                  <xsl:text>This text imperfectly legible in source; possible alternative: </xsl:text>
                  <xsl:value-of select="*:unclear[2]" />
               </xsl:attribute>
               <xsl:value-of select="*:unclear[1]" />
            </xsl:element>
            <xsl:element name="span">
               <xsl:attribute name="class" select="'delim'" />
               <xsl:attribute name="style" select="'font-style:normal; color:red'" />
               <xsl:text>]</xsl:text>
            </xsl:element>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates mode="html" />
         </xsl:otherwise>
      </xsl:choose>

   </xsl:template>

   <xsl:template match="*:corr" mode="html">

      <xsl:apply-templates mode="html" />

   </xsl:template>

   <xsl:template match="*:desc" mode="html">

      <xsl:apply-templates mode="html" />

   </xsl:template>

   <xsl:template match="text()" mode="html">

      <xsl:variable name="translated" select="translate(., '^&#x00A7;', '&#x00A0;&#x30FB;')" />
<!--      <xsl:variable name="replaced" select="replace($translated, '&#x005F;&#x005F;&#x005F;', '&#x2014;&#x2014;&#x2014;')" /> -->
      <xsl:variable name="replaced" select="replace($translated, '_ _ _', '&#x2014;&#x2014;&#x2014;')" />
      <xsl:value-of select="$replaced" />

   </xsl:template>


   <xsl:template match="*:head" mode="html">

      <xsl:element name="br" />

      <xsl:element name="p">

         <xsl:if test="@rend='center'">
            <!--<xsl:attribute name="style" select="'text-align: center'"/>-->
            <xsl:attribute name="style" select="'margin-left: 200px;'"/>

         </xsl:if>


         <xsl:element name="b">
            <xsl:apply-templates mode="html" />
         </xsl:element>
      </xsl:element>

   </xsl:template>

   <xsl:template match="*:listBibl" mode="html">

      <xsl:element name="div">
         <xsl:attribute name="style" select="'list-style-type: disc;'"/>
         <xsl:apply-templates select=".//*:bibl|.//*:biblStruct" mode="html" />
      </xsl:element>

   </xsl:template>


   <xsl:template match="*:listBibl//*:bibl" mode="html">

      <xsl:element name="div">
         <xsl:attribute name="style" select="'display: list-item; margin-left: 20px;'"/>
         <xsl:apply-templates mode="html" />
      </xsl:element>

   </xsl:template>


   <xsl:template match="*:listBibl//*:biblStruct[*:analytic]" mode="html">

      <xsl:element name="div">
         <xsl:attribute name="style" select="'display: list-item; margin-left: 20px;'"/>

         <xsl:choose>
            <xsl:when test="@xml:id">
               <xsl:attribute name="id" select="normalize-space(@xml:id)" />
            </xsl:when>
            <xsl:when test="*:idno[@type='callNumber']">
               <xsl:attribute name="id" select="normalize-space(*:idno)" />
            </xsl:when>
         </xsl:choose>


      <xsl:choose>
         <xsl:when test="@type='bookSection' or @type='encyclopaediaArticle' or @type='encyclopediaArticle'">

            <xsl:for-each select="*:analytic">

               <xsl:for-each select="*:author|*:editor">

                  <xsl:call-template name="get-names-first-surname-first" />

               </xsl:for-each>

               <xsl:text>. </xsl:text>

               <xsl:for-each select="*:title">

                  <xsl:text>&quot;</xsl:text>
                  <xsl:value-of select="normalize-space(.)" />
                  <xsl:text>&quot;</xsl:text>

               </xsl:for-each>

            </xsl:for-each>

            <xsl:text>. In </xsl:text>

            <xsl:for-each select="*:monogr">

               <xsl:for-each select="*:title">

                  <xsl:element name="i">
                  <xsl:value-of select="normalize-space(.)" />
                  </xsl:element>

               </xsl:for-each>

               <xsl:if test="*:author">
                  <xsl:text>, by </xsl:text>

                  <xsl:for-each select="*:author">

                     <xsl:call-template name="get-names-all-forename-first" />

                  </xsl:for-each>

               </xsl:if>

               <xsl:if test="*:editor">
                  <xsl:text>, edited by </xsl:text>

                  <xsl:for-each select="*:editor">

                     <xsl:call-template name="get-names-all-forename-first" />

                  </xsl:for-each>

               </xsl:if>

               <xsl:if test="*:edition">
                  <xsl:text> </xsl:text>
                  <xsl:value-of select="*:edition" />
               </xsl:if>

               <xsl:text>.</xsl:text>

               <xsl:if test="*:respStmt">

                  <xsl:for-each select="*:respStmt">

                     <xsl:text> </xsl:text>

                     <xsl:call-template name="get-respStmt" />

                  </xsl:for-each>

               </xsl:if>

               <xsl:if test=".//*:biblScope">

                  <xsl:for-each select=".//*:biblScope">

                     <xsl:text> </xsl:text>

                     <xsl:if test="@type">
                        <xsl:value-of select="normalize-space(@type)" />
                        <xsl:text> </xsl:text>
                     </xsl:if>

                     <xsl:value-of select="normalize-space(.)" />

                  </xsl:for-each>

               </xsl:if>

               <xsl:text>.</xsl:text>

               <xsl:if test="*:imprint">

                  <xsl:text> </xsl:text>

                  <xsl:for-each select="*:imprint">

                     <xsl:call-template name="get-imprint" />

                  </xsl:for-each>

                </xsl:if>

            </xsl:for-each>

            <xsl:if test="*:series">

               <xsl:for-each select="*:series">

                  <xsl:text> </xsl:text>

                  <xsl:for-each select="*:title">

                     <xsl:element name="i">
                     <xsl:value-of select="normalize-space(.)" />
                     </xsl:element>

                  </xsl:for-each>

                  <xsl:if test=".//*:biblScope">

                     <xsl:for-each select=".//*:biblScope">

                        <xsl:text> </xsl:text>

                        <xsl:if test="@type">
                           <xsl:value-of select="normalize-space(@type)" />
                           <xsl:text> </xsl:text>
                        </xsl:if>

                        <xsl:value-of select="normalize-space(.)" />

                     </xsl:for-each>

                  </xsl:if>

               </xsl:for-each>

               <xsl:text>.</xsl:text>

            </xsl:if>

         </xsl:when>

         <xsl:when test="@type='journalArticle'">

            <xsl:for-each select="*:analytic">

               <xsl:for-each select="*:author|*:editor">

                  <xsl:call-template name="get-names-first-surname-first" />

               </xsl:for-each>

               <xsl:text>. </xsl:text>

               <xsl:for-each select="*:title">

                  <xsl:text>&quot;</xsl:text>
                  <xsl:value-of select="normalize-space(.)" />
                  <xsl:text>&quot;</xsl:text>

               </xsl:for-each>

            </xsl:for-each>

            <xsl:text>. </xsl:text>

            <xsl:for-each select="*:monogr">

               <xsl:for-each select="*:title">

                  <xsl:element name="i">
                  <xsl:value-of select="normalize-space(.)" />
                  </xsl:element>

               </xsl:for-each>

               <xsl:if test=".//*:biblScope">

                  <xsl:for-each select=".//*:biblScope">

                     <xsl:text> </xsl:text>

                     <xsl:if test="@type">
                        <xsl:value-of select="normalize-space(@type)" />
                        <xsl:text> </xsl:text>
                     </xsl:if>

                     <xsl:value-of select="normalize-space(.)" />

                  </xsl:for-each>

               </xsl:if>

               <xsl:text>.</xsl:text>

               <xsl:if test="*:imprint">

                  <xsl:text> </xsl:text>

                  <xsl:for-each select="*:imprint">

                     <xsl:call-template name="get-imprint" />

                  </xsl:for-each>

               </xsl:if>

            </xsl:for-each>

            <xsl:if test="*:series">

               <xsl:for-each select="*:series">

                  <xsl:text> </xsl:text>

                  <xsl:for-each select="*:title">

                     <xsl:element name="i">
                     <xsl:value-of select="normalize-space(.)" />
                     </xsl:element>

                  </xsl:for-each>

                  <xsl:if test=".//*:biblScope">

                     <xsl:for-each select=".//*:biblScope">

                        <xsl:text> </xsl:text>

                        <xsl:if test="@type">
                           <xsl:value-of select="normalize-space(@type)" />
                           <xsl:text> </xsl:text>
                        </xsl:if>

                        <xsl:value-of select="normalize-space(.)" />

                     </xsl:for-each>

                  </xsl:if>

               </xsl:for-each>

               <xsl:text>.</xsl:text>

            </xsl:if>

         </xsl:when>

         <xsl:otherwise>

         </xsl:otherwise>

      </xsl:choose>

      </xsl:element>

   </xsl:template>



   <xsl:template match="*:listBibl//*:biblStruct[*:monogr and not(*:analytic)]" mode="html">

      <xsl:element name="div">
         <xsl:attribute name="style" select="'display: list-item; margin-left: 20px;'"/>

         <xsl:choose>
            <xsl:when test="@xml:id">
               <xsl:attribute name="id" select="normalize-space(@xml:id)" />
            </xsl:when>
            <xsl:when test="*:idno[@type='callNumber']">
               <xsl:attribute name="id" select="normalize-space(*:idno)" />
            </xsl:when>
         </xsl:choose>

      <xsl:choose>
         <xsl:when test="@type='book' or @type='document' or @type='thesis' or @type='manuscript'">

            <xsl:for-each select="*:monogr">

               <xsl:choose>
                  <xsl:when test="*:author">

                     <xsl:for-each select="*:author">

                        <xsl:call-template name="get-names-first-surname-first" />

                     </xsl:for-each>

                     <xsl:text>. </xsl:text>

                     <xsl:for-each select="*:title">

                        <xsl:element name="i">
                        <xsl:value-of select="normalize-space(.)" />
                        </xsl:element>

                     </xsl:for-each>

                     <xsl:if test="*:editor">

                        <xsl:text>, edited by </xsl:text>

                        <xsl:for-each select="*:editor">

                           <xsl:call-template name="get-names-all-forename-first" />

                        </xsl:for-each>

                     </xsl:if>

                  </xsl:when>

                  <xsl:when test="*:editor">

                     <xsl:for-each select="*:editor">

                        <xsl:call-template name="get-names-first-surname-first" />

                     </xsl:for-each>

                     <xsl:text>, editor</xsl:text>

                     <xsl:if test="(count(*:editor) &gt; 1)">
                        <xsl:text>s</xsl:text>
                     </xsl:if>

                     <xsl:text>. </xsl:text>

                     <xsl:for-each select="*:title">

                        <xsl:element name="i">
                        <xsl:value-of select="normalize-space(.)" />
                        </xsl:element>

                     </xsl:for-each>

                  </xsl:when>

                  <xsl:otherwise>

                     <xsl:for-each select="*:title">

                        <xsl:element name="i">
                        <xsl:value-of select="normalize-space(.)" />
                        </xsl:element>

                     </xsl:for-each>

                  </xsl:otherwise>

               </xsl:choose>

               <xsl:if test="*:edition">
                  <xsl:text> </xsl:text>
                  <xsl:value-of select="*:edition" />
               </xsl:if>

               <xsl:text>.</xsl:text>

               <xsl:if test="*:respStmt">

                  <xsl:for-each select="*:respStmt">

                     <xsl:text> </xsl:text>

                     <xsl:call-template name="get-respStmt" />

                  </xsl:for-each>

               </xsl:if>

               <xsl:if test="*:imprint">

                  <xsl:for-each select="*:imprint">

                     <xsl:text> </xsl:text>

                     <xsl:call-template name="get-imprint" />

                  </xsl:for-each>

               </xsl:if>

            </xsl:for-each>

            <xsl:if test="*:series">

               <xsl:for-each select="*:series">

                  <xsl:text> </xsl:text>

                  <xsl:for-each select="*:title">

                     <xsl:element name="i">
                     <xsl:value-of select="normalize-space(.)" />
                     </xsl:element>

                  </xsl:for-each>

                  <xsl:if test=".//*:biblScope">

                     <xsl:for-each select=".//*:biblScope">

                        <xsl:text> </xsl:text>

                        <xsl:if test="@type">
                           <xsl:value-of select="normalize-space(@type)" />
                           <xsl:text> </xsl:text>
                        </xsl:if>

                        <xsl:value-of select="normalize-space(.)" />

                     </xsl:for-each>

                  </xsl:if>

               </xsl:for-each>

               <xsl:text>.</xsl:text>

            </xsl:if>

            <xsl:if test="*:idno[@type='ISBN']">

               <xsl:for-each select="*:idno[@type='ISBN']">

                  <xsl:text> ISBN: </xsl:text>
                  <xsl:value-of select="normalize-space(.)" />

               </xsl:for-each>

            </xsl:if>

         </xsl:when>

         <xsl:otherwise>

         </xsl:otherwise>
      </xsl:choose>


      </xsl:element>

   </xsl:template>

   <xsl:template name="get-names-first-surname-first">

      <xsl:choose>
         <xsl:when test="position() = 1">
            <!-- first author = surname first -->

            <xsl:choose>
               <xsl:when test=".//*:surname">
                  <!-- surname explicitly present -->

                  <xsl:for-each select=".//*:surname">
                     <xsl:value-of select="normalize-space(.)" />
                     <xsl:if test="not(position()=last())">
                        <xsl:text> </xsl:text>
                     </xsl:if>
                  </xsl:for-each>

                  <xsl:if test=".//*:forename">
                     <xsl:text>, </xsl:text>

                     <xsl:for-each select=".//*:forename">
                        <xsl:value-of select="normalize-space(.)" />
                        <xsl:if test="not(position()=last())">
                           <xsl:text> </xsl:text>
                        </xsl:if>
                     </xsl:for-each>

                  </xsl:if>

               </xsl:when>
               <xsl:when test="*:name[not(*)]">
                  <!-- just a name, not surname/forename -->

                  <xsl:for-each select=".//*:name[not(*)]">
                     <xsl:value-of select="normalize-space(.)" />
                     <xsl:if test="not(position()=last())">
                        <xsl:text> </xsl:text>
                     </xsl:if>
                  </xsl:for-each>

               </xsl:when>

               <xsl:otherwise>
                  <!-- forenames only? not sure what else to do but render them -->

                  <xsl:for-each select=".//*:forename">
                     <xsl:value-of select="normalize-space(.)" />
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
                        <xsl:value-of select="normalize-space(.)" />
                        <xsl:if test="not(position()=last())">
                           <xsl:text> </xsl:text>
                        </xsl:if>
                     </xsl:for-each>

                     <xsl:text> </xsl:text>

                 </xsl:if>

                  <xsl:for-each select=".//*:surname">
                     <xsl:value-of select="normalize-space(.)" />
                     <xsl:if test="not(position()=last())">
                        <xsl:text> </xsl:text>
                     </xsl:if>
                  </xsl:for-each>

               </xsl:when>
               <xsl:when test="*:name[not(*)]">
                  <!-- just a name, not forename/surname -->

                  <xsl:for-each select=".//*:name[not(*)]">
                     <xsl:value-of select="normalize-space(.)" />
                     <xsl:if test="not(position()=last())">
                        <xsl:text> </xsl:text>
                     </xsl:if>
                  </xsl:for-each>

               </xsl:when>
               <xsl:otherwise>
                  <!-- forenames only? not sure what else to do but render them -->

                  <xsl:for-each select=".//*:forename">
                     <xsl:value-of select="normalize-space(.)" />
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
         <xsl:when test="position() = 1" />
         <xsl:when test="position()=last()">
            <xsl:text> and </xsl:text>
         </xsl:when>
         <xsl:otherwise>
            <xsl:text>, </xsl:text>
         </xsl:otherwise>
      </xsl:choose>

      <xsl:for-each select=".//*:name[not(*)]">
         <xsl:value-of select="normalize-space(.)" />
         <xsl:if test="not(position()=last())">
            <xsl:text> </xsl:text>
         </xsl:if>
      </xsl:for-each>

      <xsl:for-each select=".//*:forename">
         <xsl:value-of select="normalize-space(.)" />
         <xsl:if test="not(position()=last())">
            <xsl:text> </xsl:text>
         </xsl:if>
      </xsl:for-each>

      <xsl:text> </xsl:text>

      <xsl:for-each select=".//*:surname">
         <xsl:value-of select="normalize-space(.)" />
         <xsl:if test="not(position()=last())">
            <xsl:text> </xsl:text>
         </xsl:if>
      </xsl:for-each>

   </xsl:template>

   <xsl:template name="get-imprint">

      <xsl:if test="*:pubPlace">
         <xsl:for-each select="*:pubPlace">
            <xsl:value-of select="normalize-space(.)" />
         </xsl:for-each>
         <xsl:text>: </xsl:text>
      </xsl:if>

      <xsl:if test="*:publisher">
         <xsl:for-each select="*:publisher">
            <xsl:value-of select="normalize-space(.)" />
         </xsl:for-each>
         <xsl:if test="*:date">
            <xsl:text>, </xsl:text>
         </xsl:if>
      </xsl:if>

      <xsl:if test="*:date">
         <xsl:for-each select="*:date">
            <xsl:value-of select="normalize-space(.)" />
         </xsl:for-each>
         <xsl:text>.</xsl:text>
      </xsl:if>

      <xsl:if test="*:note[@type='thesisType']">
         <xsl:for-each select="*:note[@type='thesisType']">
            <xsl:value-of select="normalize-space(.)" />
            <xsl:text> thesis</xsl:text>
         </xsl:for-each>
         <xsl:text>.</xsl:text>
      </xsl:if>

      <xsl:if test="*:note[@type='accessed']">
         <xsl:text> Accessed: </xsl:text>
         <xsl:for-each select="*:note[@type='accessed']">
            <xsl:value-of select="normalize-space(.)" />
         </xsl:for-each>
         <xsl:text>.</xsl:text>
      </xsl:if>

      <xsl:if test="*:note[@type='url']">
         <xsl:element name="a">
            <xsl:attribute name="target" select="'_blank'"/>
            <xsl:attribute name="class" select="'externalLink'"/>
            <xsl:attribute name="href">
               <xsl:value-of select="*:note[@type='url']" />
            </xsl:attribute>
            <xsl:value-of select="*:note[@type='url']" />
         </xsl:element>
      </xsl:if>

   </xsl:template>

   <xsl:template name="get-respStmt">

      <xsl:choose>
         <xsl:when test="*">
            <xsl:for-each select="*:resp">
               <xsl:value-of select="." />
               <xsl:text>: </xsl:text>
            </xsl:for-each>
            <xsl:for-each select=".//*:forename">
               <xsl:value-of select="." />
               <xsl:text> </xsl:text>
            </xsl:for-each>
            <xsl:for-each select=".//*:surname">
               <xsl:value-of select="." />
               <xsl:if test="not(position()=last())">
                  <xsl:text> </xsl:text>
               </xsl:if>
            </xsl:for-each>
            <xsl:for-each select=".//*:name[not(*)]">
               <xsl:value-of select="." />
               <xsl:if test="not(position()=last())">
                  <xsl:text> </xsl:text>
               </xsl:if>
            </xsl:for-each>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="." />
         </xsl:otherwise>
     </xsl:choose>

   </xsl:template>

   <xsl:template match="*:name[*:persName]">

      <xsl:element name="div">
         <xsl:attribute name="class" select="'value'" />

         <xsl:choose>
            <xsl:when test="*:persName[@type='standard']">
               <xsl:for-each select="*:persName[@type='standard']">
                  <xsl:value-of select="normalize-space(.)"/>
               </xsl:for-each>

            </xsl:when>
            <xsl:when test="*:persName[@type='display']">
               <xsl:for-each select="*:persName[@type='display']">
                  <xsl:value-of select="normalize-space(.)"/>
               </xsl:for-each>

            </xsl:when>
            <xsl:otherwise>
               <!-- No standard form, no display form, take whatever we've got? -->
               <xsl:for-each select="*:persName">
                  <xsl:value-of select="normalize-space(.)"/>
               </xsl:for-each>

            </xsl:otherwise>
         </xsl:choose>

      </xsl:element>

   </xsl:template>

   <xsl:template name="make-footer">

      <xsl:element name="div">
         <xsl:attribute name="class" select="'footer'" />
      </xsl:element>


   </xsl:template>


</xsl:stylesheet>
