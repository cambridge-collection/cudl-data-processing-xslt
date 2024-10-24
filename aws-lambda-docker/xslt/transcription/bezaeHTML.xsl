<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE TEI [
<!ENTITY om "⸆"><!-- omission (blank first hand reading)-->
]>

<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:tei="http://www.tei-c.org/ns/1.0">

   <xsl:output method="xml"></xsl:output>

   <!--cut-down version of bezae.xsl-->


   <xsl:template match="/">
      <html>
         <head>
            <meta http-equiv="Content-Type" content="text/html; charset=utf-8"></meta>
            <title>Codex Bezae Transcription</title>
            <script type="text/javascript">
                    function gotoTranscriptionPap(mySel) {
                        var form = document.forms.transnavPap;
                        var wit = form.ms[form.ms.selectedIndex].value
                        window.parent.location.href = "" + wit;
                        return false;
                    }</script>
            <!--<link rel="stylesheet" href="/xtf/style/transcriptions/bezae.css" type="text/css"></link> -->
            <!-- css margin order: top right bottom left -->
            <style>
            .transcription-credit { float: right; color:#999999; }
            body { background-color:#ffffff; font-family: Gentium, Times, Gentium Plus, Arial Unicode MS; }
            div#text { font-family: Gentium, Times, Gentium Plus, GFS Decker; background-color:#ffffff; font-size:1em; width:600px; }
            div#hyperlinks-top { width:620px;}
            h1 { font-family:Gentium, Times New Roman; color:darkRed; font-size:3em; float:left; display: inline; }
            h2 { font-family:Gentium, Times New Roman; font-size:1.5em; }
            h3 { font-family:Gentium, Times New Roman; font-size:1.3em; }
            span#logo { font-family:Gentium, Times New Roman; color:darkRed; font-size:3em; display: inline; float:left; }
            span#top { font-family:Gentium, Times New Roman; color:black; font-size:1.5em; display: inline; float:bottom; }
            p.menu { clear: both; }
            span.verse_number { color:grey;font-size:0.8em;float:right;margin: 0.2em 10px 0 5px;font-weight:bold;font-style:normal;}
            span.chapter_number {font-family:Gentium, Times New Roman;color:grey;font-size:0.8em;float:right;margin: 0.2em 30px 0 -120px;font-weight:bold;font-style:normal;}
            span.line_number {/*font-family:Gentium, Times New Roman;*/color:grey;font-size:0.8em;width:20px;float:left;vertical-align:text-bottom;margin: 0.2em 30px 0 3px;font-style:normal;}
            span.hang {text-align:left;margin: 0.2em 0 0 80px;}
            span.line {text-align:left;margin: 0.2em 0 0 100px;}
            span.line-key-heading {text-align:left;margin: 0.2em 0 0 -25px;}
            span.line-key {text-align:left;margin: 0.2em 0 0 -25px;}
            span.lineleftmargin {text-align:left;margin: 0.2em 0 0 -25px;}
            span.linerightmargin {text-align:right;margin: 0.2em -25px 0 0px;}
            span.indent {text-align:left;margin: 0.2em 0px 0 130px;}
            span.rightJust {text-align:right;margin-left:50%;}
            span.centerJustmargin {text-align:center;margin-left:13%;}
            span.centerJust {text-align:center;margin-left:30%;}
            span.column2 {text-align:left;position:absolute;left:350px;}
            span.hermeneia {color:black;margin-left:20%;}
            span.lect {color:purple;}
            span.pageNum {text-align:right;margin-left:50%;}
            span.runTitle {margin-left:100px;font-size:0.8em;}
            span.marginlineleft {font-size:0.8em; float:left; margin-right:-100px;}
            span.marginlineright {font-size:0.8em; float:right; margin-right:100px;}
            span.marginpage {/*line-height:60%;*/}
            span.pageheader {font-family:Gentium, Times New Roman;font-size:0.9em; color:grey; font-style:normal;}
            span.supplement { font-style:italic;}
            span.title {color:black;  font-size:1.3em;}
            span.supplied {color:red;}
            span.unclear { color:grey;}
            span.rubric {color:darkred;}
            span.original {color:green;}
            span.editorialnote {color:blue;position: relative; top: -0.5em; font-size: 80%;font-style:normal;}
            span.italic {font-style:italic;}
            </style>
         </head>
         <body>
            <span class="transcription-credit">Transcription by <a target="_blank"
               href="http://www.igntp.org/bezae.html">IGNTP</a></span>
            <div style="clear: both;"></div>
            <br/>
            <div id="text">
               <xsl:apply-templates/>
            </div>
         </body>
      </html>
   </xsl:template>


   <!-- Text stuff -->
   <xsl:template match="text()" mode="title">
      <xsl:value-of select="."/>
      <xsl:text> </xsl:text>
   </xsl:template>

   <xsl:template match="text()" mode="title-nospace">
      <xsl:value-of select="."/>
   </xsl:template>


   <!-- Page layout-->
   <xsl:template match="tei:pb">
      <span class="pageheader">
         <p>

            <xsl:text>Folio </xsl:text>
            <xsl:value-of select="@n"/>
            <xsl:text>            </xsl:text>
            <xsl:value-of select="@type"/>
            <xsl:text> (</xsl:text>
            <xsl:value-of select="@subtype"/>
            <xsl:text>)      </xsl:text>

            <span class="italic">
               <xsl:value-of select="(./ancestor::tei:div[@type='book']/@n)"/>
               <xsl:value-of
                  select="substring-after(./ancestor::tei:div[@type='chapter']/@n, 'K')"/>
            </span>
         </p>
         <p>
            <span class="line_number" title="Line number label"> Line Numbers </span>
            <span class="verse_number" title="Modern verse number label"> Verse Numbers </span>
            <br/>
         </p>
      </span>
   </xsl:template>

   <xsl:template match="tei:lb">
      <br/>



      <span class="line_number" title="Line number">
         <xsl:choose>
            <xsl:when test="@n='3'">
               <xsl:value-of select="@n"/>
               <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="@n='6'">
               <xsl:value-of select="@n"/>
               <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="@n='9'">
               <xsl:value-of select="@n"/>
               <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="@n='12'">
               <xsl:value-of select="@n"/>
            </xsl:when>
            <xsl:when test="@n='15'">
               <xsl:value-of select="@n"/>
            </xsl:when>
            <xsl:when test="@n='18'">
               <xsl:value-of select="@n"/>
            </xsl:when>
            <xsl:when test="@n='21'">
               <xsl:value-of select="@n"/>
            </xsl:when>
            <xsl:when test="@n='24'">
               <xsl:value-of select="@n"/>
            </xsl:when>
            <xsl:when test="@n='27'">
               <xsl:value-of select="@n"/>
            </xsl:when>
            <xsl:when test="@n='30'">
               <xsl:value-of select="@n"/>
            </xsl:when>
            <xsl:when test="@n='33'">
               <xsl:value-of select="@n"/>
            </xsl:when>
            <xsl:when test="@n='36'">
               <xsl:value-of select="@n"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:text>  </xsl:text>
            </xsl:otherwise>
         </xsl:choose>
      </span>


      <xsl:choose>
         <xsl:when test="@rend">

            <span>
               <xsl:attribute name="class">
                  <xsl:value-of select="@rend"/>
               </xsl:attribute>
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
   <xsl:template match="tei:div[@type='book']">
      <span id="{@n}"/>
      <xsl:apply-templates/>
   </xsl:template>

   <xsl:template match="tei:div[@type='chapter']">
      <span class="chapter_number" id="{@n}" title="Modern chapter number">
         <xsl:value-of select="substring-after(@n,'K')"/>
         <xsl:text>:</xsl:text>
      </span>
      <xsl:apply-templates/>
   </xsl:template>

   <xsl:template match="tei:ab">
      <span class="verse_number" title="Modern verse number">
         <xsl:value-of select="substring-after(@n,'V')"/>
         <!--this keeps the element properly closed if it's empty-->
         <xsl:comment>verse number</xsl:comment>
      </span>
      <xsl:choose>
         <xsl:when test="@type='supplement'">
            <span class="supplement">
               <xsl:apply-templates/>
            </span>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="tei:w">
      <xsl:apply-templates/>
      <xsl:text> </xsl:text>
   </xsl:template>

   <xsl:template match="tei:pc">
      <xsl:apply-templates/>
      <xsl:text> </xsl:text>
   </xsl:template>

   <xsl:template match="tei:ex">
      <span class="abbreviation" title="Expansion of abbreviated text">
         <xsl:text>(</xsl:text>
         <xsl:apply-templates/>
         <xsl:text>)</xsl:text>
      </span>
   </xsl:template>

   <xsl:template match="tei:div[@type='incipit']">
      <span class="verse_number">
         <strong>Incipit</strong>
      </span>
      <xsl:apply-templates/>
   </xsl:template>

   <xsl:template match="tei:div[@type='explicit']">
      <span class="verse_number">
         <strong>Explicit</strong>
      </span>
      <xsl:apply-templates/>
   </xsl:template>


   <!-- Margins-->
   <xsl:template match="tei:seg">
      <xsl:choose>
         <xsl:when test="@subtype='lineleft'">
            <span class="marginlineleft">
               <xsl:apply-templates/>
            </span>
         </xsl:when>
         <xsl:when test="@subtype='lineright'">
            <span class="marginlineright">
               <xsl:apply-templates/>
            </span>
         </xsl:when>
         <xsl:when test="@subtype='pagetop'">
            <span class="marginpage">
               <xsl:apply-templates/>
               <br/>
            </span>
         </xsl:when>
         <xsl:when test="@subtype='pagebottom'">
            <br/>
            <br/>
            <span class="marginpage">
               <xsl:apply-templates/>
            </span>
         </xsl:when>
         <xsl:when test="@type='secondColumn'">
            <span class="column2">
               <xsl:choose>
                  <xsl:when test="@subtype='center'">
                     <xsl:text>                     </xsl:text>
                  </xsl:when>
                  <xsl:when test="@subtype='hang'">
                     <xsl:text/>
                  </xsl:when>
                  <xsl:otherwise>    </xsl:otherwise>
               </xsl:choose>
               <xsl:apply-templates/>
            </span>
         </xsl:when>
      </xsl:choose>
   </xsl:template>

   <!-- Notes and numbers-->
   <xsl:template match="tei:note[@type='editorial']">
      <span>
         <xsl:attribute name="class">
            <xsl:choose>
               <xsl:when test="@place='right'">rightJust</xsl:when>
               <xsl:when test="@place='center'">centerJust</xsl:when>
               <xsl:when test="@place='left'">line</xsl:when>
            </xsl:choose>
         </xsl:attribute>
         <span class="editorialnote">
            <xsl:attribute name="title">
               <xsl:apply-templates mode="title"/>
            </xsl:attribute>
            <xsl:text>Note </xsl:text>
         </span>
      </span>
   </xsl:template>

   <xsl:template match="tei:note[@type='hermeneia']">
      <span title="Hermeneia">
         <xsl:attribute name="class">
            <xsl:choose>
               <xsl:when test="@place='center'">centerJustmargin</xsl:when>
            </xsl:choose>
         </xsl:attribute>
         <span class="hermeneia">
            <xsl:apply-templates/>
         </span>
      </span>
      <br/>
   </xsl:template>

   <xsl:template match="tei:note[@type='library']">
      <span>
         <xsl:attribute name="class">
            <xsl:choose>
               <xsl:when test="@place='right'">rightJust</xsl:when>
               <xsl:when test="@place='center'">centerJust</xsl:when>
               <xsl:when test="@place='left'">line</xsl:when>
            </xsl:choose>
         </xsl:attribute>
         <span class="editorialnote">
            <xsl:attribute name="title">
               <xsl:text>Library Note (</xsl:text>
               <xsl:value-of select="@rend"/>
               <xsl:text>): </xsl:text>
               <xsl:apply-templates mode="title-nospace"/>
            </xsl:attribute>
            <xsl:text>Library Note </xsl:text>
         </span>
      </span>
   </xsl:template>

   <xsl:template match="tei:note[@type='titlos']">
      <span>
         <xsl:attribute name="title">
            <xsl:text>Titlos: </xsl:text>
            <xsl:apply-templates/>
         </xsl:attribute>
         <xsl:apply-templates/>
      </span>
      <br/>
   </xsl:template>

   <xsl:template match="tei:num">
      <!-- num can be chapNum AmmSec -->
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
            <xsl:apply-templates/>
         </span>
      </span>
   </xsl:template>

   <!-- Gap, space, unclear-->
   <xsl:template match="tei:gap[not(ancestor::tei:rdg)]">
      <xsl:if test="@reason='lacuna'">
         <span class="supplied" title="Lacuna of {@extent} {@unit}">[...]</span>
      </xsl:if>
      <xsl:if test="@reason='illegible'">
         <span class="supplied" title="{@extent} {@unit} illegible">[...]</span>
      </xsl:if>
   </xsl:template>

   <xsl:template match="tei:gap[ancestor::tei:rdg]">
      <xsl:text>[...] </xsl:text>
   </xsl:template>

   <xsl:template match="tei:space">
      <xsl:choose>
         <xsl:when test="@unit='char' and @extent='1'">
            <xsl:text> </xsl:text>
         </xsl:when>
         <xsl:when test="@unit='char' and @extent='2'">
            <xsl:text>  </xsl:text>
         </xsl:when>
         <xsl:when test="@unit='char' and @extent='3'">
            <xsl:text>    </xsl:text>
         </xsl:when>
         <xsl:when test="@unit='char' and @extent='4'">
            <xsl:text>      </xsl:text>
         </xsl:when>
         <xsl:when test="@unit='char' and @extent='5'">
            <xsl:text>        </xsl:text>
         </xsl:when>
         <xsl:when test="@unit='char' and @extent='6'">
            <xsl:text>          </xsl:text>
         </xsl:when>
         <xsl:when test="@unit='char' and @extent='7'">
            <xsl:text>            </xsl:text>
         </xsl:when>
         <xsl:when test="@unit='line'">
            <br/>
         </xsl:when>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="tei:unclear">
      <span class="unclear" title="Unclear text">
         <xsl:apply-templates/>
      </span>
   </xsl:template>

   <!-- Corrections-->
   <xsl:template match="tei:app">
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
                        <xsl:when test="tei:w/text()='&om;'">
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
                        <xsl:when test="tei:w/text()='&om;'"> deletes</xsl:when>
                        <xsl:otherwise>
                           <xsl:text>: </xsl:text>
                           <xsl:apply-templates mode="title"/>
                        </xsl:otherwise>
                     </xsl:choose>
                  </xsl:when>
               </xsl:choose>
            </xsl:for-each>
         </xsl:attribute>
         <xsl:apply-templates/>
      </span>
   </xsl:template>

   <xsl:template match="tei:rdg">
      <xsl:choose>
         <xsl:when test="@type='orig'">
            <span class="original">
               <xsl:apply-templates/>
            </span>
         </xsl:when>
         <xsl:otherwise/>
      </xsl:choose>
   </xsl:template>


   <!-- Decorations and fw-->
   <xsl:template match="tei:hi[@rend='ol']">
      <span style="text-decoration:overline">
         <xsl:apply-templates/>
      </span>
   </xsl:template>

   <xsl:template match="tei:hi[@rend='rubric']">
      <span class="rubric" title="Rubricated text">
         <xsl:apply-templates/>
      </span>
   </xsl:template>

   <xsl:template match="tei:fw">
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
                     <xsl:apply-templates/>
                  </xsl:otherwise>
               </xsl:choose>
            </span>
         </span>
      </span>
      <xsl:text> </xsl:text>
   </xsl:template>

   <!-- Supplied-->
   <xsl:template match="tei:supplied">
      <span class="supplied" title="Supplied text (no longer extant or legible)"
         >[<xsl:apply-templates/>]</span>
   </xsl:template>

   <!--Abbreviations-->

   <xsl:template match="tei:abbr">
      <span>
         <xsl:attribute name="title">
            <xsl:choose>
               <xsl:when test="@type='nomSac'">Nomen sacrum (abbreviation)</xsl:when>
               <xsl:when test="@type='num'">Numeral (abbreviation)</xsl:when>
            </xsl:choose>
         </xsl:attribute>
         <xsl:apply-templates/>
      </span>
   </xsl:template>



</xsl:stylesheet>
