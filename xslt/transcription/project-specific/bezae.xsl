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
    
    <xsl:template match="tei:cb[not(@n='2')][$project_name = 'igntp']" priority="3" mode="#all"/>
    
    <xsl:template match="tei:pb[$project_name = 'igntp']" mode="#all" priority="1">
        <div class="pageheader">
            <p>
                <xsl:text>Folio </xsl:text>
                <xsl:value-of select="@n"/>
                
                <xsl:if test="normalize-space(@type)">
                    <xsl:text> </xsl:text>
                    <xsl:value-of select="@type"/>
                </xsl:if>
                <xsl:if test="normalize-space(@subtype)">
                    <xsl:text> (</xsl:text>
                    <xsl:value-of select="@subtype"/>
                    <xsl:text>)</xsl:text>
                </xsl:if>
                
                <xsl:text> </xsl:text>
                
                <xsl:if test="normalize-space(@ed)">
                    <em>
                        <xsl:value-of select="@ed"/>
                    </em>
                </xsl:if>
            </p>
            <p class="number_header">
                <span class="line_number" title="Line number label">Line Numbers </span>
                <span class="verse_number" title="Modern verse number label"> Verse Numbers</span>
            </p>
        </div>
    </xsl:template>
  
    <xsl:template match="tei:lb[$project_name = 'igntp']" mode="#all" priority="1">
        <br/>
        <span class="line_number" title="Line number">
            <xsl:if test="(@n mod 3) = 0">
                <xsl:value-of select="@n"/>
            </xsl:if>
            <xsl:text> </xsl:text>
        </span>
        
        <xsl:choose>
            <xsl:when test="@rend">
                <span>
                    <xsl:attribute name="class" select="@rend"/>
                    <xsl:text> </xsl:text>
                </span>
            </xsl:when>
            <xsl:otherwise>
                <span class="line">
                    <xsl:text> </xsl:text>
                </span>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- Divisions-->
    
    <xsl:template match="tei:milestone[@type='bookStart'][$project_name = 'igntp']" priority="3" mode="#all">
        <span id="{@n}"/>
    </xsl:template>
    
    <xsl:template match="tei:milestone[@type='chapterStart'][$project_name = 'igntp']" priority="3" mode="#all">
        <span class="chapter_number" id="{@n}" title="Modern chapter number">
            <xsl:value-of select="substring-after(@n,'K')"/>
            <xsl:text>:</xsl:text>
        </span>
    </xsl:template>
    
    <xsl:template match="tei:milestone[@type='modernVerseStart'][$project_name = 'igntp']" priority="3" mode="#all">
        <xsl:variable name="current" select="."/>
        
        <span class="{string-join(('verse_number',cudl:add_offset_classname(.))[normalize-space()],' ')}" title="Modern verse number">
            <xsl:value-of select="substring-after(@n,'V')"/>
            <!--this keeps the element properly closed if it's empty-->
            <xsl:comment>verse number</xsl:comment>
        </span>
    </xsl:template>
    
    <xsl:template match="tei:ab[@type='supplement'][not(@prev)][$project_name = 'igntp'][not(@n)]" mode="#all" priority="2">
        <span class="supplement">
            <xsl:next-match/>
        </span>
    </xsl:template>
    
    <xsl:template match="tei:ab[not(@prev)][$project_name = 'igntp'][not(@n)]" mode="#all" priority="1">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
    <xsl:template match="tei:w[$project_name = 'igntp'] |
                         tei:pc[$project_name = 'igntp']" priority="1" mode="#all">
        <!-- Investigate whether adding a space after w in the general template affects output -->
        <xsl:apply-templates mode="#current"/>
        <xsl:text> </xsl:text>
    </xsl:template>
    
    <xsl:template match="tei:ex[$project_name = 'igntp']" mode="#all" priority="1">
        <span class="abbreviation" title="Expansion of abbreviated text">
            <xsl:text>(</xsl:text>
            <xsl:apply-templates mode="#current"/>
            <xsl:text>)</xsl:text>
        </span>
    </xsl:template>
    
    <!-- Incipit and explicit will be repeated on each page when the original div is longer than a single page -->
    <xsl:template match="tei:milestone[@type = ('incipit', 'explicit')][$project_name = 'igntp']" priority="3" mode="#all">
        <span class="verse_number">
            <strong>
                <xsl:value-of select="functx:capitalize-first(@type)"/>
            </strong>
        </span>
    </xsl:template>
    
    <xsl:template match="tei:seg[$project_name = 'igntp']" mode="#all" priority="1">
        <!-- Convert @subtype to @rend in preprocess, make latinCol into @rend too
             This should allow seg to be processed by the default template -->
        <xsl:variable name="classnames" as="xs:string*">
            <xsl:choose>
                <xsl:when test="@type = 'latinCol'">
                    <xsl:sequence select="'col2'"/>
                </xsl:when>
            </xsl:choose>
            <xsl:choose>
                <xsl:when test="@subtype='lineleft'">
                    <xsl:sequence select="'marginlineleft'"/>
                </xsl:when>
                <xsl:when test="@subtype='lineright'">
                    <xsl:sequence select="'marginlineright'"/>
                </xsl:when>
                <xsl:when test="@subtype='pagetop'">
                    <xsl:sequence select="'marginpage top'"/>
                </xsl:when>
                <xsl:when test="@subtype='pagebottom'">
                    <xsl:sequence select="'marginpage bottom'"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        
        <span class="{string-join($classnames,' ')}">
            <xsl:apply-templates mode="#current"/>
        </span>
    </xsl:template>
    
    <xsl:template match="tei:note[@type = ('editorial', 'hermeneia', 'library')][$project_name = 'igntp']" priority="99" mode="#all">
        <span>
            <xsl:variable name="classname">
                <xsl:choose>
                    <xsl:when test="@type = 'hermeneia' and @place='center'">
                        <xsl:text>centerJustmargin</xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:choose>
                            <xsl:when test="@place='right'">
                                <xsl:text>rightJust</xsl:text>
                            </xsl:when>
                            <xsl:when test="@place='center'">
                                <xsl:text>centerJust</xsl:text>
                            </xsl:when>
                            <xsl:when test="@place='left'">
                                <xsl:text>line</xsl:text>
                            </xsl:when>
                        </xsl:choose>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:if test="normalize-space($classname)">
                <xsl:attribute name="class" select="$classname"/>
            </xsl:if>
            <xsl:next-match/>
        </span>
    </xsl:template>
  
  
    <xsl:template match="tei:note[@type='editorial'][$project_name = 'igntp']" priority="98" mode="#all">
        <span class="editorialnote">
            <xsl:attribute name="title">
                <xsl:apply-templates mode="title"/>
            </xsl:attribute>
            <xsl:text>Note </xsl:text>
        </span>
    </xsl:template>
    
    <xsl:template match="tei:note[@type='hermeneia'][$project_name = 'igntp']" priority="98" mode="#all">
        <span class="hermeneia">
            <xsl:apply-templates mode="#current"/>
        </span>
        <br/>
    </xsl:template>
    
    <xsl:template match="tei:note[@type='library'][$project_name = 'igntp']" priority="98" mode="#all">
        <span class="editorialnote">
            <xsl:attribute name="title">
                <xsl:text>Library Note (</xsl:text>
                <xsl:value-of select="@rend"/>
                <xsl:text>): </xsl:text>
                <xsl:apply-templates mode="title-nospace"/>
            </xsl:attribute>
            <xsl:text>Library Note </xsl:text>
        </span>
    </xsl:template>
    
    <xsl:template match="tei:note[@type='titlos'][$project_name = 'igntp']" priority="98" mode="#all">
        <span class="titlos">
            <xsl:attribute name="title">
                <xsl:text>Titlos: </xsl:text>
                <xsl:apply-templates mode="#current"/>
            </xsl:attribute>
            <xsl:apply-templates mode="#current"/>
        </span>
        <br/>
    </xsl:template>
    
    <xsl:template match="tei:note[@type='jotting'][$project_name = 'igntp']" priority="98" mode="#all">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
    <xsl:template match="tei:num[$project_name = 'igntp']" mode="#all" priority="1">
        <!-- num can be chapNum AmmSec -->
        <span class="{@rend[.=('pencil','ink')]}">
            <span>
                <xsl:attribute name="title">
                    <xsl:choose>
                        <xsl:when test="@type='chapNum'">
                            <xsl:text>Chapter Number (</xsl:text>
                            <xsl:value-of select="@rend"/>
                            <xsl:text>): </xsl:text>
                            <xsl:apply-templates mode="title-nospace"/>
                        </xsl:when>
                        <xsl:when test="@type='AmmSec'">
                            <xsl:text>Ammonian Section </xsl:text>
                            <xsl:value-of select="@n"/>
                        </xsl:when>
                    </xsl:choose>
                </xsl:attribute>
                <xsl:apply-templates mode="#current"/>
            </span>
        </span>
    </xsl:template>
    
    <!-- Gap, space, unclear-->
    <xsl:template match="tei:gap[$project_name = 'igntp']" mode="#all" priority="1">
        <!-- If they can accept [illeg] in the output, the only differences would be:
            tei:rdg//tei:gap has a space after it. Address in tei:app?
            @reason = lacuna has a different title. Add lacuna into main template
            @reason = illegible -->
        <xsl:choose>
            <xsl:when test="ancestor::tei:rdg">
                <xsl:text>[...] </xsl:text>
            </xsl:when>
            <xsl:when test="@reason='lacuna'">
                <span class="supplied" title="Lacuna of {@extent} {@unit}">[...]</span>
            </xsl:when>
            <xsl:when test="@reason='illegible'">
                <span class="supplied" title="{@extent} {@unit} illegible">[...]</span>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text>[...] </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="tei:unclear[$project_name = 'igntp']" mode="#all" priority="1">
        <span class="unclear" title="Unclear text">
            <xsl:apply-templates mode="#current"/>
        </span>
    </xsl:template>
    
    <!-- Corrections-->
    <xsl:template match="tei:app[$project_name = 'igntp']" mode="#all" priority="1">
        <span class="original">
            <xsl:attribute name="title">
                <xsl:for-each select="tei:rdg">
                    <xsl:choose>
                        <xsl:when test="@type='orig'">
                            <xsl:text>Original </xsl:text>
                            <xsl:choose>
                                <xsl:when test="@hand='firsthand'">
                                    <xsl:text>(first hand)</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>(</xsl:text>
                                    <xsl:value-of select="@hand"/>
                                    <xsl:text>)</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                            <xsl:choose>
                                <xsl:when test="tei:w/text()='⸆'">
                                    <xsl:text> omits</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>: </xsl:text>
                                    <xsl:apply-templates mode="title"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:when test="@type='corr'">
                            <xsl:text>;&#13;Corrector </xsl:text>
                            <xsl:choose>
                                <xsl:when test="@hand='firsthand'">
                                    <xsl:text>(first hand)</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>(</xsl:text>
                                    <xsl:value-of select="@hand"/>
                                    <xsl:text>)</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                            <xsl:choose>
                                <xsl:when test="tei:w/text()='⸆'"> deletes</xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>: </xsl:text>
                                    <xsl:apply-templates mode="title"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                    </xsl:choose>
                </xsl:for-each>
            </xsl:attribute>
            <xsl:apply-templates mode="#current"/>
        </span>
    </xsl:template>
    
    <xsl:template match="tei:rdg[$project_name = 'igntp']" mode="#all" priority="1">
        <xsl:choose>
            <xsl:when test="@type='orig'">
                <span class="original">
                    <xsl:apply-templates mode="#current"/>
                </span>
            </xsl:when>
            <xsl:otherwise/>
        </xsl:choose>
    </xsl:template>
    
    
    <!-- Decorations and fw-->
    
    <xsl:template match="tei:hi[@rend='rubric'][$project_name = 'igntp']" mode="#all" priority="1">
        <span class="rubric" title="Rubricated text">
            <xsl:apply-templates mode="#current"/>
        </span>
    </xsl:template>
    
    <xsl:template match="tei:fw[$project_name = 'igntp']" mode="#all" priority="1">
        <!-- fw can be pageNum quireSig runTitle chapTitle chapRef lectTitle -->
        <span>
            <xsl:attribute name="class">
                <xsl:choose>
                    <xsl:when test="@place='right'">rightJust</xsl:when>
                    <xsl:when test="@type='runTitle'">runTitle</xsl:when>
                    <xsl:when test="@place='center'">centerJustmargin</xsl:when>
                    <xsl:when test="@place='left'">line</xsl:when>
                </xsl:choose>
            </xsl:attribute>
            <span>
                <xsl:attribute name="class">
                    <xsl:choose>
                        <xsl:when test="@rend='pencil'">pencil</xsl:when>
                        <xsl:when test="@rend='ink'">ink</xsl:when>
                    </xsl:choose>
                </xsl:attribute>
                <span>
                    <xsl:attribute name="title">
                        <xsl:choose>
                            <xsl:when test="@type='pageNum'">Folio Number (<xsl:value-of
                                select="@rend"/>): <xsl:apply-templates mode="title-nospace"
                                /></xsl:when>
                            <xsl:when test="@type='quireSig'">Quire Signature (<xsl:value-of
                                select="@rend"/>): <xsl:apply-templates mode="title-nospace"
                                /></xsl:when>
                            <xsl:when test="@type='runTitle'">Running Title</xsl:when>
                            <xsl:when test="@type='chapRef'">Chapter Reference: <xsl:apply-templates
                                mode="title-nospace"/></xsl:when>
                            <xsl:when test="@type='titlos'">Titlos (hand <xsl:value-of
                                select="@rend"/>): <xsl:apply-templates mode="title-nospace"
                                /></xsl:when>
                            <xsl:when test="@type='lectTitle'">Lectionary indication (hand
                                <xsl:value-of select="@rend"/>): <xsl:apply-templates
                                    mode="title-nospace"/></xsl:when>
                        </xsl:choose>
                    </xsl:attribute>
                    <xsl:choose>
                        <xsl:when test="@type='lectTitle'">
                            <span class="lect">Lect.</span>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:apply-templates mode="#current"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </span>
            </span>
        </span>
        <xsl:text> </xsl:text>
    </xsl:template>
    
    <!-- Supplied-->
    <!-- Provided by core template - @title value differs -->
    <!--<xsl:template match="tei:supplied[$project_name = 'igntp']" mode="#all" priority="1">
        <span class="supplied" title="Supplied text (no longer extant or legible)">
            <xsl:text>[</xsl:text>
            <xsl:apply-templates mode="#current"/>
            <xsl:text>]</xsl:text>
        </span>
    </xsl:template>-->
    
    <!--Abbreviations-->
    <xsl:template match="tei:abbr[$project_name = 'igntp'][@type =('nomSac','num')]" mode="#all" priority="1">
        <span>
            <xsl:attribute name="title">
                <xsl:choose>
                    <xsl:when test="@type='nomSac'">Nomen sacrum (abbreviation)</xsl:when>
                    <xsl:when test="@type='num'">Numeral (abbreviation)</xsl:when>
                </xsl:choose>
            </xsl:attribute>
            <xsl:apply-templates mode="#current"/>
        </span>
    </xsl:template>
    
    <xsl:function name="cudl:add_offset_classname" as="xs:string*">
        <xsl:param name="current"/>
        
        <xsl:variable name="next_lb" select="$current/following::tei:lb[1]"/>
        
        <xsl:if test="$current/following::tei:milestone[. &lt;&lt; $next_lb]">
            <xsl:sequence select="'addOffset'"/>
        </xsl:if>
    </xsl:function>
    
</xsl:stylesheet>