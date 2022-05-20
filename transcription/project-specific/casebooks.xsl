<?xml version="1.0"?>
<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:mml="http://www.w3.org/1998/Math/MathML"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:functx="http://www.functx.com"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:teix="http://www.tei-c.org/ns/Examples"
  xmlns:cudl="http://cudl.cam.ac.uk/xtf/"
  xmlns="http://www.w3.org/1999/xhtml"
  exclude-result-prefixes="#all">
  
  <xsl:variable name="special_app_children" select="('handShift','lacunaStart','lacunaEnd','witStart','witEnd')"/>
  
  <xsl:variable name="witnesses" select="$listWit/tei:witness/concat('#',@xml:id)"/>
  
  <xsl:variable name="witness_names" as="item()+">
    <xsl:for-each select="$witnesses">
      <xsl:variable name="id" select="."/>
      
      <xsl:variable name="idno" select="$listWit/tei:witness[@xml:id=replace($id,'^#','')]/tei:msDesc/tei:msIdentifier[1]/tei:idno" as="node()"/>
      <xsl:variable name="short_name" select="replace(string-join($idno//text(),''),'^([^,]+),.*$','$1')"/>
      <xsl:element name="idno">
        <xsl:attribute name="short_name" select="$short_name"/>
        <xsl:attribute name="pointer_to" select="$id"/>
        <xsl:call-template name="apply-mode-to-templates">
          <xsl:with-param name="displayMode" select="$viewMode"/>
          <xsl:with-param name="node" select="$idno"/>
        </xsl:call-template>
      </xsl:element>
    </xsl:for-each>
  </xsl:variable>
  
  <xsl:variable name="listWit" select="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:listWit"/>
  
  <xsl:template match="
    tei:pb[$project_name = 'casebooks project'][@sameAs | @xml:id][not(@xml:id = $requested_pb/@xml:id)][not(@prev = concat('#', $requested_pb/@xml:id))][@edRef][not(tokenize(@edRef,'\s+')=tokenize(@bestText,'\s+'))][ancestor::tei:div] |
    tei:cb[$project_name = 'casebooks project'][@sameAs | @xml:id][ancestor::tei:div][@edRef][not(tokenize(@edRef,'\s+')=tokenize(@bestText,'\s+'))] |
    tei:milestone[$project_name = 'casebooks project'][@sameAs | @xml:id][ancestor::tei:div][@edRef][not(tokenize(@edRef,'\s+')=tokenize(@bestText,'\s+'))]" />
    
  
  
  <xsl:template match="
      tei:pb[$project_name = 'casebooks project'][@sameAs | @xml:id][not(@xml:id = $requested_pb/@xml:id)][not(@prev = concat('#', $requested_pb/@xml:id))][ancestor::tei:div] |
      tei:cb[$project_name = 'casebooks project'][@sameAs | @xml:id][ancestor::tei:div] |
      tei:milestone[$project_name = 'casebooks project'][@sameAs | @xml:id][ancestor::tei:div]" priority="1" mode="diplomatic normalised">
    <!--<xsl:if test="not(@edRef) or tokenize(@edRef,'\s+')=tokenize(@bestText,'\s+')">-->
    <xsl:variable name="elem" select="."/>
    <xsl:variable name="pageNum">
      <xsl:call-template name="formatPageId">
        <xsl:with-param name="elem" select="
            if ($elem[@n]) then
              $elem
            else
              if ($elem[@sameAs]) then
                key('milestones_id', $elem/@sameAs)
              else
                ()"/>
      </xsl:call-template>
    </xsl:variable>

    <xsl:variable name="bestText_elem">
      <xsl:if test="tokenize(@edRef, '\s+') = tokenize(@bestText, '\s+')">
        <span class="smallcaps">
          <xsl:variable name="unique_wit_names" select="cudl:get_unique_witness_names(tokenize(@edRef, '\s+'))"/>
          <xsl:value-of select="cudl:write_shelfmark_list($unique_wit_names)"/>
        </span>
        <xsl:text>, </xsl:text>
      </xsl:if>
    </xsl:variable>

    <xsl:copy-of select="$bestText_elem"/>
    <xsl:value-of select="$pageNum"/>

    <!--</xsl:if>-->
  </xsl:template>
  
  
  <xsl:template match="tei:rdg[$project_name='casebooks project'][not(@type=('substantive', 'hisubs'))]" mode="#default normalised diplomatic"/>

  <xsl:template match="tei:milestone[@unit=('question','subsequentInfo','question','judgment','urineInfo','financialInfo','subsequentEventInfo','treatment')][$project_name='casebooks project']" mode="#all"/>
  
  <!-- Within the CB collection, none of these elements will occur outside app.
     However, I thought it was worthwhile to include this template in the XSLT
     since it provides for a nice textual message should one ever occur.
-->
  <xsl:template match="tei:*[self::tei:lacunaStart|self::tei:lacunaEnd|self::tei:witStart|self::tei:witEnd][$project_name='casebooks project'][not(ancestor::tei:lem|ancestor::tei:rdg)]" mode="diplomatic normalised">
    <xsl:variable name="element_name" select="local-name()"/>
    <xsl:variable name="wit_attr" select="ancestor::*[local-name()=('rdg','lem')][1]/@wit"/>
    <xsl:variable name="noun">
      <xsl:choose>
        <xsl:when test="matches($element_name,'^lacuna')">lacuna</xsl:when>
        <xsl:when test="matches($element_name,'^wit')">witness</xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="verb">
      <xsl:choose>
        <xsl:when test="matches($element_name,'End$')">ends</xsl:when>
        <xsl:when test="matches($element_name,'Start$')">starts</xsl:when>
      </xsl:choose>
    </xsl:variable>
    <span class="editorialGloss pagenum">
      <xsl:text>&lt;</xsl:text>
      <xsl:text>The </xsl:text>
      <xsl:value-of select="$noun"/>
      <xsl:text> in </xsl:text>
      <xsl:for-each select="tokenize($wit_attr,'\s+')">
        <xsl:variable name="i" select="."/>
        <xsl:if test="not(position()=1)"><xsl:text>, </xsl:text></xsl:if>
        <xsl:value-of select="$witness_names[@pointer_to= $i]/@short_name"/>
      </xsl:for-each>
      <xsl:text> </xsl:text>
      <xsl:value-of select="$verb"/>
      <xsl:text> here</xsl:text>
      <xsl:text>&gt;</xsl:text>
    </span>
  </xsl:template>
  
  <xsl:template match="tei:handShift[$project_name='casebooks project'][not(ancestor::tei:lem|ancestor::tei:rdg)]|
    tei:handShift[$project_name='casebooks project'][(ancestor::tei:lem|ancestor::tei:rdg)[cudl:contains-text-or-displayable-elem(.)]]" mode="#all">
    <span class="editorialGloss pagenum">
      <xsl:text>&lt;</xsl:text>
      <xsl:value-of select="cudl:write_handShift_msg(., false())"/>
      <xsl:text>&gt;</xsl:text>
    </span>
  </xsl:template>  
  
  <!-- HERE BE DRAGONS....
       The following code concerns the rendering of TEXT5 - a genetic edition that is comprised of approximately half a dozen
       different manuscripts with all their variant readings coded.
       This code takes that dense transcription and renders the different readings in a concise and (I'm proud to say) aesthetically
       pleasing fashion.
  -->
  
  <!-- TODO MJH: This text needs changing or updating so that I can present singular and plural messages once the transcription of TEXT5 is completed and it's ready to go live -->
  <xsl:variable name="app_mouseover">This passage contains a variety of readings from different manuscripts</xsl:variable>
  
  <xsl:template name="construct_app_text">
    <xsl:param name="app"/>
    
    <xsl:if test="$app[descendant::*[local-name()=$special_app_children]]">
      <xsl:variable name="msg" as="xs:string*">
        <xsl:for-each select="$app//*[local-name()=$special_app_children[not(.='handShift')]]">
          <xsl:value-of select="cudl:write_lacuna_or_witness_msg(., position())"/>
        </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="msg2">
        <xsl:for-each select="$app[(tei:lem|tei:rdg)[(not(cudl:contains-text-or-displayable-elem(.))) or @type[not(.=('substantive', 'hisubs'))]]]//tei:handShift">
          <xsl:sort select="min(for $x in tokenize((ancestor::tei:lem|ancestor::tei:rdg)[1]/@wit,'\s+') return index-of($witnesses,$x))[1]"/>
          <xsl:value-of select="cudl:write_handShift_msg(., true())"/>
        </xsl:for-each>
      </xsl:variable>
      <!-- Strictly speaking, I should do:
       lacunaEnd, witStart first
       then process app (which might have text). The two items there cannot have text before them
       then
       lacunaStart, witEnd.
       The problem will be not repeating the base-text notice. It might have to be get lacuna msg, get base_text message. Output it. Process APP (if texty) then get text of final message. concat it with '.'.
       -->
      <xsl:variable name="final_msg" select="string-join(($msg, $msg2),' ')"/>
      
      <xsl:if test="$final_msg!=''">
        <span class="editorialGloss pageNum">
          <xsl:text>&lt;</xsl:text>
          <xsl:value-of select="string-join(($msg, $msg2),' ')"/>
          <xsl:text>&gt;</xsl:text>
        </span>
      </xsl:if>
    </xsl:if>
  </xsl:template>
  
  <!-- app contains special element that is in otherwise empty container:
  Display special message
  Then process app - let templates sort out details
  Must refine xpath:
  app with rdg/lem that contains child but is otherwise empty - no text, no texty empty elements
  -->
  <xsl:template match="tei:app[$project_name='casebooks project'][*[.//*[local-name()=$special_app_children][(not(cudl:contains-text-or-displayable-elem(.))) or @type[not(.=('substantive', 'hisubs'))]]]]" mode="diplomatic normalised" priority="2">
    <xsl:call-template name="construct_app_text">
      <xsl:with-param name="app" select="."/>
    </xsl:call-template>
    <xsl:next-match />
  </xsl:template>
  
  <!-- App DOES NOT contain special element in otherwise empty container
  Process app - let templates sort out the details
  refine xpath to reflect truly empty container.
  -->
  <xsl:template match="tei:app[$project_name='casebooks project'][not(descendant::*[local-name()=$special_app_children][not(cudl:contains-text-or-displayable-elem(.))])]" mode="normalised diplomatic" priority="2">
    <xsl:next-match />
  </xsl:template>
  
  <xsl:template match="tei:app[$project_name='casebooks project'][not(tei:rdg[@type=('substantive', 'hisubs')])][tei:lem[not(cudl:contains-text-or-displayable-elem(.))]]" mode="diplomatic normalised" priority="1" />
  
  <xsl:template match="tei:lem[$project_name='casebooks project']" mode="diplomatic normalised">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xsl:template match="tei:rdg[$project_name='casebooks project']" mode="app-rdg-add">
    <xsl:call-template name="apply-mode-to-templates">
      <xsl:with-param name="displayMode" select="$viewMode"/>
      <xsl:with-param name="node" select="*|text()"/>
    </xsl:call-template>
    <xsl:variable name="action">
      <xsl:choose>
        <xsl:when test="cudl:contains-text-or-displayable-elem(.)"><xsl:text>add. </xsl:text></xsl:when>
        <xsl:when test="not(cudl:contains-text-or-displayable-elem(.))"><xsl:text>om. </xsl:text></xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:variable>
    <xsl:text> </xsl:text>
    <em class="smaller smallcaps">
      <xsl:text>[</xsl:text>
      <xsl:value-of select="$action"/>
      <xsl:variable name="unique_wit_names" select="cudl:get_unique_witness_names(tokenize(@wit,'\s+'))"/>
      <xsl:value-of select="cudl:write_shelfmark_list($unique_wit_names)"/>
      <xsl:text>]</xsl:text>
    </em>
  </xsl:template>
  
  <xsl:template match="tei:lem[$project_name='casebooks project']|tei:rdg[$project_name='casebooks project']" mode="app-rdg-texty">
    <xsl:call-template name="apply-mode-to-templates">
      <xsl:with-param name="displayMode" select="$viewMode"/>
      <xsl:with-param name="node" select="*|text()"/>
    </xsl:call-template>
    <xsl:variable name="action">
      <xsl:choose>
        <xsl:when test="cudl:contains-text-or-displayable-elem(.)"></xsl:when>
        <xsl:otherwise><xsl:text>om. </xsl:text></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:text> </xsl:text>
    <em class="smaller smallcaps">
      <xsl:text>[</xsl:text>
      <xsl:value-of select="$action"/>
      <xsl:variable name="unique_wit_names" select="cudl:get_unique_witness_names(tokenize(@wit,'\s+'))"/>
      <xsl:value-of select="cudl:write_shelfmark_list($unique_wit_names)"/>
      <xsl:text>]</xsl:text>
    </em>
  </xsl:template>
  
  <xsl:template name="iterate_texty_rdg">
    <xsl:param name="elem"/>
    <xsl:param name="lem_empty" select="false()"/>
    <xsl:for-each select="$elem[@type=('substantive', 'hisubs')]">
      <xsl:sort select="min(for $x in tokenize(@wit,'\s+') return index-of($witnesses,$x))[1]"/>
      <xsl:if test="not(position()=1)">
        <span class="delim">|</span>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="$lem_empty=false()">
          <xsl:apply-templates select="." mode="app-rdg-texty"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="." mode="app-rdg-add"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>
  
  <!-- do texty app -->
  <xsl:template match="tei:app[$project_name='casebooks project'][tei:rdg[@type=('substantive', 'hisubs')]][(tei:lem|tei:rdg[@type=('substantive', 'hisubs')])[cudl:contains-text-or-displayable-elem(.)]]" mode="diplomatic" priority="1">
    <!-- if it's texty or contains an elemen apart from the special suspects ... ouput it -->
    <xsl:variable name="huh" select="generate-id(current())"/>
    <span class="lemapp-n" title="{$app_mouseover}">
      <xsl:choose>
        <xsl:when test="tei:lem[normalize-space() or child::*]">
          <span class="delim">|</span>
          <xsl:apply-templates select="tei:lem" mode="app-rdg-texty"/>
          <span class="delim">|</span>
          <xsl:call-template name="iterate_texty_rdg">
            <xsl:with-param name="elem" select="tei:rdg[@type=('substantive', 'hisubs')]"/>
            <xsl:with-param name="lem_empty" select="false()"/>
          </xsl:call-template>
          <span class="delim">|</span>
        </xsl:when>
        <xsl:when test="tei:lem[not(cudl:contains-text-or-displayable-elem(.))] and tei:rdg[@type=('substantive', 'hisubs')]">
          <span class="delim">|</span>
          <xsl:call-template name="iterate_texty_rdg">
            <xsl:with-param name="elem" select="tei:rdg[@type=('substantive', 'hisubs')]"/>
            <xsl:with-param name="lem_empty" select="true()"/>
          </xsl:call-template>
          <span class="delim">|</span>
        </xsl:when>
      </xsl:choose>
    </span>
  </xsl:template>
  
  <!-- app not contain relevant rdg but has texty lem -->
  <xsl:template match="tei:app[$project_name='casebooks project'][not(tei:rdg[@type=('substantive', 'hisubs')])][tei:lem[cudl:contains-text-or-displayable-elem(.)]]" mode="diplomatic" priority="1">
    <xsl:variable name="huh" select="generate-id(current())"/>
    <xsl:variable name="base" select="tokenize(@n,'\s+')"/>
    <xsl:choose>
      <xsl:when test="not(tei:lem/tokenize(@wit,'\s+')=$base)">
        <span class="lemapp-n"  title="{$app_mouseover}">
          <span class="delim">|</span>
          <xsl:apply-templates select="tei:lem" mode="app-rdg-texty"/>
          <span class="delim">|</span>
        </span></xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="tei:lem" mode="#current"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  
  <xsl:template match="tei:app[$project_name='casebooks project'][tei:lem[cudl:contains-text-or-displayable-elem(.)]]" mode="normalised" priority="1">
    <xsl:variable name="huh" select="generate-id(current())"/>
    <xsl:variable name="base" select="tokenize(@n,'\s+')"/>
    
    <xsl:choose>
      <xsl:when test="not(tei:lem/tokenize(@wit,'\s+')=$base)">
        <span class="lemapp-n"  title="{$app_mouseover}">
          <span class="delim">|</span>
          <xsl:apply-templates select="tei:lem" mode="app-rdg-texty"/>
          <span class="delim">|</span>
        </span></xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="tei:lem" mode="#current"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="tei:seg[$project_name='casebooks project'][@type='deprecation'][@subtype=('cb','pb','milestone')]" mode="#default diplomatic normalised">
    <xsl:variable name="element_name" select="cudl:determine-output-element-name(., 'span')"/>
    
    <xsl:element name="{$element_name}">
      <xsl:attribute name="class" select="'boundaryMarker'"/>
      <xsl:apply-templates mode="#current"/>
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="tei:seg[$project_name='casebooks project'][@type='deprecation'][not(@subtype=('cb','pb','milestone'))]" mode="#default diplomatic normalised">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xsl:template match="tei:app[$project_name='casebooks project'][tei:rdg[@type=('substantive', 'hisubs')]][tei:lem[not(cudl:contains-text-or-displayable-elem(.))] and tei:rdg[@type=('substantive', 'hisubs')][cudl:contains-text-or-displayable-elem(.)]]" mode="normalised" priority="1">
    <!-- if it's a substantial change AND lem is not text, iterate over the substantial rdg -->
    <span class="lemapp-n" title="{$app_mouseover}">
      <span class="delim">|</span>
      <xsl:call-template name="iterate_texty_rdg">
        <xsl:with-param name="elem" select="tei:rdg[@type=('substantive', 'hisubs')]"/>
        <xsl:with-param name="lem_empty" select="true()"/>
      </xsl:call-template>
      <span class="delim">|</span>
    </span>
  </xsl:template>
</xsl:stylesheet>