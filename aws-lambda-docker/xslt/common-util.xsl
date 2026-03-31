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
           <xsl:when test="$repository=('Trinity College Library, Cambridge')">
               <xsl:text>https://www.trin.cam.ac.uk/library/wren-digital-library/</xsl:text>
           </xsl:when>
           <xsl:when test="starts-with($repository, 'Fitzwilliam Museum')">
               <xsl:text>https://www.fitzmuseum.cam.ac.uk/commercial-services/image-library/</xsl:text>
           </xsl:when>
           <xsl:when test="$repository='Pepys Library'">
               <xsl:text>https://www.magd.cam.ac.uk/pepys/photography/</xsl:text>
           </xsl:when>
           <xsl:when test="$repository='The John Rylands Library'">
               <xsl:text>https://www.library.manchester.ac.uk/search-resources/manchester-digital-collections/digitisation-services/copyright-and-licensing/</xsl:text>
           </xsl:when>
           <xsl:when test="$repository='Ancient India and Iran Trust'">
               <xsl:text>https://www.indiran.org/library/</xsl:text>
           </xsl:when>
           <xsl:when test="$repository='Cavendish Laboratory'">
               <xsl:text>https://www.phy.cam.ac.uk/about/photo-archive-and-filming/image-request-form/</xsl:text>
           </xsl:when>
           <xsl:when test="$repository='Department of Engineering'">
               <xsl:text>https://www.indiran.org/library/</xsl:text>
           </xsl:when>
           <xsl:when test="$repository='Girton College Archive, Cambridge'">
               <xsl:text>https://www.girton.cam.ac.uk/about-girton/library-archive/archive-special-collections#copying-or-publishing-material</xsl:text>
           </xsl:when>
           <xsl:when test="$repository='Downing College Archive'">
               <xsl:text>https://www.dow.cam.ac.uk/about/downing-college-archive</xsl:text>
           </xsl:when>
           <xsl:when test="$repository='Faculty of Classics Archives, University of Cambridge'">
               <xsl:text>https://www.classics.cam.ac.uk/library/archives</xsl:text>
           </xsl:when>
           <xsl:when test="$repository='Gonville and Caius College, Lower Library'">
               <xsl:text>https://www.cai.cam.ac.uk/discover/library/contacting-library</xsl:text>
           </xsl:when>
           <xsl:when test="normalize-space($repository)='Needham Research Institute'">
               <xsl:text>https://www.nri.cam.ac.uk/</xsl:text>
           </xsl:when>
           <xsl:when test="$repository=('King''s College Library', 'King''s College Archive Centre, Cambridge')">
               <xsl:text>https://www.kings.cam.ac.uk/using-archives</xsl:text>
           </xsl:when>
           <xsl:when test="$repository='Newnham College Library'">
               <xsl:text>https://newn.cam.ac.uk/student-hub/newnham-college-library</xsl:text>
           </xsl:when>
           <xsl:when test="$repository='Newnham College Archive, Cambridge'">
               <xsl:text>https://newn.cam.ac.uk/research/college-archive</xsl:text>
           </xsl:when>
           <xsl:when test="$repository='Skilliter Centre Research Library and Archives'">
               <xsl:text>https://newn.cam.ac.uk/research/skilliter-centre</xsl:text>
           </xsl:when>
           <xsl:when test="$repository=('Pembroke College Library', 'Pembroke College Library: on long-term deposit at Cambridge University Library', 'Pembroke College Archives')">
               <xsl:text>https://www.pem.cam.ac.uk/college/library/archives-special-collections</xsl:text>
           </xsl:when>
           <xsl:when test="$repository='St Catharine''s College Library'">
               <xsl:text>https://www.caths.cam.ac.uk/college-life/library/special-collections</xsl:text>
           </xsl:when>
           <xsl:when test="$repository='Trinity Hall Library'">
               <xsl:text>http://www.trinhall.cam.ac.uk/about/library/old-library/special-collections</xsl:text>
           </xsl:when>
           <xsl:when test="$repository='Trinity Hall Archive'">
               <xsl:text>https://www.trinhall.cam.ac.uk/about/library/archives/access-and-enquiries/</xsl:text>
           </xsl:when>
           <xsl:when test="$repository='Westminster College, Cambridge'">
               <xsl:text>https://www.westminster.cam.ac.uk/library-archives-history/visiting-and-contacting-us</xsl:text>
           </xsl:when>
           <xsl:when test="$repository='Christ''s College Library'">
               <xsl:text>https://www.christs.cam.ac.uk/library-contactus</xsl:text>
           </xsl:when>
           <xsl:when test="$repository=('Clare College Library', 'Clare College Library')">
               <xsl:text>https://www.clare.cam.ac.uk/about/college-history/college-archives</xsl:text>
           </xsl:when>
           <xsl:when test="normalize-space($repository)='Cambridge University: Kettle''s Yard Museum and Art Gallery'">
               <xsl:text>https://www.kettlesyard.cam.ac.uk/about-us/#image-licensing</xsl:text>
           </xsl:when>
           <xsl:when test="$repository=('Perne Library, Peterhouse', 'Peterhouse Library', 'Perne Library: on long-term deposit at Cambridge University Library')">
               <xsl:text>https://www.pet.cam.ac.uk/libraries-and-archives</xsl:text>
           </xsl:when>
           <xsl:when test="$repository=('Queens'' College Library')">
               <xsl:text>https://www.queens.cam.ac.uk/life-at-queens/library/library-and-archives-staff/</xsl:text>
           </xsl:when>
           <xsl:when test="$repository=('Sidney Sussex College, Cambridge', 'Sidney Sussex College Library', 'Sidney Sussex College Muniment Room')">
               <xsl:text>https://www.sid.cam.ac.uk/life-sidney/library/special-collections</xsl:text>
           </xsl:when>
           <xsl:when test="$repository=('St John''s College Library')">
               <xsl:text>https://archives.joh.cam.ac.uk/contact</xsl:text>
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
