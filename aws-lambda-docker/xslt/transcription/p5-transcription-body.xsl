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
  
  <xsl:preserve-space elements="teix:*"/>

  <xsl:include href="p5-functions-and-named-templates.xsl"/>
  <!-- variables needed to be defined for this sheet and included to be self-
       contained:
       viewMode: diplomatic|normalised
       inTextMode: true()
   -->
  
  <xsl:key name="milestones_id" match="tei:div//tei:pb|tei:div//tei:cb|tei:div//tei:milestone" use="concat('#',@xml:id)"/>
  <xsl:key name="milestones_sameAs" match="tei:div//tei:pb|tei:div//tei:cb|tei:div//tei:milestone" use="@sameAs"/>
  <xsl:key name="note-target" match="tei:text//tei:note" use="tokenize(@target,'\s+')"/>
  
  <xsl:variable name="hands" as="item()*">
    <xsl:for-each select="/tei:TEI/tei:teiHeader/tei:profileDesc/tei:handNotes/tei:handNote">
      <xsl:variable name="handNote" select="."/>
      <xsl:element name="handNote">
        <xsl:attribute name="pointer_to" select="$handNote/(concat('#',@xml:id),@sameAs)[.!='#'][1]"/>
        <xsl:call-template name="apply-mode-to-templates">
          <xsl:with-param name="displayMode" select="$viewMode"/>
          <xsl:with-param name="node" select="$handNote"/>
        </xsl:call-template>
      </xsl:element>
    </xsl:for-each>
  </xsl:variable>
  
  <xsl:template match="tei:body" mode="diplomatic normalised">
    <div class="body">
      <xsl:apply-templates mode="#current"/>
    </div>
    <xsl:call-template name="endnote"/>
    
    <xsl:if test="$useMathJax or $has_dropCap">
      <script src="https://code.jquery.com/jquery-3.5.1.min.js" integrity="sha256-9/aliU8dGd2tb6OSsuzixeV4y/faTqgFtohetphbbj0=" crossorigin="anonymous"/>
      <script src="/cudl-resources/javascript/jquery.inview/jquery.inview.min.js"/>
      <xsl:if test="$useMathJax">
        <script type="text/x-mathjax-config">
          <xsl:text disable-output-escaping="yes">MathJax.Hub.Register.StartupHook("End",function () {$('&lt;script>').attr('type', "text/javascript").attr('src', "/cudl-resources/javascript/stretchies.js").appendTo('body');});</xsl:text>
        </script>
      </xsl:if>
      <script type="text/javascript">
        <xsl:text disable-output-escaping="yes">$('body').on('inview', function(event, isInView) {</xsl:text>
        <xsl:text>&#10;</xsl:text>
        <xsl:text disable-output-escaping="yes">if (isInView &amp;&amp; ( $('#MathJax-script').length == 0 || $('#dropCap-script').length == 0)) {</xsl:text>
        <xsl:if test="$has_dropCap">
          <xsl:text>&#10;</xsl:text>
          <xsl:text disable-output-escaping="yes">$('&lt;script>').attr('id', "dropCap-script").attr('type', "text/javascript").attr('src', "/cudl-resources/javascript/dropcap/dropcap.min.js").appendTo('body');</xsl:text>
          <xsl:text>&#10;</xsl:text>
          <xsl:text>var dropcaps = document.querySelectorAll(".dropCap");</xsl:text>
          <xsl:text>window.Dropcap.layout(dropcaps, 3);</xsl:text>
        </xsl:if>
        <xsl:if test="$useMathJax">
          <xsl:text>&#10;</xsl:text>
          <xsl:text disable-output-escaping="yes">$('&lt;script>').attr('id', "MathJax-script").attr('type', "text/javascript").attr('async', 'async').attr('src', "https://cdn.jsdelivr.net/npm/mathjax@2/MathJax.js?config=MML_CHTML").appendTo('body');</xsl:text>
        </xsl:if>
        <xsl:text disable-output-escaping="yes">}});</xsl:text></script>
    </xsl:if>
  </xsl:template>


<!-- Basic Blocks -->
  <xsl:template match="tei:div" mode="#all">
    <xsl:choose>
      <xsl:when test="cudl:elem-empty-in-normalised-view(current())"/>
      <xsl:otherwise>
        <div>
          <xsl:call-template name="add-attr-if-exists">
            <xsl:with-param name="name" select="'id'"/>
            <xsl:with-param name="value" select="@xml:id"/>
          </xsl:call-template>
          <xsl:call-template name="add-attr-if-exists">
            <xsl:with-param name="name" select="'class'"/>
            <xsl:with-param name="value" select="@rend"/>
          </xsl:call-template>
          <xsl:apply-templates mode="#current"/>
        </div>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="tei:opener" mode="#all">
    <div class="opener">
      <xsl:apply-templates mode="#current"/>
    </div>
  </xsl:template>
  
  <!-- This template is explicitly only numbering paragraphs that occur within tei:text
       and which are NOT contained within notes
  -->
  <xsl:template match="tei:text//tei:p|tei:text//tei:ab[@type='p']|tei:text//tei:ab[not(@type) or not(normalize-space(@type))][not(cudl:is-in-block(.))]" mode="#all">
    <xsl:variable name="elem_name" as="xs:string">
      <xsl:choose>
        <xsl:when test="descendant::tei:cell[@rows|@cols]">
          <xsl:text>div</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="cudl:determine-output-element-name(., 'p')"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="paraAnchor">
      <xsl:choose>
        <xsl:when test="normalize-space(@facs) != ''">
          <xsl:value-of select="replace(normalize-space(@facs),'^#', '')"/>
        </xsl:when>
        <xsl:otherwise>
        <xsl:text>para</xsl:text>
      <xsl:number format="1" level="any" count="tei:text//tei:p[not(ancestor::tei:note)]|tei:text//tei:ab[@type='p'][not(ancestor::tei:note)]|tei:text//tei:ab[not(@type)][not(cudl:is-in-block(.))][not(ancestor::tei:note)]"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="cudl:elem-empty-in-normalised-view(current())"/>
      <xsl:otherwise>
        <xsl:element name="{$elem_name}">
          <xsl:if test="not(ancestor::tei:note)">
            <xsl:call-template name="add-attr-if-exists">
              <xsl:with-param name="name" select="'id'"/>
              <xsl:with-param name="value" select="((normalize-space(@xml:id),$paraAnchor)[.!=''])[1]"/>
            </xsl:call-template>
          </xsl:if>
          <xsl:attribute name="class" select="string-join(('paragraph', cudl:rendPara(normalize-space(@rend)[normalize-space(.)]),' '))" />
          <xsl:apply-templates select="@facs" mode="data-points"/>
          <xsl:apply-templates mode="#current"/>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="tei:table/tei:*[self::tei:head|self::tei:ab[@type='head']]" mode="#all">
    <caption><xsl:apply-templates mode="#current"/></caption>
  </xsl:template>

  <xsl:template match="tei:*[self::tei:head|self::tei:ab[@type='head']][not(ancestor::tei:figure)][not(parent::tei:table)]" mode="#all">
    <xsl:variable name="headAnchor">
      <xsl:text>head</xsl:text>
      <xsl:number format="1" count="tei:*[self::tei:head|self::tei:ab[@type='head']][not(ancestor::tei:figure)][not(parent::tei:table)]" level="any"/>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="cudl:elem-empty-in-normalised-view(current())"/>
      <xsl:otherwise>
        <!-- This variable offsets the count of the header in html BECAUSE transcriptions contain metatadat with an h1 already-->
        <xsl:variable name="header_offset">
          <xsl:choose>
            <xsl:when test="$inTextMode">1</xsl:when>
            <xsl:otherwise>0</xsl:otherwise>
          </xsl:choose>
        </xsl:variable>

        <xsl:variable name="classname">
          <xsl:text> </xsl:text>
          <xsl:value-of select="cudl:rendPara(@rend)"/>
        </xsl:variable>

        <xsl:variable name="level" select="count(ancestor::tei:div)"/>
        <xsl:variable name="header_number">
          <xsl:choose>
            <xsl:when test="($level+number($header_offset)) > 6">
              <xsl:text>6</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="$level+number($header_offset)"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:element name="h{$header_number}">
          <xsl:if test="not(ancestor::tei:note)">
            <xsl:call-template name="add-attr-if-exists">
              <xsl:with-param name="name" select="'id'"/>
              <xsl:with-param name="value" select="((normalize-space(@xml:id),$headAnchor)[.!=''])[1]"/>
            </xsl:call-template>
          </xsl:if>
          <xsl:attribute name="class" select="normalize-space($classname)"/>
          <xsl:apply-templates mode="#current"/>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Linking -->
  <!-- TODO: This template will need to be rewritten or abandoned utterly in CUDL
             since I doubt I could link directly to a case
  -->
  <xsl:template match="tei:ref[@type='case']" mode="#all">
    <!--<a href="/view/case/{$viewMode}/{@target}">-->
      <xsl:apply-templates mode="#current"/>
    <!--</a>-->
  </xsl:template>

  <xsl:template match="tei:choice[not(tei:unclear)]" mode="#default diplomatic normalised">
    <xsl:apply-templates select="*" mode="#current"/>
  </xsl:template>

  <xsl:template match="tei:choice[tei:unclear][count(child::*[local-name()!='unclear'])=0]" mode="#default diplomatic normalised">
    <span class="app" title="The editor is uncertain which of these possible readings is the correct one">
      <span class="delim">[</span>
      <xsl:for-each select="tei:unclear">
        <xsl:apply-templates select="." mode="#current" />
        <xsl:if test="position() ne last()">
          <xsl:text>&#160;</xsl:text>
          <span class="delim">
            <xsl:text>|</xsl:text>
          </span>
          <xsl:text>&#160;</xsl:text>
        </xsl:if>
      </xsl:for-each>
      <span class="delim">]</span>
    </span>
  </xsl:template>

  <xsl:template match="tei:supplied" mode="#all">
    <!-- Is this use of @source from casebooks or CDL
         It seems it might be from Casebooks
    -->
    <xsl:variable name="title">
      <xsl:choose>
        <xsl:when test="not(@source)">
          <xsl:text>This text has been supplied by the editor</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>This text has been supplied by </xsl:text>
          <xsl:value-of select="@source"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <span class="supplied" title="{$title}">
      <span class="delim">[</span>
      <xsl:apply-templates mode="#current"/>
      <span class="delim">]</span>
    </span>
  </xsl:template>

  <!-- Copy mathML directly into final document. It will either be displayed natively or parsed and displayed using mathJax.js -->
  <xsl:template match="tei:formula" mode="#all">
    <xsl:copy-of select="*" copy-namespaces="no"/>
  </xsl:template>

  <!-- Images -->
  
  <!-- NB: figure/@type is used to record the presence of charts within the case files and it should not be acted upon -->
  <xsl:template match="tei:figure[@type]" mode="#all" />
  
  <!-- TODO: This code needs to be rewritten so that it's less
             preoccupied with staying within the grid layout of the 
             old Casebooks site.
             It's not a high priority right now since there aren't
             ANY elements in the CDL Data that contain figure with
             a child
  -->
  
  <xsl:template match="tei:figure[not(@type)][*][tokenize(@rend,'\s+')='inline']" priority="2" mode="#all">
    <span>
      <xsl:if test="@xml:id">
        <xsl:attribute name="id" select="@xml:id"/>
      </xsl:if>
      <xsl:next-match />
    </span>
  </xsl:template>
  
  <xsl:template match="tei:figure[not(@type)][*][not(tokenize(@rend,'\s+')[matches(.,'^(inline|width\d+)$')])]" priority="2" mode="#all">
    <xsl:variable name="width_val" as="xs:string*">
      <xsl:if test="not(tokenize(@rend,'\s+')[matches(.,'^width\d+')]) and tei:graphic/@width !=''">
        <!--<xsl:value-of select="floor((number(replace(tei:graphic/@width,'px',''))+20) div $width-size)"/>-->
      </xsl:if>
    </xsl:variable>
    
    <xsl:variable name="position" as="xs:string*">
      <xsl:if test="@rend !=''">
        <xsl:variable name="rend_vals" select="tokenize(@rend,'\s+')"/>
        <xsl:choose>
          <xsl:when test="$rend_vals ='floatLeft'">
            <xsl:text>float left</xsl:text>
          </xsl:when>
          <xsl:when test="$rend_vals ='floatRight'">
            <xsl:text>float right</xsl:text>
          </xsl:when>
          <xsl:when test="$rend_vals ='block'">
            <xsl:text>float left</xsl:text>
          </xsl:when>
          <xsl:when test="$rend_vals =('blockCentered','blockCentred')">
            <xsl:text>blockCentered</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>float left</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:if>
    </xsl:variable>
    
    <xsl:variable name="image_type" select="if (matches(tei:graphic/@url,'\.svg')) then 'svg' else ()" as="xs:string*"/>
    <xsl:element name="{cudl:determine-output-element-name(., 'span')}">
      <xsl:if test="exists(($image_type,$width_val,$position,tokenize(@rend,'\s+')[not(.=('floatLeft','floatRight','blockCentered','blockCentred'))])[.!=''])">
        <xsl:attribute name="class" select="string-join(($image_type,$width_val,$position,tokenize(@rend,'\s+')[not(.=('floatLeft','floatRight','blockCentered','blockCentred'))],'image')[.!=''],' ')"/></xsl:if>
      <xsl:if test="@xml:id">
        <xsl:attribute name="id" select="@xml:id"/>
      </xsl:if>
      <xsl:next-match />
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="tei:figure[not(@type)][*][exists(tokenize(@rend,'\s+')[matches(.,'^width\d+$')])]" priority="2" mode="#all">
    <xsl:variable name="width_val" as="xs:string*">
      <xsl:if test="not(tokenize(@rend,'\s+')[matches(.,'^width\d+')]) and tei:graphic/@width !=''">
        <!--<xsl:value-of select="floor((number(replace(tei:graphic/@width,'px',''))+20) div $width-size)"/>-->
      </xsl:if>
    </xsl:variable>
    
    <xsl:variable name="position" as="xs:string*">
      <xsl:if test="@rend !=''">
        <xsl:variable name="rend_vals" select="tokenize(@rend,'\s+')"/>
        <xsl:choose>
          <xsl:when test="$rend_vals ='floatLeft'">
            <xsl:text>float left</xsl:text>
          </xsl:when>
          <xsl:when test="$rend_vals ='floatRight'">
            <xsl:text>float right</xsl:text>
          </xsl:when>
          <xsl:when test="$rend_vals ='block'">
            <xsl:text>float left</xsl:text>
          </xsl:when>
          <xsl:when test="$rend_vals =('blockCentered','blockCentred')">
            <xsl:text>blockCentered</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>float left</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:if>
    </xsl:variable>
    
    <xsl:variable name="image_type" select="if (matches(tei:graphic/@url,'\.svg')) then 'svg' else ()" as="xs:string*"/>
    <xsl:element name="{cudl:determine-output-element-name(., 'div')}">
      <xsl:if test="exists(($image_type,$width_val,$position,tokenize(@rend,'\s+')[not(.=('floatLeft','floatRight','blockCentered','blockCentred'))])[.!=''])">
        <xsl:attribute name="class" select="string-join(($image_type,$width_val,$position,tokenize(@rend,'\s+')[not(.=('floatLeft','floatRight','blockCentered','blockCentred'))],'image')[.!=''],' ')"/></xsl:if>
      <xsl:if test="@xml:id">
        <xsl:attribute name="id" select="@xml:id"/>
      </xsl:if>
      <xsl:next-match />
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="tei:figure[not(@type)][*]" priority="1" mode="#all">
    <img>
      <xsl:apply-templates select="tei:graphic" mode="populateImgAttrs"/>
      <xsl:choose>
        <xsl:when test="tei:figDesc[normalize-space(.)]">
          <xsl:attribute name="alt" select="tei:figDesc/normalize-space(.)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable name="image_number">
            <xsl:number format="1" level="any" count="tei:figure[tei:graphic]"/>
          </xsl:variable>
          <xsl:attribute name="alt" select="concat('Figure ',string($image_number))"/>
        </xsl:otherwise>
      </xsl:choose>
    </img>
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xsl:template match="tei:figure/tei:graphic" mode="populateImgAttrs">
    <xsl:apply-templates select="(@url, @width, @height)" mode="#current"/>
  </xsl:template>
  
  <xsl:template match="tei:figure/tei:graphic/@url" mode="populateImgAttrs">
    <xsl:attribute name="src" select="."/>
  </xsl:template>
  
  <xsl:template match="tei:figure/tei:graphic/@width[.!='']|tei:figure/tei:graphic/@height[.!='']" mode="populateImgAttrs">
    <xsl:attribute name="{local-name(.)}" select="replace(.,'px','')"/>
  </xsl:template>
  
  <xsl:template match="tei:figDesc" mode="#all"/>
  
  <xsl:template match="tei:text//tei:graphic[not(ancestor::tei:figure)]">
    <!-- Add support for these, I suppose -->
  </xsl:template>
  
  <xsl:template match="tei:del[@type = 'redactedBlockStrikethrough']" mode="#all">
        <span class="blockstrike-n" title="This block of text appears to have been censored by the author">
          <span class="color_fix">
            <xsl:apply-templates mode="#current"/>
          </span>
        </span>
  </xsl:template>
  
  <xsl:template match="tei:del[@type = 'redactedCancelled']" mode="#all">
        <span class="cancel-n" title="This text appears to have been censored by the author">
          <span class="color_fix">
            <xsl:apply-templates mode="#current"/>
          </span>
        </span>
  </xsl:template>

  <xsl:template match="tei:gap[not(@reason = ('illgblDel', 'blotDel', 'del', 'over'))]|
    tei:gap[@reason = ('illgblDel', 'blotDel', 'del', 'over')][ancestor::tei:del[contains(@type,'redacted')]]" mode="#all">
    <xsl:variable name="parsedUnit" select="cudl:parseUnit(@unit,@extent)" />
      
    <xsl:variable name="title">
      <xsl:choose>
        <xsl:when test="@reason = 'binding'">
          <xsl:text>Text is illegible because of the binding (Extent: </xsl:text>
          <xsl:value-of select="@extent"/>
          <xsl:text> </xsl:text>
          <xsl:value-of select="$parsedUnit"/>
          <xsl:text>)</xsl:text>
        </xsl:when>
        <xsl:when test="@reason = 'blot'">
          <xsl:text>Text </xsl:text>
          <xsl:value-of select="cudl:outputCertVerb(@cert)"/>
          <xsl:text> missing due to a blot</xsl:text>
        </xsl:when>
        <xsl:when test="@reason = 'smudge'">
          <xsl:text>Text is illegible because the manuscript text is smudged</xsl:text>
        </xsl:when>
        <xsl:when test="@reason = 'code'">
          <xsl:text>Text is illegible because it is encoded in an unknown cipher. (Extent: </xsl:text>
          <xsl:value-of select="@extent"/>
          <xsl:text> </xsl:text>
          <xsl:value-of select="$parsedUnit"/>
          <xsl:text>)</xsl:text>
        </xsl:when>
        <xsl:when test="@reason = 'copy'">
          <xsl:text>Text is illegible due to defective copy</xsl:text>
        </xsl:when>
        <xsl:when test="@reason = 'damage'">
          <xsl:text>Text is missing due to manuscript damage</xsl:text>
        </xsl:when>
        <xsl:when test="@reason = 'faded'">
          <xsl:text>Text is illegible because the manuscript is faded</xsl:text>
        </xsl:when>
        <xsl:when test="@reason = 'faint'">
          <xsl:text>Text is illegible because the manuscript text is faint</xsl:text>
        </xsl:when>
        <xsl:when test="@reason = 'foxed'">
          <xsl:text>Text is illegible because the manuscript is foxed</xsl:text>
        </xsl:when>
        <xsl:when test="@reason = 'hand'">
          <xsl:text>Illegible hand (Extent: </xsl:text>
          <xsl:value-of select="@extent"/>
          <xsl:text> </xsl:text>
          <xsl:value-of select="$parsedUnit"/>
          <xsl:text>)</xsl:text>
        </xsl:when>
        <xsl:when test="@reason = 'blotDel'">
          <xsl:text>Blot or deletion: </xsl:text>
          <xsl:value-of select="@extent"/>
          <xsl:text> </xsl:text>
          <xsl:value-of select="$parsedUnit"/>
        </xsl:when>
        <xsl:when test="@reason = ('del','illgblDel')">
          <xsl:text>Text is illegible because it is deleted</xsl:text>
        </xsl:when>
        <xsl:when test="@reason = 'over'">
          <xsl:text>Text is illegible or unclear because it is overwritten</xsl:text>
        </xsl:when>
        <!-- The following are CDL values -->
        <xsl:when test="@reason = 'omitted'">
          <xsl:text>Text is illegible because it is omitted</xsl:text>
        </xsl:when>
        <xsl:when test="@reason = ('illegible','illbgl')">
          <xsl:text>Text is illegible</xsl:text>
        </xsl:when>
        <xsl:when test="@reason = 'bleedthrough'">
          <xsl:text>Text is illegible because of bleedthrough</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>Text is illegible or missing.</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <span class="gap" title="{$title}">
      <xsl:choose>
        <xsl:when test="tei:desc">
          <xsl:apply-templates mode="#current" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>[illeg]</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </span>
  </xsl:template>
  
  

  <xsl:template match="tei:foreign" mode="#all">
      <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xsl:template match="tei:fw" mode="#all"/>
  
  <xsl:template match="tei:ab[not(@type) or not(normalize-space(@type))][cudl:is-in-block(.)]" mode="#default diplomatic normalised">
    <span>
      <xsl:if test="@facs != ''">
        <xsl:attribute name="xml:id" select="replace(normalize-space(@facs),'^#', '')"/>
      </xsl:if>
      <xsl:attribute name="class" select="normalize-space(string-join(('p',@rend),''))"/>
      <xsl:apply-templates select="@facs" mode="data-points"/>
      <xsl:apply-templates mode="#current"/>
    </span>
  </xsl:template>
  
  <xsl:template match="tei:seg[@type=('p')]" mode="#all">
    <!-- 'para' occurs within CUDL transcription metadata -->
    <span class="{@type}">
      <xsl:apply-templates mode="#current"/>
    </span>
  </xsl:template>
  
  <xsl:template match="tei:hi |
                       tei:seg[@rend][not(ancestor::tei:figure)]" 
                       mode="#default diplomatic normalised">
    <xsl:choose>
      <xsl:when test="cudl:elem-empty-in-normalised-view(current())"/>
      <xsl:otherwise>
        <xsl:variable name="rend_details" as="item()">
          <xsl:call-template name="render_inline">
            <xsl:with-param name="tokens" select="@rend"/>
          </xsl:call-template>
        </xsl:variable>

        <xsl:element name="{string($rend_details//text())}">
          <xsl:if test="$rend_details//normalize-space(@classes) != ''">
            <xsl:attribute name="class" select="normalize-space(string-join($rend_details//@classes,''))"/>
          </xsl:if>
          <xsl:apply-templates mode="#current"/>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="tei:lg" mode="#all">
    <xsl:choose>
      <xsl:when test="cudl:elem-empty-in-normalised-view(current())"/>
      <xsl:otherwise>
        <xsl:variable name="element_name" select="cudl:determine-output-element-name(., 'div')"/>
        
        <xsl:variable name="lgAnchor">
          <xsl:text>lg</xsl:text>
          <xsl:number format="1" level="any" count="tei:text//tei:lg"/>
        </xsl:variable>

        <xsl:element name="{$element_name}">
          <xsl:attribute name="id" select="$lgAnchor"/>
          <xsl:attribute name="class" select="string-join(('lg', cudl:rendPara(@rend)), ' ')"/>
          <xsl:apply-templates mode="#current"/>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="tei:l" mode="#all">
    <xsl:choose>
      <xsl:when test="cudl:elem-empty-in-normalised-view(current())"/>
      <xsl:otherwise>
        <xsl:variable name="element_name" select="cudl:determine-output-element-name(., 'p')"/>
        <xsl:element name="{$element_name}">
          <xsl:attribute name="class" select="string-join(('line', cudl:rendPara(@rend)), ' ')"/>
          <xsl:apply-templates mode="#current"/>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="tei:num" mode="#all">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>

  <xsl:template match="tei:lb[@type='hyphenated'][not(cudl:is_first_significant_child(.))]" priority="2" mode="#all">
    <xsl:text>-</xsl:text>
    <xsl:next-match/>
  </xsl:template>
  
  <xsl:template match="tei:lb[not(@type='hyphenated')][not(cudl:is_first_significant_child(.))]" priority="2" mode="#all">
    <xsl:next-match/>
  </xsl:template>
  
  <xsl:template match="tei:lb[not(cudl:is_first_significant_child(.))]|tei:lb[@facs]" priority="1" mode="#all">
    <br>
      <xsl:attribute name="xml:id" select="replace(normalize-space(@facs),'^#', '')"/>
      <xsl:apply-templates select="@facs" mode="data-points"/>
    </br>
  </xsl:template>
  
  <!-- Add data-points for polygons created by Transkribus -->
  <xsl:template match="@facs" mode="data-points">
    <xsl:attribute name="data-points" select="id(replace(.,'#',''))/@points"/>
  </xsl:template>
  
  <!-- According to TEI, lb specifies the beginning of the line. That means
       that many projects start of a block element (say a <p>) with an <lb/>
       We likely shouldn't display these initial linebreaks since it introduces
       a superfluous extra line break - one for the block element and another for
       the lb
       There is no reason to check whether lb is the last significant node in a block
       since a terminal br at the end of a block doesn't cause an extra line break
       on the screen
  -->
  <xsl:template match="tei:lb[not(@facs)][cudl:is_first_significant_child(.)]" mode="#all"/>
  
  <!-- list and item are just being output in generic containers. 
       switch to semantic html elements?
  -->
  <xsl:template match="tei:list" mode="#all">
    <xsl:variable name="element_name" select="cudl:determine-output-element-name(., 'div')"/>

    <xsl:variable name="listAnchor">
      <xsl:text>list</xsl:text>
      <xsl:number format="1" level="any" count="tei:text//tei:list"/>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="cudl:elem-empty-in-normalised-view(current())"/>
      <xsl:otherwise>
        <xsl:element name="{$element_name}">
          <xsl:call-template name="add-attr-if-exists">
            <xsl:with-param name="name" select="'id'"/>
            <xsl:with-param name="value" select="((normalize-space(@xml:id),$listAnchor)[.!=''])[1]"/>
          </xsl:call-template>
          <xsl:attribute name="class" select="string-join(('ul',cudl:rendPara(@rend)),' ')"/>
          <xsl:apply-templates mode="#current"/>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  

  <xsl:template match="tei:item" mode="#all">
    <!-- This needs fixing up so that it's using semantically
         appropriate elements when necessary (ie. li) and 
         span when not
    -->
    <xsl:choose>
      <xsl:when test="cudl:elem-empty-in-normalised-view(current())"/>
      <xsl:otherwise>
        <span class="{string-join(('li',cudl:rendPara(@rend)),' ')}">
          <xsl:apply-templates mode="#current"/>
        </span>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="tei:space[@dim='vertical']" mode="#all">
    <br class="verticalspace"/>
  </xsl:template>

  <xsl:template match="tei:space[@dim='horizontal']" mode="#all">
    <xsl:variable name="length" as="xs:integer">
      <xsl:variable name="length_cleaned" select="replace(normalize-space(@extent),'\?.*$', '')"/>
      <xsl:choose>
        <xsl:when test="$length_cleaned castable as xs:integer and xs:integer($length_cleaned) gt 0">
          <xsl:value-of select="xs:integer($length_cleaned)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="xs:integer(0)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:variable name="unit_text">
      <xsl:choose>
        <xsl:when test="@unit">
          <xsl:value-of select="@unit"/>
        </xsl:when>
        <xsl:otherwise>chars</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:variable name="message">
      <xsl:choose>
        <xsl:when test="$unit_text='chars' and $length ne 0">
          <xsl:text>Space for </xsl:text>
          <xsl:value-of select="@extent"/>
          <xsl:text> character</xsl:text>
          <xsl:if test="$length > 1">s</xsl:if>
          <xsl:text> left blank.</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>Space left blank.</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <span class="hspac-n" title="{$message}">
      <xsl:variable name="loop_max" select="if ($length ne 0) then $length else 3"/>
      <xsl:for-each select="1 to $length">
        <xsl:text>&#160;</xsl:text>
      </xsl:for-each>
    </span>
  </xsl:template>
  
  <xsl:template match="
      tei:pb[@sameAs | @xml:id][not(@xml:id = $requested_pb/@xml:id)][not(@prev = concat('#', $requested_pb/@xml:id))] |
      tei:cb[@sameAs | @xml:id] |
      tei:milestone[@sameAs | @xml:id]" priority="2" mode="diplomatic normalised">
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

    <xsl:variable name="element_name" select="cudl:determine-output-element-name(., 'span')"/>

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
      <xsl:choose>
        <xsl:when test="not(.//preceding::tei:*[1][name() = 'lb' and @rend = 'hyphenated'])">
          <xsl:text> </xsl:text>
        </xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:variable>

    <xsl:element name="{$element_name}">
      <xsl:attribute name="class" select="normalize-space($classname)"/>
      <xsl:if test="@xml:id | @sameAs">
        <xsl:attribute name="id">
          <xsl:choose>
            <xsl:when test="@xml:id">
              <xsl:value-of select="@xml:id"/>
            </xsl:when>
            <xsl:when test="@sameAs">
              <xsl:variable name="sameAs_attr" select="@sameAs"/>
              <xsl:variable name="count">
                <xsl:number format="1" level="any" count="key('milestones_id', $sameAs_attr) | key('milestones_sameAs', $sameAs_attr)"/>
              </xsl:variable>
              <xsl:value-of select="replace($sameAs_attr, '#', '')"/>
              <xsl:text>-</xsl:text>
              <xsl:value-of select="$count"/>
            </xsl:when>
          </xsl:choose>
        </xsl:attribute>
      </xsl:if>
      <xsl:value-of select="$optionalSpace"/>
      <xsl:text>&lt;</xsl:text>
      <xsl:next-match />
      <xsl:text>&gt;</xsl:text>
      <xsl:value-of select="$optionalSpace"/>
    </xsl:element>

  </xsl:template>
  
  <xsl:template match="
    tei:pb[@sameAs | @xml:id][not(@xml:id = $requested_pb/@xml:id)][not(@prev = concat('#', $requested_pb/@xml:id))] |
    tei:cb[@sameAs | @xml:id] |
    tei:milestone[@sameAs | @xml:id]" priority="1" mode="diplomatic normalised">
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
    
    <xsl:value-of select="$pageNum"/>

  </xsl:template>

  <xsl:template match="tei:unclear[not(parent::tei:choice[count(child::*[local-name()!='unclear'])=0])]" mode="diplomatic normalised">
    <xsl:choose>
      <xsl:when test="cudl:elem-empty-in-normalised-view(current())"/>
      <xsl:otherwise>
        <span>
          <xsl:attribute name="title">
            <xsl:choose>
              <xsl:when test="@cert = 'high'">
                  <xsl:text>This text is unclear in the manuscript, but the editor is highly confident of the reading.</xsl:text>
              </xsl:when>
              <xsl:when test="@cert = 'medium'">
                  <xsl:text>This text is unclear in the manuscript, but the editor is reasonably confident of the reading.</xsl:text>
              </xsl:when>
              <xsl:when test="@cert = 'low'">
                  <xsl:text>The editor is unsure of this reading because this text is unclear in the manuscript.</xsl:text>
              </xsl:when>
              <xsl:otherwise>
                  <xsl:text>The editor is unsure of this reading because this text is unclear in the manuscript.</xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
          <xsl:attribute name="class" select="string-join(('unclear',@cert),' ')"/>
          <span class="delim">
            <xsl:text>[</xsl:text>
          </span>
          <xsl:apply-templates mode="#current"/>
          <span class="delim">
            <xsl:text>]</xsl:text>
          </span>
        </span>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="tei:choice[count(child::*[local-name()!='unclear'])=0]/tei:unclear" mode="diplomatic normalised">
    <span class="{string-join(('unclear', @cert), ' ')}">
      <xsl:apply-templates mode="#current"/>
    </span>
  </xsl:template>

  <xsl:template match="tei:table[descendant::tei:cell[@cols|@rows]]" priority="2" mode="#default diplomatic normalised">
    <table>
      <xsl:call-template name="add-attr-if-exists">
        <xsl:with-param name="name" select="'class'"/>
        <xsl:with-param name="value" select="@rend"/>
      </xsl:call-template>
      <xsl:next-match/>
    </table>
  </xsl:template>
  
  <xsl:template match="tei:table[not(descendant::tei:cell[@cols|@rows])]" priority="2" mode="#default diplomatic normalised">
    
    <xsl:variable name="element_name" select="cudl:determine-output-element-name(., 'table')" />
    <xsl:variable name="stucturalClass" select="if ($element_name = 'span') then 'table' else ()"/>
    
    <xsl:element name="{$element_name}">
      <xsl:call-template name="add-attr-if-exists">
        <xsl:with-param name="name" select="'class'"/>
        <xsl:with-param name="value" select="($stucturalClass, @rend)"/>
      </xsl:call-template>
      <xsl:next-match/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="tei:table" priority="1" mode="#default diplomatic normalised">
    <xsl:call-template name="add-attr-if-exists">
      <xsl:with-param name="name" select="'id'"/>
      <xsl:with-param name="value" select="@xml:id"/>
    </xsl:call-template>
    
    <xsl:apply-templates mode="#current"/>
  </xsl:template>

  <xsl:template match="tei:table[descendant::tei:cell[@cols|@rows]]//tei:row" priority="2" mode="#default diplomatic normalised">
    <tr>
      <xsl:call-template name="add-attr-if-exists">
        <xsl:with-param name="name" select="'class'"/>
        <xsl:with-param name="value" select="@rend"/>
      </xsl:call-template>
      <xsl:next-match/>
    </tr>
  </xsl:template>
  
  <xsl:template match="tei:table[not(descendant::tei:cell[@cols|@rows])]//tei:row" priority="2" mode="#default diplomatic normalised">
    <xsl:variable name="element_name" select="cudl:determine-output-element-name(., 'tr')" />
    <xsl:variable name="stucturalClass" select="if ($element_name = 'span') then 'tr' else ()"/>
    
    <xsl:element name="{$element_name}">
      <xsl:call-template name="add-attr-if-exists">
        <xsl:with-param name="name" select="'class'"/>
        <xsl:with-param name="value" select="($stucturalClass, @rend)"/>
      </xsl:call-template>
      <xsl:next-match/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="tei:row" priority="1" mode="#default diplomatic normalised">
      <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xsl:template match="tei:table[descendant::tei:cell[@cols|@rows]]//tei:cell" priority="2" mode="#default diplomatic normalised">
    <td>
      <xsl:call-template name="add-attr-if-exists">
        <xsl:with-param name="name" select="'class'"/>
        <xsl:with-param name="value" select="cudl:rendPara(@rend)"/>
      </xsl:call-template>
      <xsl:next-match/>
    </td>
  </xsl:template>
  
  <xsl:template match="tei:table[not(descendant::tei:cell[@cols|@rows])]//tei:cell" priority="2" mode="#default diplomatic normalised">
    <xsl:variable name="element_name" select="cudl:determine-output-element-name(., 'td')" />
    <xsl:variable name="stucturalClass" select="if ($element_name = 'span') then 'td' else ()"/>
    
    <xsl:element name="{$element_name}">
      <xsl:call-template name="add-attr-if-exists">
        <xsl:with-param name="name" select="'class'"/>
        <xsl:with-param name="value" select="string-join(($stucturalClass, cudl:rendPara(@rend)),' ')"/>
      </xsl:call-template>
      <xsl:next-match/>
    </xsl:element>
  </xsl:template>
  

  <xsl:template match="tei:cell" priority="1" mode="#default diplomatic normalised">
    <xsl:apply-templates select="@cols|@rows"/>
      <xsl:choose>
        <xsl:when test="@role = 'label'">
          <xsl:element name="b">
            <xsl:apply-templates mode="#current"/>
          </xsl:element>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates mode="#current"/>
        </xsl:otherwise>
      </xsl:choose>
  </xsl:template>
  
  <xsl:template match="tei:cell/@cols" mode="#all">
    <xsl:attribute name="colspan" select="."/>
  </xsl:template>
  
  <xsl:template match="tei:cell/@rows" mode="#all">
    <xsl:attribute name="rowspan" select="."/>
  </xsl:template>

  <xsl:template match="tei:seg[not(ancestor::tei:figure|ancestor::tei:opener)][not(@type)][not(@rend)]" mode="#all">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xsl:template match="tei:quote|tei:q" mode="#all">
    <!-- CDL puts quotes around the string. Is this a problem of cb?-->
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xsl:template  match="text()[$project_name=('casebooks project')][parent::tei:*]" mode="#all">
    <xsl:variable name="string" select="."/>
    
    <xsl:variable name="cardo" as="xs:string">[&#x2e2b;&#x0292;&#x2108;&#x2125;&#x2114;&#xe670;&#xe270;&#xa770;&#xa76b;&#xe8bf;&#xa75b;&#xe8b3;&#xa757;&#x180;&#x1e9c;&#xa75d;&#xa75f;&#xa76d;&#xdf;&#xa76f;&#x204a;&#x0119;&#x271d;&#x211e;&#x2720;&#x2641;&#x25b3;&#x260c;&#x260d;&#x2297;&#x260a;&#x260b;]</xsl:variable>
    <xsl:variable name="newton" as="xs:string">[&#x261e;&#x2020;&#x2016;&#xe704;&#xe70d;&#x2652;&#x2648;&#x264c;&#xe002;&#x2653;&#x264f;&#x2649;&#x264d;&#x264a;&#x264b;&#x264e;&#x2650;&#x2651;&#xe714;&#x263e;&#x263e;&#x2640;&#x2640;&#x263f;&#x2609;&#x2609;&#xe739;&#x2642;&#x2642;&#x2643;&#x2643;&#x2644;&#x2644;&#xe704;&#x26b9;&#x25a1;&#xe74e;&#xe708;]</xsl:variable>
    <!-- NB: Is df needed? -->
    <xsl:variable name="df" as="xs:string">&#x101;|&#x111;|&#x113;|&#x12b;|m&#x304;|n&#x304;|&#x14d;|&#x16b;|w&#x304;|&#x233;</xsl:variable>
    
    <xsl:analyze-string select="$string" regex="({string-join(($cardo,$newton,$df),'|')})">
      
      <xsl:matching-substring>
        <xsl:choose>
          <xsl:when test="matches(.,$cardo)">
            <span class="cardo"><xsl:value-of select="."/></span>
          </xsl:when>
          <xsl:when test="matches(.,$newton)">
            <span class="ns"><xsl:value-of select="."/></span>
          </xsl:when>
          <xsl:when test="matches(.,$df)">
            <span class="df"><xsl:value-of select="."/></span>
          </xsl:when>
        </xsl:choose>
      </xsl:matching-substring>
      
      <xsl:non-matching-substring>
        <xsl:value-of select="."/>
      </xsl:non-matching-substring>
      
    </xsl:analyze-string>
  </xsl:template>

  
  <!-- For good-looking tree output, we need to include a return after any  text content, assuming we're not inside a paragraph tag. -->
  <xsl:template match="teix:*/text()" mode="#default diplomatic normalised">
    <xsl:if test="not(ancestor::teix:p)" />
    <xsl:value-of select="replace(., '&amp;', '&amp;amp;')"/>
    <xsl:if test="not(ancestor::teix:p) or  not(following-sibling::* or following-sibling::text())" />
  </xsl:template>
  
  <xsl:template name="endnote">
      <xsl:if test="exists(//tei:anchor[key('note-target', concat('#', @xml:id))] | //tei:text//tei:note[not(@target)][not($project_name = 'igntp')])">
      <div class="footnotes">
        <h4><strong>Notes:</strong></h4>
        <xsl:apply-templates select="//tei:anchor[key('note-target', concat('#', @xml:id))] |
                                    //tei:text//tei:note[not(@target)]" mode="endnote"/>
      </div>
    </xsl:if>
  </xsl:template>

  <xsl:function name="cudl:rendPara" as="xs:string*">
    <xsl:param name="rend_val" as="xs:string*"/>
    
    <xsl:variable name="rend" select="distinct-values(tokenize(normalize-space($rend_val),'\s+'))" as="xs:string*"/>
    <!-- Currently only take the first token -->
    <xsl:for-each select="$rend">
      <xsl:choose>
        <xsl:when test=".=''">
          <xsl:sequence select="'paraleft'" />          
        </xsl:when>
        <xsl:when test=". = 'indent0'">
          <xsl:sequence select="'noindent'" />
        </xsl:when>
        <xsl:when test="matches(.,'^indent\(*\d+\)*$')">
          <xsl:sequence select="."/>
        </xsl:when>
        <xsl:when test=". = 'left'">
          <xsl:sequence select="'paraleft'" />
        </xsl:when>
        <xsl:when test=". = 'right'">
          <xsl:sequence select="'pararight'" />
        </xsl:when>
        <xsl:when test=". = ('center', 'centre')">
          <xsl:sequence select="'paracenter'" />
        </xsl:when>
        <xsl:when test="lower-case(.) = ('blockquote')">
          <xsl:sequence select="'blockQuote'" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="." />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
    <!-- Should I default to including 'paraleft'? This might conflict with other values -->
    
    <xsl:if test="exists($rend[not(matches(normalize-space(.),'(left|right|center|centre|blockquote|indent\d+)'))])">
      <xsl:sequence select="'paraleft'" />
    </xsl:if>
  </xsl:function>
    
  <!-- Dipl/Normalised code below -->
    <xsl:template match="tei:abbr" mode="normalised"/>

    <xsl:template match="tei:abbr" mode="diplomatic">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>


    <xsl:template match="tei:expan" mode="normalised">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
    <xsl:template match="tei:expan" mode="diplomatic"/>

    
  <xsl:template match="tei:orig[parent::tei:choice]" mode="normalised"/>
    
  <xsl:template match="tei:orig[parent::tei:choice]" mode="diplomatic">
        <xsl:variable name="gloss">
            <xsl:call-template name="gloss">
                <xsl:with-param name="current_node" select="."/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="not($gloss ='')">
                <span class="gloss" title="{$gloss}">
                    <xsl:apply-templates mode="#current"/>
                </span>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates mode="#current"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    

  <xsl:template match="tei:reg[not(@type='gloss')][parent::tei:choice]" mode="normalised">
        <xsl:variable name="gloss">
            <xsl:call-template name="gloss">
                <xsl:with-param name="current_node" select="."/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="not($gloss ='')">
                <span class="gloss" title="{$gloss}">
                    <xsl:apply-templates mode="#current"/>
                </span>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates mode="#current"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
  <xsl:template match="tei:reg[@type='gloss'][parent::tei:choice][not(preceding-sibling::tei:reg)][not(following-sibling::tei:reg)]" mode="normalised">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
  <xsl:template match="tei:reg[@type='gloss'][parent::tei:choice][preceding-sibling::tei:reg or following-sibling::tei:reg]" mode="normalised"/>
  
  <xsl:template match="tei:subst" mode="#all">
    <span class="subst">
      <xsl:apply-templates mode="#current"/>
    </span>
  </xsl:template>
    
  <xsl:template match="tei:damage" mode="#all">
    <span class="delim">
      <xsl:text>[</xsl:text>
    </span>
    <span class="damage" title="This text damaged in source">
      <xsl:apply-templates mode="#current"/>
    </span>
    <span class="delim">
      <xsl:text>]</xsl:text>
    </span>
  </xsl:template>
  
  <xsl:template match="tei:reg[parent::tei:choice]" mode="diplomatic"/>

    <xsl:template match="tei:sic[parent::tei:choice]" mode="normalised"/>
    
    <xsl:template match="tei:sic[parent::tei:choice]" mode="diplomatic">
      
      <xsl:variable name="corr-type-attr" select="parent::tei:choice/tei:corr/lower-case(@type)" />
      
      <xsl:variable name="title-text" as="xs:string*">
        <xsl:choose>
          <xsl:when test="$corr-type-attr = ('notext', 'deltext')">
            <xsl:text>Editorial Note: This text is redundant.</xsl:text><!-- REmove period -->
          </xsl:when>
          <xsl:otherwise>
          <xsl:variable name="outputstring">
            <xsl:apply-templates select="parent::tei:choice[current()]/tei:corr" mode="tooltip"/>
          </xsl:variable>
          <xsl:variable name="tmp">
            <xsl:text>A correction of <![CDATA["]]></xsl:text>
            <xsl:value-of select="$outputstring"/>
            <xsl:text><![CDATA["]]> has been supplied for this text.</xsl:text></xsl:variable>
            <xsl:value-of select="normalize-space(string-join($tmp,''))"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      
      <span title="{normalize-space($title-text)}">
        <xsl:apply-templates mode="#current"/>
        <xsl:text>&#160;</xsl:text>
        <span class="delim">
          <xsl:text>[sic]</xsl:text>
        </span>
      </span>
    </xsl:template>
  
  <xsl:template match="tei:sic[not(parent::tei:choice)]" mode="#all">
    <span class="sic" title="This text is in error in source">
      <xsl:apply-templates mode="#current" />
    </span>
    <span class="delim">
      <xsl:text>(!)</xsl:text>
    </span>
  </xsl:template>

  <!-- These templates should only fire in non-casebooks materials -->
  <xsl:template match="tei:text//tei:corr[not(parent::tei:choice)]|
    tei:text//tei:orig[not(parent::tei:choice)]|
    tei:text//tei:reg[not(parent::tei:choice)]" mode="#all">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xsl:template match="tei:corr[parent::tei:choice]" mode="tooltip">
        <xsl:choose>
            <xsl:when test="tei:choice">
                <xsl:call-template name="apply-mode-to-templates">
                    <xsl:with-param name="displayMode" select="'diplomatic'"/>
                    <xsl:with-param name="node" select="*|text()"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="apply-mode-to-templates">
                    <xsl:with-param name="displayMode" select="'normalised'"/>
                    <xsl:with-param name="node" select="."/>
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

  <xsl:template match="tei:corr[parent::tei:choice]" mode="normalised">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
  <xsl:template match="tei:corr[parent::tei:choice]" mode="diplomatic"/>

    <!-- Additions and deletions -->
    
    <xsl:template match="tei:add" mode="normalised">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
    <xsl:template match="tei:add" mode="diplomatic">
        <xsl:variable name="place_token" select="tokenize(@place,'[-\s+]')[1]"/>
        <xsl:choose>
            <xsl:when test="$place_token = 'supralinear'">
                <span class="supra-n" title="This text added above the line">
                    <span class="delim">\</span>
                    <xsl:apply-templates mode="#current"/>
                    <span class="delim">/</span>
                </span>
            </xsl:when>
            <xsl:when test="$place_token = 'infralinear'">
                <span class="infra-n" title="This text added below the line">
                    <span class="delim">/</span>
                    <xsl:apply-templates mode="#current"/>
                    <span class="delim">\</span>
                </span>
            </xsl:when>
            <xsl:when test="$place_token = 'over'">
                <span class="over-n" title="This text is written over the foregoing">
                    <span class="delim">|</span>
                    <xsl:apply-templates mode="#current"/>
                    <span class="delim">|</span>
                </span>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="title_attr">
                    <xsl:choose>
                        <xsl:when test="$place_token='inline'">
                            <xsl:text>This text added inline</xsl:text>
                        </xsl:when>
                        <xsl:when test="$place_token='lineBeginning'">
                            <xsl:text>This text added at the beginning of the line</xsl:text>
                        </xsl:when>
                        <xsl:when test="$place_token='lineEnd'">
                            <xsl:text>This text added at the end of the line</xsl:text>
                        </xsl:when>
                        <xsl:when test="$place_token='marginLeft'">
                            <xsl:text>This text added in the left margin</xsl:text>
                        </xsl:when>
                        <xsl:when test="$place_token='marginRight'">
                            <xsl:text>This text added in the right margin</xsl:text>
                        </xsl:when>
                        <xsl:when test="$place_token='interlinear'">
                            <xsl:text>This text added between the lines</xsl:text>
                        </xsl:when>
                        <xsl:when test="$place_token='pageBottom'">
                            <xsl:text>This text added at the bottom of the page</xsl:text>
                        </xsl:when>
                        <xsl:when test="$place_token='pageTop'">
                            <xsl:text>This text added at the top of the page</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="concat('This text added from ', @place)"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <span class="inline-n" title="{$title_attr}">
                    <span class="delim">|</span>
                    <xsl:apply-templates mode="#current"/>
                    <span class="delim">|</span>
                </span>
            </xsl:otherwise>
        </xsl:choose>
</xsl:template>

    <xsl:template match="tei:del[not(@type=('redactedBlockStrikethrough','redactedCancelled'))]" mode="normalised"/>
    
    <xsl:template match="tei:del[not(@type=('redactedBlockStrikethrough', 'redactedCancelled'))]" mode="diplomatic">
        <xsl:choose>
            <xsl:when test="@type = 'cancelled'">
                <span class="cancel-n" title="Cancelled">
                    <xsl:apply-templates mode="#current"/>
                </span>
            </xsl:when>
            <xsl:when test="@type = 'erased'">
                <span class="erased-n" title="This text has been erased">
                    <xsl:apply-templates mode="#current"/>
                </span>
            </xsl:when>
            <xsl:when test="@type = ('strikethrough')">
                <span class="wordstrike-n" title="Deleted">
                    <span class="color_fix">
                        <xsl:apply-templates mode="#current"/>
                    </span>
                </span>
            </xsl:when>
            <xsl:when test="@type = 'over'">
                <span class="delover-n" title="This text has been overwritten">
                    <span class="color_fix">
                        <xsl:apply-templates mode="#current"/>
                    </span>
                </span>
            </xsl:when>
            <xsl:when test="@type = 'blockStrikethrough'">
                <span class="blockstrike-n" title="This block of text has been deleted">
                    <span class="color_fix">
                        <xsl:apply-templates mode="#current"/>
                    </span>
                </span>
            </xsl:when>
            <xsl:when test="@type = 'redactedBlockStrikethrough'">
                <span class="blockstrike-n" title="This block of text appears to have been censored by the author">
                    <span class="color_fix">
                        <xsl:apply-templates mode="#current"/>
                    </span>
                </span>
            </xsl:when>
            <xsl:when test="@type = 'redactedCancelled'">
                <span class="cancel-n" title="This text appears to have been censored by the author">
                    <span class="color_fix">
                        <xsl:apply-templates mode="#current"/>
                    </span>
                </span>
            </xsl:when>
          <!-- CDL value-->
          <xsl:when test="@type = 'illegible'">
            <span class="cancel-n" title="This text has been deleted and is illegible">
              <span class="color_fix">
                <xsl:apply-templates mode="#current"/>
              </span>
            </span>
          </xsl:when>
            <xsl:otherwise>
              <xsl:variable name="class" select="string-join((normalize-space(@rend),'wordstrike-n')[.!=''],' ')"/>
              <span class="{$class}" title="Deleted Text">
                <xsl:apply-templates mode="#current"/>
              </span>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>  
    
  <xsl:template match="tei:gap[@reason = ('illgblDel', 'blotDel', 'del', 'over')][not(ancestor::tei:del[contains(@type,'redacted')])]" mode="normalised"/>

  <xsl:template match="tei:gap[@reason = ('illgblDel', 'blotDel', 'del', 'over')][not(ancestor::tei:del[contains(@type, 'redacted')])]" mode="diplomatic">
    <xsl:variable name="parsedUnit" select="cudl:parseUnit(@unit, @extent)"/>

    <span class="gap">
      <xsl:choose>
        <xsl:when test="@reason = 'blotDel'">
          <xsl:attribute name="title" select="concat('Blot or deletion: ', @extent, ' ', $parsedUnit)"/>
        </xsl:when>
        <xsl:when test="@reason = ('del', 'illgblDel')">
          <xsl:attribute name="title" select="'Text is illegible because it is deleted'"/>
        </xsl:when>
        <xsl:when test="@reason = 'over'">
          <xsl:attribute name="title" select="'Text is illegible or unclear because it is overwritten'"/>
        </xsl:when>
      </xsl:choose>
      <span class="gap">[illeg]</span>
    </span>
  </xsl:template>
  
  <xsl:template name="render_inline" as="item()*">
    <xsl:param name="tokens"/>

    <xsl:variable name="tokenized_items" select="for $x in functx:sort(distinct-values(tokenize(normalize-space(replace(string-join($tokens, ' '),',',' ')), '\s+'))) return cudl:canonicalise-css-class-names($x)"/>

    <!-- The token map is used to map rend values to named html elements
         any tokens that fail to match this list will be returned as the
         className.
         The final element name for the segment will be the name of the
         first custom element name in the sorted token list or, failing
         that, span.
    -->

    <xsl:variable name="token_map">
      <list>
        <item n="bold" suppressClass="yes">strong</item>
        <item n="doubleUnderline">em</item>
        <item n="underlineDashed">em</item>
        <item n="ital itals italic italics" cssClassName="italic">em</item><!-- remove @suppressClass -->
        <item n="subscript infralinear sub" suppressClass="yes">sub</item>
        <item n="super superscript supralinear" suppressClass="yes">sup</item>
        <item n="underline underlined" cssClassName="underline">em</item>
        <item n="smallCaps smallcaps" cssClassName="smallCaps">span</item>
      </list>
    </xsl:variable>
    
    <xsl:variable name="unique_classes" select="normalize-space(string-join($tokenized_items[not(.=$token_map//*:item[@suppressClass='yes']/tokenize(@n,'\s+'))],''))"/>
    

    <xsl:variable name="results" as="item()">
      <item classes="{distinct-values(for $x in $unique_classes return ($token_map//*:item[$x = tokenize(@n,'\s+')]/@cssClassName, $x)[normalize-space(.) != ''][1])}">
        <xsl:value-of select="($token_map//*:item[tokenize(@n, '\s+') = $tokenized_items[1]], 'span')[. != ''][1]"/>
      </item>
    </xsl:variable>

    <xsl:copy-of select="$results"/>
  </xsl:template>
  
  <xsl:function name="cudl:canonicalise-css-class-names" as="xs:string">
    <xsl:param name="class"/>
    
    <xsl:value-of select="replace($class,'[^-_A-Za-z0-9]','')"/>
  </xsl:function>
  
</xsl:stylesheet>