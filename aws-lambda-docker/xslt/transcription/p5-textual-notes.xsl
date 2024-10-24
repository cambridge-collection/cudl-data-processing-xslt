<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="http://www.w3.org/1999/xhtml" xmlns:np="http://www.newtonproject.sussex.ac.uk/ns/nonTEI" xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:mml="http://www.w3.org/1998/Math/MathML" xmlns:teix="http://www.tei-c.org/ns/Examples" xpath-default-namespace="" version="2.0" exclude-result-prefixes="#all">
    
    <xsl:template match="tei:note[@target]" mode="diplomatic normalised"/>
    
    <xsl:template match="tei:anchor[key('note-target',concat('#',@xml:id))] |
                         tei:text//tei:note[not(@target)]" mode="normalised diplomatic">
        
        <xsl:variable name="noteNumber">
            <xsl:call-template name="number-footnote"/>
        </xsl:variable>
        
        <xsl:variable name="noteId" select="np:create-note-id($noteNumber, @type)"/>
        <xsl:variable name="noteIndicator" select="np:create-note-label($noteNumber, @type)" />
        <xsl:variable name="noteRef" select="concat(np:create-note-id($noteNumber, @type),'-ref')" />

        <xsl:call-template name="write_note_indicator">
            <xsl:with-param name="id" select="$noteRef"/>
            <xsl:with-param name="indicator" select="$noteIndicator"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template match="tei:anchor[key('note-target',concat('#',@xml:id))]" mode="endnote">
        <xsl:variable name="anchorId">
            <xsl:value-of select="@xml:id"/>
        </xsl:variable>
        
        <xsl:if test="exists(key('note-target',concat('#',@xml:id)))">
            <xsl:variable name="noteNumber">
                <xsl:call-template name="number-footnote"/>
            </xsl:variable>
            <xsl:variable name="noteId" select="np:create-note-id($noteNumber, @type)"/>

            <xsl:apply-templates select="key('note-target', concat('#', @xml:id))" mode="anchored">
                <!-- Must pass the noteNumber in order to ensure that single notes
                     referred to by more than one anchor are numbered properly
                    -->
                <xsl:with-param name="noteNumber" select="$noteNumber"/>
            </xsl:apply-templates>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="tei:text//tei:note[not(@target)]" priority="2" mode="endnote">
        <xsl:variable name="noteNumber">
            <xsl:call-template name="number-footnote"/>
        </xsl:variable>
        
        <xsl:next-match>
            <xsl:with-param name="noteNumber" select="$noteNumber" />
        </xsl:next-match>
    </xsl:template>
    
    <xsl:template match="tei:text//tei:note[@target]" priority="2" mode="anchored">
        <xsl:param name="noteNumber"/>
        
        <xsl:next-match>
            <xsl:with-param name="noteNumber" select="$noteNumber" />
        </xsl:next-match>
        
    </xsl:template>
    
    <xsl:template match="tei:text//tei:note" priority="1" mode="anchored endnote">
        <xsl:param name="noteNumber" />

        <xsl:variable name="noteId" select="np:create-note-id($noteNumber, @type)"/>
        <xsl:variable name="noteIndicator" select="np:create-note-label($noteNumber, @type)" />

        <div id="{$noteId}" class="footnote">
            <xsl:call-template name="writeNote">
                <xsl:with-param name="noteNumber" select="$noteIndicator" />
            </xsl:call-template>
        </div>
    </xsl:template>
    
    <xsl:template name="writeNote">
        <xsl:param name="noteNumber" />
        
        <p class="notenumber">
            <xsl:value-of select="$noteNumber"/>
        </p>
        <xsl:if test="not(descendant::tei:p)">
            
            <p class="note-content"><xsl:choose>
                <xsl:when test="text()[normalize-space(.)] | *">
                    <xsl:choose>
                        <xsl:when test="$viewMode='normalized'">
                            <xsl:choose>
                                <xsl:when test=". = .//tei:del">
                                    <em>
                                        <xsl:text>The contents of this note are only visible in the diplomatic transcript because they were deleted on the original manuscript</xsl:text>
                                    </em>
                                </xsl:when>
                                <xsl:when test="(normalize-space(.)='' or . = .//tei:del)">
                                    <strong>Note:</strong>
                                    <xsl:text> </xsl:text>
                                    <em>
                                        <xsl:text>The contents of this note were not translated because the passage was deleted in the original manuscript</xsl:text>
                                    </em>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:call-template name="apply-mode-to-templates">
                                        <xsl:with-param name="displayMode" select="$viewMode"/>
                                        <xsl:with-param name="node" select="*|text()"/>
                                    </xsl:call-template>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <span class="note_content"><xsl:call-template name="apply-mode-to-templates">
                                <xsl:with-param name="displayMode" select="$viewMode"/>
                                <xsl:with-param name="node" select="*|text()"/>
                            </xsl:call-template></span>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise>
                    <strong>Editorial Note:</strong>
                    <xsl:text> This Note Empty</xsl:text>
                </xsl:otherwise>
            </xsl:choose></p>
        </xsl:if>
        
        <xsl:if test="(descendant::tei:p)">
            <xsl:call-template name="apply-mode-to-templates">
                <xsl:with-param name="displayMode" select="$viewMode"/>
                <xsl:with-param name="node" select="*|text()"/>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>
    
    <xsl:template name="number-footnote">
        <xsl:choose>
            <xsl:when test="not($project_name='mingana lewis') and @type='editorial'">
                <xsl:number format="1" count="//tei:text//tei:note[@type='editorial']" level="any"/>
            </xsl:when>
            <xsl:when test="@type='imageLink'">
                <xsl:number format="1" count="//tei:text//tei:note[@type='imageLink']" level="any"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:choose>
                    <xsl:when test="$project_name='mingana lewis'">
                        <xsl:number format="1" count="//tei:anchor[key('note-target',concat('#',@xml:id))]|//tei:text//tei:note[not(@target) and not(@type=('imageLink'))]" level="any"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:number format="1" count="//tei:anchor[key('note-target',concat('#',@xml:id))]|//tei:text//tei:note[not(@target) and not(@type=('editorial','imageLink'))]" level="any"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:function name="np:create-note-id" as="xs:string">
        <xsl:param name="note-number"/>
        <xsl:param name="note-type"/>
        
        <xsl:variable name="prefix">
            <xsl:choose>
                <xsl:when test="not($project_name='mingana lewis') and $note-type = 'editorial'">
                    <xsl:text>ed</xsl:text>
                </xsl:when>
                <xsl:when test="$note-type = 'imageLink'">
                    <xsl:text>img</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>n</xsl:text>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:value-of select="concat($prefix, $note-number)"/>
    </xsl:function>
    
    <xsl:function name="np:create-note-label" as="xs:string">
        <xsl:param name="note-number"/>
        <xsl:param name="note-type"/>
        
        <xsl:variable name="prefix">
            <xsl:choose>
                <xsl:when test="not($project_name='mingana lewis') and $note-type = 'editorial'">
                    <xsl:text>Editorial&#160;Note&#160;</xsl:text>
                </xsl:when>
                <xsl:when test="$note-type = 'imageLink'">
                    <xsl:text>Image </xsl:text>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        <xsl:value-of select="concat($prefix, $note-number)"/>
    </xsl:function>
    
    <xsl:template name="write_note_indicator">
        <xsl:param name="id"/>
        <xsl:param name="indicator"/>
        
        <a id="{$id}" class="superscript footnote_indicator" href="{concat('#',replace($id,'-ref$',''))}">
            <xsl:value-of select="$indicator"/>
        </a>
        
        <!--<sup class="note">
            <xsl:attribute name="id">
                <xsl:value-of select="$id"/>
            </xsl:attribute>
            <!-\-<xsl:text>[</xsl:text>-\->
            <xsl:value-of select="$indicator"/>
            <!-\-<xsl:text>]</xsl:text>-\->
        </sup>-->
    </xsl:template>
</xsl:stylesheet>