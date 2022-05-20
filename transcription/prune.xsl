<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:functx="http://www.functx.com" xmlns:saxon="http://saxon.sf.net/" xmlns:xs="http://www.w3.org/2001/XMLSchema"    xmlns:util="http://cudl.lib.cam.ac.uk/xtf/ns/util"
    exclude-result-prefixes="#all">

    <xsl:key name="elements-by-id" match="*[@xml:id]" use="@xml:id"/>

    <!-- Enable special handling for Casebooks documents -->
    <xsl:template match="/tei:TEI[tei:teiHeader/tei:fileDesc/tei:publicationStmt/tei:publisher[.='The Casebooks Project']]" mode="prune">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()" mode="prune-casebooks" />
        </xsl:copy>
    </xsl:template>

    <!-- Enable special handling for Darwin documents -->
    <xsl:template match="/tei:TEI[tei:teiHeader/tei:fileDesc/tei:publicationStmt/tei:authority[.='Darwin Correspondence Project']]" mode="prune">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()" mode="prune-darwin" />
        </xsl:copy>
    </xsl:template>

    <xsl:template match="/tei:TEI" mode="prune" priority="0">
        <xsl:next-match/>
    </xsl:template>

    <!-- Retain the whole teiHeader unchanged by default -->
    <xsl:template match="tei:teiHeader" mode="prune">
        <xsl:copy-of select="."/>
    </xsl:template>

    <!-- Casebooks: Drop msItem for cases which are not in the selected page(s) -->
    <xsl:template mode="prune-casebooks"
                  match="tei:msItem/tei:msItem[not(key('elements-by-id', tokenize(normalize-space(tei:title),':')[1]))]"/>

    <!-- Darwin: Drop msPart for letters which are not in the selected page(s) -->
    <xsl:template mode="prune-darwin"
                  match="tei:msPart[descendant::tei:altIdentifier[@type='letter_id']/
                                    tei:idno[not(key('elements-by-id', normalize-space(.)))]]"/>

    <!-- Strip insignificant whitespace in elements -->
    <xsl:template match="tei:msItem/text()[not(normalize-space(.))] |
                         tei:facsimile/text()[not(normalize-space(.))] |
                         tei:msDesc/text()[not(normalize-space(.))]"
                  mode="prune prune-darwin prune-casebooks"/>

    <!-- Drop surface elements which don't refer to selected pages -->
    <xsl:template match="tei:surface[@xml:id and not(key('pb-with-valid-context-by-facs', concat('#', @xml:id)))]"
                  mode="prune prune-darwin prune-casebooks"/>

    <!-- Retain everything by default -->
    <xsl:template match="node() | @*" mode="prune prune-darwin prune-casebooks">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()" mode="#current" />
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>
