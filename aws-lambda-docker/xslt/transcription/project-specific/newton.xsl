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
  
  <xsl:key name="addSpans" match="tei:addSpan" use="tokenize(normalize-space(@spanTo),'\s+')" />
  
  <xsl:key name="anchor-targetting-elems" match="tei:delSpan[@target]|tei:note[@target]" use="tokenize(normalize-space(@target),'\s+')"/>
  <!-- Merge these keys? -->
  
  <xsl:template match="tei:g[@type='unknownSymbol'][$project_name='newton project']" mode="#all">
    <span class="flag" title="Symbol in text">
      <xsl:apply-templates mode="#current"/>
    </span>
  </xsl:template>
  
  <xsl:template match="tei:addSpan[$project_name='newton project']" mode="#all">
    <xsl:variable name="element_name" select="cudl:determine-output-element-name(., 'div')"/>
    
    <xsl:variable name="className">
      <xsl:choose>
        <xsl:when test="cudl:is-in-block(.)">
          <xsl:text>pagenumber-embed</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>pagenumber</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    
    <xsl:variable name="insertionPlace" select="normalize-space((@n,@place)[normalize-space(.)!=''][1])" />
    
    <xsl:element name="{$element_name}">
      <xsl:attribute name="class" select="$className" />
      <xsl:text> &lt; insertion from </xsl:text>
      <xsl:value-of select="$insertionPlace"/>
      <xsl:text> &gt; </xsl:text>
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="tei:anchor[key('addSpans',concat('#', @xml:id))][$project_name='newton project']" mode="#all">
    <xsl:variable name="element_name" select="cudl:determine-output-element-name(., 'div')" as="xs:string"/>
    
    <xsl:variable name="className" as="xs:string">
      <xsl:choose>
        <xsl:when test="cudl:is-in-block(.)">
          <xsl:text>pagenumber-embed</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>pagenumber</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    
    <xsl:variable name="anchor_label" as="xs:string">
      <xsl:variable name="page_label_before_addSpan" select="normalize-space(@n)"/>
      
      <xsl:variable name="result" as="xs:string*">
        <xsl:text> &lt; </xsl:text>
      <xsl:choose>
        <xsl:when test="$page_label_before_addSpan != ''">
          <xsl:text>text from </xsl:text>
          <xsl:value-of select="$page_label_before_addSpan"/>
          <xsl:text> resumes</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>insertion ends</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
        <xsl:text> &gt; </xsl:text>
      </xsl:variable>
      <xsl:value-of select="string-join($result,'')"/>
    </xsl:variable>
    
    <xsl:element name="{$element_name}">
      <xsl:attribute name="class" select="$className"/>
      <xsl:value-of select="$anchor_label"/>
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="tei:anchor[key('anchor-targetting-elems',concat('#',@xml:id))[self::tei:delSpan]][$project_name='newton project']" mode="#all">
    <!-- delSpan not supported as of yet -->
  </xsl:template>
  
  <xsl:template match="tei:app[@type='authorial'][$project_name='newton project']" mode="#all">
    <span class="app" title="The author presented alternate readings of this text.">
      <xsl:for-each select="tei:rdg">
        <xsl:variable name="css_class" as="xs:string">
          <xsl:choose>
            <xsl:when test="position() mod 2 = 1">
              <xsl:text>sub</xsl:text>
            </xsl:when>
            <xsl:when test="position() mod 2 = 0">
              <xsl:text>sup</xsl:text>
            </xsl:when>
          </xsl:choose>
        </xsl:variable>
        <span class="{$css_class}">
          <xsl:apply-templates mode="#current"/>
        </span>
        <xsl:if test="position()!=last()">
          <xsl:text>&#160;</xsl:text>
          <span class="nb-n">
            <xsl:text>|</xsl:text>
          </span>
          <xsl:text>&#160;</xsl:text>
        </xsl:if>
      </xsl:for-each>
    </span>
  </xsl:template>
  
  <xsl:template match="tei:rdg[$project_name='newton project']" mode="#all">
    <xsl:call-template name="apply-mode-to-templates">
      <xsl:with-param name="displayMode" select="$viewMode"/>
      <xsl:with-param name="node" select="*|text()"/>
    </xsl:call-template>
  </xsl:template>
  
  <xsl:template match="tei:delSpan[$project_name='newton project']" mode="#all">
    <!-- delSpan not supported as of yet -->
  </xsl:template>
  
  <xsl:template match="tei:gap[@reason='editorialDecision'][$project_name='newton project']" mode="#all">
    <xsl:variable name="element_name" select="cudl:determine-output-element-name(., 'div')"/>
    
    <xsl:element name="{$element_name}">
      <xsl:attribute name="class" select="'editorialdecision'" />
      <span class="gap">
        <xsl:attribute name="title">
          <xsl:text>The editor has omitted text from this transcription (Extent: </xsl:text>
          <xsl:value-of select="concat(@extent,' ',cudl:parseUnit(@unit,@extent),')')"/>
        </xsl:attribute>
        <xsl:text>{text not transcribed}</xsl:text>
      </span>
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="tei:sic[$project_name='newton project'][not(parent::tei:choice)]" mode="#all">
    <span class="sic" title="It is unclear how this text should be corrected">
      <xsl:apply-templates mode="#current" />
      <xsl:text>&#160;</xsl:text>
      <span class="nb-n">
        <xsl:text>{sic}</xsl:text>
      </span>
    </span>
  </xsl:template>
  
  <!-- This template is overriding the main one, which is a casebooks
       bit of code that ignores pb/cb outside of div. Once that template is
       migrated to casebooks.xsl, this one can be moved into the main file
       with a simplified xPath expression, although it'll still be 
       necessary to include a check for the presence of attrs to
       differentiate it from the one dealing with legacy cdl code
  -->
  <xsl:template match="tei:pb[@sameAs|@xml:id][not(@xml:id = $requested_pb/@xml:id)][not(@prev = concat('#',$requested_pb/@xml:id))][not(ancestor::tei:div)]|
    tei:cb[@sameAs|@xml:id][not(ancestor::tei:div)]" mode="#all">
      <xsl:variable name="elem" select="."/>
      <xsl:variable name="pageNum">
        <xsl:call-template name="formatPageId">
          <xsl:with-param name="elem" select="if ($elem[@n]) then $elem else if ($elem[@sameAs]) then key('milestones_id', $elem/@sameAs) else ()" />
        </xsl:call-template>
      </xsl:variable>
      
      <xsl:variable name="element_name" select="cudl:determine-output-element-name(., 'span')" />
      
      <xsl:variable name="classname">
        <xsl:text>boundaryMarker </xsl:text>
        <xsl:choose>
          <xsl:when test="cudl:is-in-block(.)">
            <xsl:text>inline</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>pagenum</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
    
      <xsl:variable name="optionalSpace">
        <xsl:if test="preceding-sibling::node()[(self::text() and matches(.,'\s$')) or (self::tei:lb and not((@rend,@type)[.='hyphenated']))]">
          <xsl:text> </xsl:text>
        </xsl:if>
      </xsl:variable>
      
      <xsl:if test=".//preceding::tei:*[1][name()='lb' and @rend='hyphenated']">
        <xsl:text>-</xsl:text>
      </xsl:if>
      <xsl:element name="{$element_name}">
        <xsl:attribute name="class" select="normalize-space($classname)"/>
        <xsl:if test="$elem[@xml:id|@sameAs]">
          <xsl:attribute name="id">
            <xsl:choose>
              <xsl:when test="$elem[@xml:id]">
                <xsl:value-of select="$elem/@xml:id"/>
              </xsl:when>
              <xsl:when test="$elem[@sameAs]">
                <xsl:variable name="sameAs_attr" select="@sameAs"/>
                <xsl:variable name="count">
                  <xsl:number format="1" level="any" count="key('milestones_id', $sameAs_attr)|key('milestones_sameAs', $sameAs_attr)"/>
                </xsl:variable>
                <xsl:value-of select="replace($sameAs_attr,'#','')"/>
                <xsl:text>-</xsl:text>
                <xsl:value-of select="$count"/>
              </xsl:when>
            </xsl:choose>
          </xsl:attribute>
        </xsl:if>
        <xsl:value-of select="$optionalSpace"/>
        <xsl:text>&lt;</xsl:text>
        <xsl:value-of select="$pageNum"/>
        <xsl:text>&gt;</xsl:text>
        <xsl:value-of select="$optionalSpace"/>
      </xsl:element>
    
  </xsl:template>
    
  <xsl:template match="tei:seg[$project_name='newton project'][@type=('floatingHead', 'head', 'line')]" mode="#all">
    <!-- 'para' occurs within CUDL transcription metadata -->
    <span class="{@type}">
      <xsl:apply-templates mode="#current"/>
    </span>
  </xsl:template>
  
  <xsl:template match="tei:figDesc[$project_name='newton project']" mode="#all">
    <!-- This template is never called in Newton -->
  </xsl:template>
  
</xsl:stylesheet>