<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
   xmlns:date="http://exslt.org/dates-and-times"
   xmlns:parse="http://cdlib.org/xtf/parse"
   xmlns:xtf="http://cdlib.org/xtf"
   xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:cudl="http://cudl.cam.ac.uk/xtf/"
   xmlns:xs="http://www.w3.org/2001/XMLSchema"
   xmlns="http://www.w3.org/1999/xhtml"
   extension-element-prefixes="date"
   exclude-result-prefixes="#all">

   <!--<xsl:output method="html" version="5.0" indent="no" encoding="UTF-8" omit-xml-declaration="yes"/>-->
   <xsl:output method="html" indent="no" encoding="UTF-8" doctype-system="about:legacy-compat" omit-xml-declaration="yes"/>
   
   <xsl:param name="viewMode" select="'diplomatic'" />
   <xsl:param name="inTextMode" select="true()" />
   
   <xsl:include href="global-var.xsl"/>
   <xsl:include href="p5-transcription-body.xsl"/>
   <xsl:include href="p5-textual-notes.xsl"/>
   <xsl:include href="project-specific/cudl-legacy.xsl"/>
   <xsl:include href="project-specific/newton.xsl"/>
   <xsl:include href="project-specific/casebooks.xsl"/>
   <xsl:include href="project-specific/darwinCorrespondence.xsl"/>
   
   <xsl:variable name="project_name" select="cudl:determine-project(/*)" as="xs:string"/>
   <xsl:variable name="project_className" select="cudl:get-project-abbreviation(/*)" as="xs:string"/>
   
   <xsl:variable name="use_legacy_display" select="cudl:use-legacy-character-and-font-processing($project_name)" as="xs:boolean"/>
   <xsl:variable name="use_junicode" select="cudl:use-junicode($project_name)" as="xs:boolean"/>
   
   <xsl:variable name="has_stretchies" select="exists(/*[.//tei:hi[tokenize(@rend,'\s+')[matches(.,'stretchy(Horizontal|Vertical)')]]])"/>    
   <xsl:variable name="useMathJax" select="$has_stretchies or exists(/*[.//tei:formula/*:math])"/>
   <xsl:variable name="has_dropCap" select="exists(/tei:TEI[exists(descendant::tei:hi[@rend='dropCap'])])"/>
   
   <xsl:variable name="transcriber">
      <xsl:value-of select="//*:transcriber[1]"/>
   </xsl:variable>
   
   <xsl:variable name="requested_pb" select="(//*:text/*:body//*:pb)[1]"/>


   <xsl:template match="/">
      <html>
         <head>
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
            <title>
                <xsl:value-of select="concat('Folio ', $requested_pb/@n)"/>
            </title>
            <xsl:if test="$use_legacy_display eq true()">
               <link href="/cudl-resources/legacy-cudl/charis-sil.css" rel="stylesheet" type="text/css"/>
            </xsl:if>
            <xsl:if test="$use_junicode eq true()">
               <link href="/cudl-resources/stylesheets/junicode.css" rel="stylesheet" type="text/css"/>
            </xsl:if>
            <link href="/cudl-resources/stylesheets/texts.css" rel="stylesheet" type="text/css"/>
            <xsl:choose>
               <xsl:when test="$project_name='darwin correspondence project'">
                  <link href="/cudl-resources/stylesheets/darwinCorrespondence/texts.css" rel="stylesheet" type="text/css"/>
               </xsl:when>
               <xsl:when test="$project_name='newton project'">
                  <link href="/cudl-resources/stylesheets/newtonProject/texts.css" rel="stylesheet" type="text/css"/>
               </xsl:when>
               <xsl:when test="$project_name=('casebooks project')">
                  <link href="/cudl-resources/stylesheets/casebooksProject/casebooks-fonts.css" rel="stylesheet" type="text/css"/>
               </xsl:when>
            </xsl:choose>
         </head>
         
         <xsl:variable name="supplemental_class" as="xs:string*">
            <xsl:if test="$use_legacy_display eq true()">
               <xsl:sequence select="'charisSIL'" />
            </xsl:if>
         </xsl:variable>

         <body class="{string-join(($project_className,$supplemental_class)[.!=''],' ')}">
            <xsl:call-template name="make-header" />
            <xsl:call-template name="make-body" />
            <xsl:call-template name="make-footer" />
         </body>

      </html>

   </xsl:template>
   

   <xsl:template name="make-header">

      <div class="header">
         <xsl:choose>
            <xsl:when test="$transcriber='Corpus Coranicum'">
               <p style="text-align: right">
                  <xsl:text>Transcription by </xsl:text>
                  <a href="http://www.corpuscoranicum.de/" target="_blank">
                     <xsl:text>Corpus Coranicum</xsl:text>
                  </a>
               </p>
            </xsl:when>
            <xsl:otherwise>
               <p class="pagenum">
                  <xsl:text>&lt;</xsl:text>
                  <xsl:value-of select="$requested_pb/@n"/>
                  <xsl:text>&gt;</xsl:text>
               </p>
            </xsl:otherwise>
         </xsl:choose>
      </div>
   </xsl:template>

   <xsl:template name="make-body">
      <xsl:call-template name="apply-mode-to-templates">
         <xsl:with-param name="displayMode" select="$viewMode"/>
         <xsl:with-param name="node" select="//tei:text/tei:body"/>
      </xsl:call-template>
   </xsl:template>
   
   <xsl:template name="make-footer">
      <div class="footer"><xsl:text> </xsl:text></div>
   </xsl:template>

   <xsl:template match="tei:ref[not(@type)][not(exists(id(replace(@target,'^#',''))))]" mode="diplomatic normalised">
      <xsl:choose>
         <xsl:when test="normalize-space(@target)">
            <xsl:element name="a">
               <xsl:attribute name="target" select="'_blank'"/>
               <xsl:attribute name="class" select="'externalLink'"/>
               <xsl:attribute name="href" select="normalize-space(@target)"/>
               <xsl:apply-templates mode="#current" />
            </xsl:element>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates mode="#current" />
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   
   <xsl:template match="tei:ref[exists(id(replace(@target,'^#','')))]" mode="diplomatic normalised">
      <a class="superscript footnote_indicator" href="{@target}">
         <xsl:apply-templates mode="#current" />
      </a>
   </xsl:template>
   
   <xsl:template match="tei:text//tei:date|
                        tei:text//tei:name|
                        tei:text//tei:persName|
                        tei:text//tei:orgName|
                        tei:text//tei:att|
                        tei:text//tei:roleName|
                        tei:text//tei:w|
                        tei:text//tei:desc|
                        tei:text//tei:locus" mode="#all">
      <xsl:apply-templates mode="#current"/>
   </xsl:template>
   
   <!-- This might conflict with casebooks -->
   <xsl:template match="tei:graphic[not(@url)]" mode="#all">
      <xsl:if test="normalize-space(.)">
         <span class="graphic">
            <xsl:apply-templates mode="#current" />
         </span>
      </xsl:if>
   </xsl:template>
   
   <xsl:template match="tei:text//tei:title|
                         tei:text//tei:term" mode="#all">
      <!-- TODO: we need to debate the wisdom of assuming that content marked up
                 with these elements is necessarily to be rendered in italic. It
                 works for now, but it's quite possible to encounter texts where
                 these were marked up for their semantic significance not as a 
                 shortcut to a certain visual style
      -->
      <i>
         <xsl:apply-templates mode="#current" />
      </i>
   </xsl:template>
      
   <xsl:template match="tei:figure[not(*)]" mode="#all"/>
   
   
   <xsl:template match="//*:transcriber|//*:publisher" mode="#all"/>

</xsl:stylesheet>
