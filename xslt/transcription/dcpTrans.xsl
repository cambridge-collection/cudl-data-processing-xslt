<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
   xmlns:date="http://exslt.org/dates-and-times"
   xmlns:parse="http://cdlib.org/xtf/parse"
   xmlns:xtf="http://cdlib.org/xtf"
   xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:cudl="http://cudl.cam.ac.uk/xtf/"
   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
   xmlns="http://www.w3.org/1999/xhtml"
   extension-element-prefixes="date"
   exclude-result-prefixes="#all">

   <xsl:output method="xml" indent="yes" encoding="UTF-8"/>

   <xsl:include href="global-var.xsl"/>
   
   <!--should footnotes be hidden for this transcription?-->
   <xsl:variable name="hideFootnotes">

      <xsl:value-of select="//status/footnotes_view/@hide"/>

   </xsl:variable>



   <xsl:template match="/">

      <xsl:element name="html">
         <xsl:element name="head">
            <meta http-equiv="Content-Type" content="text/html; charset=utf-8"></meta>
            <xsl:element name="title"><xsl:value-of select="//data/calendarnum"/></xsl:element>
            <link href="{$services_url}/stylesheets/legacy-cudl/charis-sil.css" rel="stylesheet" type="text/css"/>
         </xsl:element>

         <xsl:element name="body">
            <xsl:attribute name="class" select="'charisSIL'"/>

            <xsl:call-template name="make-header" />

            <xsl:call-template name="make-letter" />

            <xsl:call-template name="make-enclosures" />

            <xsl:call-template name="make-footnotes" />

            <xsl:call-template name="make-annotations" />

         </xsl:element>

      </xsl:element>

   </xsl:template>

   <xsl:template name="make-header">

      <xsl:element name="div">
         <xsl:attribute name="class" select="'header'" />


         <xsl:variable name="calendarnum" select="//data/calendarnum"/>
         <xsl:variable name="dcpLink" select="concat('http://www.darwinproject.ac.uk/entry-', $calendarnum)"/>


         <span class="transcription-credit">View letter on  <a target="_blank"
            href="{$dcpLink}">Darwin Correspondence Project site</a></span>



      </xsl:element>

   </xsl:template>

   <xsl:template name="make-letter">

      <xsl:apply-templates select="//text" mode="html" />

   </xsl:template>

   <xsl:template name="make-enclosures">

      <xsl:apply-templates select="//enclosure" mode="html" />

   </xsl:template>

   <xsl:template name="make-footnotes">

      <!--should footnotes be hidden?-->
      <xsl:if test="not($hideFootnotes='true')">

         <xsl:apply-templates select="//footnotes" mode="html" />

      </xsl:if>

   </xsl:template>

   <xsl:template name="make-annotations">

      <!--should footnotes be hidden?-->
      <xsl:if test="not($hideFootnotes='true')">

         <xsl:apply-templates select="//annotations" mode="html" />

      </xsl:if>

   </xsl:template>

   <!--html processing-->

   <!--elements which stay the same-->
   <xsl:template match="p|i|u|b|ul|ol|li" mode="html">


     <xsl:element name="{name()}">

            <xsl:apply-templates mode="html" />


     </xsl:element>

   </xsl:template>

   <!--elements which need converting-->
   <xsl:template match="it" mode="html">

      <xsl:element name="i">

         <xsl:apply-templates mode="html"/>

      </xsl:element>

   </xsl:template>


   <xsl:template match="super" mode="html">

      <xsl:element name="sup">

         <xsl:apply-templates mode="html"/>

      </xsl:element>

   </xsl:template>

   <xsl:template match="hsal|hdate|hsendname" mode="html">

      <xsl:element name="p">

         <xsl:apply-templates mode="html"/>

      </xsl:element>

   </xsl:template>


   <!--ignore these elements-->
   <xsl:template match="header|haddress|transcription|otherenc" mode="html">


         <xsl:apply-templates mode="html"/>


   </xsl:template>


   <xsl:template match="enclosure">

      <xsl:if test="normalize-space(.)">

         <xsl:element name="p">
            <xsl:text>[Enclosure]</xsl:text>
         </xsl:element>

         <xsl:apply-templates mode="html"/>

         </xsl:if>



      </xsl:template>

   <!--marks for footnotes and annotations-->
   <xsl:template match="mark" mode="html">

      <xsl:if test="not($hideFootnotes='true')">

         <xsl:variable name="markid" select="@id"/>
         <xsl:variable name="displaymarkid" select="substring-after($markid, '.')"/>


         <xsl:choose>
            <xsl:when test="starts-with($displaymarkid, 'f')">

               <xsl:variable name="marktext" select="normalize-space(//footnote[mark=$markid]/note)"/>
               <xsl:variable name="marklink" select="concat('#', $markid)"/>

               <xsl:element name="sup">
                  <xsl:element name="a">
                     <xsl:attribute name="title" select="$marktext"/>
                     <xsl:attribute name="href" select="$marklink"/>
                     <xsl:value-of select="$displaymarkid"/>

                  </xsl:element>
               </xsl:element>
            </xsl:when>
            <xsl:otherwise>

               <xsl:element name="sup">

                  <xsl:variable name="start_mark" select="normalize-space(//annotation[start_mark=$markid or end_mark=$markid]/start_mark)"/>
                  <xsl:variable name="end_mark" select="normalize-space(//annotation[start_mark=$start_mark]/end_mark)"/>
                  <xsl:variable name="text" select="normalize-space(//annotation[start_mark=$start_mark]/note)"/>
                  <xsl:variable name="displaystart_mark" select="substring-after($start_mark, '.')"/>
                  <xsl:variable name="displayend_mark" select="substring-after($end_mark, '.')"/>

                  <xsl:variable name="displayAnnotation" select="concat($displaystart_mark,'-',$displayend_mark,' ', $text)"/>

                  <xsl:element name="a">
                     <xsl:attribute name="title" select="$displayAnnotation"/>

                        <xsl:value-of select="$displaymarkid"/>

                     </xsl:element>
               </xsl:element>

            </xsl:otherwise>
         </xsl:choose>

      </xsl:if>

   </xsl:template>

   <!--footnotes-->
   <xsl:template match="footnotes" mode="html">

      <xsl:if test="normalize-space(.)">

         <xsl:element name="h4">
            <xsl:text>Footnotes</xsl:text>
         </xsl:element>

         <xsl:element name="ul">

            <xsl:apply-templates mode="html"/>

         </xsl:element>

      </xsl:if>
   </xsl:template>

   <xsl:template match="footnote" mode="html">

      <xsl:element name="li">

         <xsl:apply-templates mode="html"/>

      </xsl:element>

   </xsl:template>

   <xsl:template match="footnote/mark" mode="html">

      <xsl:variable name="footnoteid" select="."/>
      <xsl:variable name="displayfootnoteid" select="substring-after($footnoteid, '.')"/>

      <xsl:element name="a">
         <xsl:attribute name="id" select="$footnoteid"/>
         <xsl:value-of select="$displayfootnoteid"/>
      </xsl:element>


   </xsl:template>

   <xsl:template match="note" mode="html">

      <xsl:apply-templates mode="html"/>

   </xsl:template>

   <!--annotations-->
   <xsl:template match="annotations" mode="html">

      <xsl:if test="./annotation/start_mark">

         <xsl:element name="h4">
            <xsl:text>Annotations</xsl:text>
         </xsl:element>

         <xsl:element name="ul">

            <xsl:apply-templates select="annotation[start_mark]" mode="html"/>

         </xsl:element>

      </xsl:if>
   </xsl:template>

   <xsl:template match="annotation[start_mark]" mode="html">

      <xsl:element name="li">

         <xsl:apply-templates mode="html"/>

      </xsl:element>

   </xsl:template>

   <xsl:template match="start_mark" mode="html">

      <xsl:variable name="displaystart_mark" select="substring-after(., '.')"/>

      <xsl:value-of select="$displaystart_mark"/>

   </xsl:template>

   <xsl:template match="end_mark" mode="html">

      <xsl:variable name="displayend_mark" select="substring-after(., '.')"/>

      <xsl:value-of select="concat('- ',$displayend_mark)"/>

   </xsl:template>




</xsl:stylesheet>
