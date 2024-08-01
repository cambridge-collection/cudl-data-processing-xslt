<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.1" 
   xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:cudl="http://cudl.lib.cam.ac.uk/xtf/" 
   xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
   exclude-result-prefixes="#all"
   xmlns:lambda="http://cudl.lib.cam.ac.uk/lambda/">
   
   <xsl:include href="language.xsl"/>
   <!--Capitalises first letter of text-->
   <xsl:function name="cudl:capitalise-first">
      <xsl:param name="text" />
      
      <xsl:value-of select="concat(upper-case(substring($text,1,1)),substring($text, 2))" />
   </xsl:function>
   
   <!--Convert boolean to Yes/No -->
   <xsl:function name="cudl:convert-boolean-to-yes-no">
      <xsl:param name="var" />
      
      <xsl:choose>
         <xsl:when test="matches(normalize-space(string($var)), '^true$', 'i')">
            <xsl:sequence select="'Yes'"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:sequence select="'No'"/>
         </xsl:otherwise>
      </xsl:choose>
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
         <xsl:when test="$repository=('Corpus Christi College Cambridge Archives', 'Parker Library', 'Parker Library: on long-term deposit at Cambridge University Library')">
            <xsl:text>https://www.corpus.cam.ac.uk/parker-library/information-readers/image-and-filming-requests</xsl:text>
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
            <xsl:value-of select="$urltext"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:text>https://imagingservices.lib.cam.ac.uk/</xsl:text>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>
   
   <!--Gets text direction from language-->
   <xsl:function name="cudl:get-language-direction">
      <xsl:param name="languageCode" />
      
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
      
      <xsl:choose>
         <xsl:when test="normalize-space($languages-direction/languages/language[code=$languageCode]/direction)">
            <xsl:value-of select="normalize-space($languages-direction/languages/language[code=$languageCode]/direction)"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:text>L</xsl:text>
         </xsl:otherwise>
      </xsl:choose>
   
   </xsl:function>
   
   <xsl:function name="lambda:write-tei-services-link" as="xsd:string*">
      <xsl:param name="node" as="item()"/>
      <xsl:param name="type" as="xsd:string"/>
      
      <xsl:variable name="fileID" select="lambda:construct-output-filename-path($node, 'services')"/>
      
      <xsl:choose>
         <xsl:when test="namespace-uri($node) = 'http://www.tei-c.org/ns/1.0'">
            <xsl:choose>
               <xsl:when test="$type = ('', 'html_transcription')">
                  <xsl:value-of select="concat('/v1/transcription/tei/diplomatic/internal/', $fileID)"/>
               </xsl:when>
               <xsl:when test="$type = ('html_translation')">
                  <!-- Can it be /EN/tei/...? The tei/... is part of fileID -->
                  <xsl:value-of select="concat('/v1/translation/tei/', lambda:get-translation-lang-code($node), '/', $fileID)" />
               </xsl:when>
               <xsl:when test="$type = ('', 'page_xml_transcription')">
                  <!-- Determine services url -->
                  <xsl:value-of select="concat('/v1/transcription/tei/diplomatic/internal/', $fileID)"/>
               </xsl:when>
               <xsl:when test="$type = ('page_xml_translation')">
                  <!-- Determine services url -->
                  <xsl:value-of select="concat('/v1/translation/tei/', lambda:get-translation-lang-code($node), '/', $fileID)"/>
               </xsl:when>
               <xsl:when test="$type = ('metadata')">
                  <xsl:value-of select="concat('/v1/metadata/tei/', replace(tokenize($fileID,'/')[last()], '\.xml$', ''), '/')"/>
               </xsl:when>
            </xsl:choose>
         </xsl:when>
         <xsl:otherwise/>
      </xsl:choose>
   </xsl:function>
   
   <xsl:function name="lambda:construct-output-filename-path" as="xsd:string">
      <!-- XSL functions cannot have optional parameters, so it was necessary to create
           a version containing the two main parameters (node and mode) so that the main 
           function with three parameters could be called with the third value containing
           the default value of 'transcription'
      -->
           
      <xsl:param name="node" as="item()*"/>
      <xsl:param name="mode" as="xsd:string*"/>
      
      <xsl:value-of select="lambda:construct-output-filename-path($node, $mode, 'transcription')"/>
   </xsl:function>
   
   <xsl:function name="lambda:construct-output-filename-path" as="xsd:string">
      <xsl:param name="node" as="item()*"/>
      <xsl:param name="mode" as="xsd:string*"/>
      <xsl:param name="type" as="xsd:string*"/>
      
      <xsl:variable name="separator" as="xsd:string">
         <xsl:choose>
            <xsl:when test="$mode eq 'filename'">
               <xsl:text>-</xsl:text>
            </xsl:when>
            <xsl:otherwise>
               <xsl:text>/</xsl:text>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      
      <xsl:variable name="suffix" select="normalize-space($type[normalize-space(.) = 'translation'])" as="xsd:string*"/>
      <xsl:variable name="surfaceID" select="key('surfaceIDs',$node/@facs, root($node))/@xml:id"
         as="xsd:string*"/>
      
      <xsl:variable name="filename-root" select="replace(normalize-space(tokenize(document-uri(root($node)), '/')[last()]),'\..*$','')" as="xsd:string"/>
         
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
                  <xsl:sequence select="distinct-values(
                     ($node//ancestor::tei:div[tokenize(@decls,'\s+') = '#unpaginated']//tei:pb[replace(@facs,'^#','')= root($node)//tei:surface/@xml:id]/replace(@facs,'^#',''))[position() = (1, last())]
                     )"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:sequence select="$surfaceID"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>
         
         <xsl:value-of select="string-join(($filename-root, $surfaceID_final, $suffix)[.!=''],$separator)"/>
         
      </xsl:variable>
      
      
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
      
      <!-- Presume that if @next contains content that is accurate to increase excecution speed of script -->
      <xsl:sequence select="exists($context[normalize-space(@next)!=''])
                            or 
                            exists($context[normalize-space(@prev)!='']) 
                            or 
                            exists($context[not(ancestor::tei:add | ancestor::tei:note) 
                            and 
                            not(preceding::tei:addSpan/replace(normalize-space(@spanTo), '#', '') = following::tei:anchor/@xml:id)])"/>
   </xsl:function>
   
</xsl:stylesheet>