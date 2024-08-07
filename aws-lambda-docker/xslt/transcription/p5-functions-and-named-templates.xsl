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
  exclude-result-prefixes="#all"
>


  <xsl:template name="apply-mode-to-templates">
    <xsl:param name="displayMode"/>
    <xsl:param name="node"/>
    <xsl:choose>
      <xsl:when test="$displayMode = 'diplomatic'">
        <xsl:apply-templates select="$node" mode="diplomatic"/>
      </xsl:when>
      <xsl:when test="$displayMode = 'normalised'">
        <xsl:apply-templates select="$node" mode="normalised"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="$node" mode="normalised"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:function name="cudl:is_first_significant_child" as="xs:boolean">
    <xsl:param name="node"/>
    <xsl:sequence select="xs:boolean($node is $node/parent::*/(*|text()[normalize-space()])[1])"/>
  </xsl:function>

  <xsl:function name="cudl:pluralize">
    <xsl:param name="string"/>
    <xsl:param name="number"/>
    
    <xsl:variable name="string_normalized" select="replace($string,' +$','')"/>
    
    <xsl:value-of select="$string_normalized"/>
    <xsl:choose>
      <xsl:when test="$string_normalized!='' and number($number)!=1"><xsl:text>s</xsl:text></xsl:when>
      <xsl:otherwise/>
    </xsl:choose>
  </xsl:function>
  
  <xsl:function name="cudl:print_inflected_number">
    <xsl:param name="number"/>
    
    <xsl:variable name="num" select="number($number)"/>
    <xsl:choose>
      <xsl:when test="string($num) != 'NaN' and $num &lt;= 11">
        <xsl:choose>
          <xsl:when test="$num &lt;= 11">
            <xsl:number value="number($number)" format="w"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="format-number($num, '###,###,###')"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$number"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  
  <xsl:function name="functx:capitalize-first" xmlns:functx="http://www.functx.com">
    <xsl:param name="arg"/>
    <xsl:sequence select="concat(upper-case(substring($arg,1,1)),substring($arg,2))"/>
  </xsl:function>
  
  <xsl:function name="functx:lowercase-first" xmlns:functx="http://www.functx.com">
    <xsl:param name="arg"/>
    <xsl:sequence select="concat(lower-case(substring($arg,1,1)),substring($arg,2))"/>
  </xsl:function>
  
  <xsl:function name="functx:sort" as="item()*" 
    xmlns:functx="http://www.functx.com" >
    <xsl:param name="seq" as="item()*"/> 
    
    <xsl:for-each select="$seq">
      <xsl:sort select="."/>
      <xsl:copy-of select="."/>
    </xsl:for-each>
    
  </xsl:function>
  
  <xsl:function name="cudl:determine-project" as="xs:string">
    <xsl:param name="node" />
    
    <xsl:choose>
      <xsl:when test="exists($node//tei:publisher[matches(normalize-space(.),'Casebooks Project','i')])">
        <xsl:text>casebooks project</xsl:text>
      </xsl:when>
      <xsl:when test="exists($node//tei:publisher[matches(normalize-space(.),'Newton Project','i')])">
        <xsl:text>newton project</xsl:text>
      </xsl:when>
      <xsl:when test="exists($node//tei:authority[matches(normalize-space(.),'Darwin Correspondence Project','i')])">
        <xsl:text>darwin correspondence project</xsl:text>
      </xsl:when>
      <xsl:when test="exists($node//tei:publisher[matches(normalize-space(.),'The International Greek New Testament Project','i')])">
            <xsl:text>igntp</xsl:text>
        </xsl:when>
      <xsl:when test="exists($node//tei:authority[matches(normalize-space(.),'Mingana Lewis Palimpsest','i')])">
        <xsl:text>mingana lewis</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>cudl</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <xsl:function name="cudl:get-project-abbreviation" as="xs:string">
    <xsl:param name="node" />
    
    <xsl:choose>
      <xsl:when test="exists($node//tei:publisher[matches(normalize-space(.),'Casebooks Project','i')])">
        <xsl:text>casebooks</xsl:text>
      </xsl:when>
      <xsl:when test="exists($node//tei:publisher[matches(normalize-space(.),'Newton Project','i')])">
        <xsl:text>newton</xsl:text>
      </xsl:when>
      <xsl:when test="exists($node//tei:authority[matches(normalize-space(.),'Darwin Correspondence Project','i')])">
        <xsl:text>dcp</xsl:text>
      </xsl:when>
      <xsl:when test="exists($node//tei:publisher[matches(normalize-space(.),'The International Greek New Testament Project','i')])">
            <xsl:text>igntp</xsl:text>
        </xsl:when>
      <xsl:when test="exists($node//tei:authority[matches(normalize-space(.),'Mingana Lewis Palimpsest','i')])">
        <xsl:text>mingana</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>cudl</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
 
  <xsl:function name="cudl:use-junicode" as="xs:boolean">
    <xsl:param name="project_name" />
    
    <xsl:sequence select="$project_name=('darwin correspondence project','newton project', 'igntp', 'mingana lewis')"/>
  </xsl:function>
  
  <xsl:function name="cudl:use-legacy-character-and-font-processing" as="xs:boolean">
    <xsl:param name="project_name" />
    
    <xsl:sequence select="$project_name=('cudl')"/>
  </xsl:function>
  
  <xsl:function name="cudl:is-in-block" as="xs:boolean">
    <xsl:param name="node" />
    
    <xsl:sequence select="exists($node[ancestor::tei:p | ancestor::tei:l | ancestor::tei:item | ancestor::tei:ab])"/>
  </xsl:function>
  
  <xsl:function name="cudl:determine-output-element-name">
    <xsl:param name="node"/>
    <xsl:param name="default"/>
    
    <xsl:choose>
      <xsl:when test="cudl:is-in-block($node)">
        <xsl:text>span</xsl:text>
      </xsl:when>
      <xsl:when test="not(cudl:is-in-block($node))">
        <xsl:value-of select="normalize-space(($default,'div')[normalize-space(.)!=''][1])"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="normalize-space($default)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <xsl:function name="cudl:elem-empty-in-normalised-view" as="xs:boolean">
    <xsl:param name="node"/>
    
    <xsl:sequence select="xs:boolean(($viewMode = 'normalised') and ($node = $node//tei:del[not(contains(@type,'redacted'))]))"/>
  </xsl:function>
  
  <xsl:function name="cudl:count-elements" as="xs:string*">
    <xsl:param name="prefix" />
    <xsl:param name="elem" />
    <xsl:param name="context" />
    
    <!-- This code is unused because it runs hideously slow when constrained to
         tei:text. If you didn't care about including elements in the header within
         the count, this could would allow for refactoring the code for readability but
         it would result in different counts than our current approach
    -->
    <xsl:variable name="number">
      <xsl:choose>
        <xsl:when test="empty($context) or $context='body_text'">
          <xsl:number format="1" level="any" select="$elem" from="tei:text"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:number format="1" level="any" select="$elem"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    
    <xsl:value-of select="concat($prefix,$number)"/>
    
  </xsl:function>
  
  <xsl:template name="formatPageId">
    <xsl:param name="elem"/>
    <xsl:variable name="pageId" select="replace($elem/(@n,@xml:id)[1],'(CASE|PERSON)\d+-','')"/>
    <xsl:variable name="cleanedPb">
      <xsl:variable name="root">
        <xsl:choose>
          <xsl:when test="contains($pageId, '-')">
            <xsl:value-of select="normalize-space(substring-before($pageId,'-'))"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="normalize-space($pageId)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:value-of select="replace($root, '^([pf]|col)0*', '','i')"/>
    </xsl:variable>
    <xsl:variable name="is_column_break"
      select="matches($pageId,'^col','i') or $elem/local-name()='cb'"/>
    <xsl:variable name="pageAbbrev">
      <xsl:choose>
        <xsl:when test="$is_column_break">
          <xsl:text>col.</xsl:text>
        </xsl:when>
        <xsl:when test="$elem/local-name()='milestone'"/>
        <xsl:when test="(substring($cleanedPb,string-length($cleanedPb),1) ='r' or substring($cleanedPb,string-length($cleanedPb),1) ='v') and not($is_column_break or $elem/local-name()='milestone')">
          <xsl:text>f.</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>p.</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    
    <xsl:value-of select="string-join(($pageAbbrev,$cleanedPb),' ')"/>
  </xsl:template>
  
  <xsl:function name="cudl:parseUnit" as="xs:string*">
    <xsl:param name="unit"/>
    <xsl:param name="extent"/>
    <xsl:choose>
      <xsl:when test="$extent='1' and matches(normalize-space($unit),'s$')">
        <xsl:value-of select="replace(normalize-space($unit),'s$','')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$unit"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <xsl:function name="cudl:convertPointerToId" as="xs:string*">
    <xsl:param name="pointer"/>
    <xsl:value-of select="replace($pointer,'^#','')"/>
  </xsl:function>
  
  <xsl:template name="gloss">
    <xsl:param name="current_node"/>
    <xsl:param name="glossed_reg"
      select="preceding-sibling::tei:reg[@type='gloss'] | following-sibling::tei:reg[@type='gloss']"/>
    <xsl:value-of select="$glossed_reg"/>
  </xsl:template>
  
  <xsl:template name="output_positionOnPage">
    <xsl:param name="elem"/>
    <xsl:if test="not(empty($elem))">
      <xsl:variable name="positions" select="tokenize(replace($elem,'\s+',' '),',')"/>
      <xsl:variable name="nat_lang">
        <xsl:for-each select="$positions">
          <xsl:variable name="position" select="."/>
          <xsl:choose>
            <xsl:when test="matches($position,'(Q[1234]|/(uL||uS|mL|mS|bL|bS|uC|mC|bC|uR|mR|bR))')">
              <xsl:choose>
                <xsl:when test="matches($position,'(Q1|/uL)')">
                  <xsl:value-of select="normalize-space(replace(replace(.,'/*(Q1[A-Z]*|uL(-\d+)*)', ' upper left'),'\s+',' '))" />
                </xsl:when>
                <xsl:when test="matches($position,'(/uS)')">
                  <xsl:value-of select="normalize-space(replace(replace(.,'/*(uS(-\d+)*)', ' upper'),'\s+',' '))" />
                </xsl:when>
                <xsl:when test="matches($position,'(/mS)')">
                  <xsl:value-of select="normalize-space(replace(replace(.,'/*(mS(-\d+)*)', ' middle'),'\s+',' '))" />
                </xsl:when>
                <xsl:when test="matches($position,'(/bS)')">
                  <xsl:value-of select="normalize-space(replace(replace(.,'/*(bS(-\d+)*)', ' bottom'),'\s+',' '))" />
                </xsl:when>
                <xsl:when test="matches($position,'(Q2|/bL)')">
                  <xsl:value-of select="normalize-space(replace(replace(.,'/*(Q2[A-Z]*|bL(-\d+)*)', ' bottom left'),'\s+',' '))" />
                </xsl:when>
                <xsl:when test="matches($position,'(Q3|/uR)')">
                  <xsl:value-of select="normalize-space(replace(replace(.,'/*(Q3[A-Z]*|uR(-\d+)*)', ' upper right'),'\s+',' '))" />
                </xsl:when>
                <xsl:when test="matches($position,'(Q4|/bR)')">
                  <xsl:value-of select="normalize-space(replace(replace(.,'/*(Q4[A-Z]*|bR(-\d+)*)', ' bottom right'),'\s+',' '))" />
                </xsl:when>
                <xsl:when test="matches($position,'(/mL)')">
                  <xsl:value-of select="normalize-space(replace(replace(.,'/*mL(-\d+)*', ' middle left'),'\s+',' '))" />
                </xsl:when>
                <xsl:when test="matches($position,'(/mR)')">
                  <xsl:value-of select="normalize-space(replace(replace(.,'/*mR(-\d+)*', ' middle right'),'\s+',' '))" />
                </xsl:when>
                <xsl:when test="matches($position,'(/uC)')">
                  <xsl:value-of select="normalize-space(replace(replace(.,'/*uC(-\d+)*', ' upper centre'),'\s+',' '))" />
                </xsl:when>
                <xsl:when test="matches($position,'(/mC)')">
                  <xsl:value-of select="normalize-space(replace(replace(.,'/*mC(-\d+)*', ' middle centre'),'\s+',' '))" />
                </xsl:when>
                <xsl:when test="matches($position,'(/bC)')">
                  <xsl:value-of select="normalize-space(replace(replace(.,'/*bC(-\d+)*', ' bottom centre'),'\s+',' '))" />
                </xsl:when>
              </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
              <xsl:choose>
                <xsl:when test="matches(.,'(uL|mL|bL|uC|mC|bC|uR|mR|bR|uS|mS|bS)')">
                  <xsl:choose>
                    <xsl:when test="matches($position,'(uS)')">
                      <xsl:value-of select="normalize-space(replace(replace(.,'/*(uS(-\d+)*)', ' upper'),'\s+',' '))" />
                    </xsl:when>
                    <xsl:when test="matches($position,'(mS)')">
                      <xsl:value-of select="normalize-space(replace(replace(.,'/*(mS(-\d+)*)', ' middle'),'\s+',' '))" />
                    </xsl:when>
                    <xsl:when test="matches($position,'(bS)')">
                      <xsl:value-of select="normalize-space(replace(replace(.,'/*(bS(-\d+)*)', ' bottom'),'\s+',' '))" />
                    </xsl:when>
                    <xsl:when test="contains(.,'uL')">
                      <xsl:value-of select="normalize-space(replace(replace(., 'uL(-\d+)*', ' upper left'), 's+', ' '))" />
                    </xsl:when>
                    <xsl:when test="contains(.,'mL')">
                      <xsl:value-of select="normalize-space(replace(replace(., 'mL(-\d+)*', ' middle left'), 's+', ' '))" />
                    </xsl:when>
                    <xsl:when test="contains(.,'bL')">
                      <xsl:value-of select="normalize-space(replace(replace(., 'bL(-\d+)*', ' bottom left'), 's+', ' '))" />
                    </xsl:when>
                    <xsl:when test="contains(.,'uC')">
                      <xsl:value-of select="normalize-space(replace(replace(., 'uC(-\d+)*', ' upper centre'), 's+', ' '))" />
                    </xsl:when>
                    <xsl:when test="contains(.,'mC')">
                      <xsl:value-of select="normalize-space(replace(replace(., 'mC(-\d+)*', ' middle centre'), 's+', ' '))" />
                    </xsl:when>
                    <xsl:when test="contains(.,'bC')">
                      <xsl:value-of select="normalize-space(replace(replace(., 'bC(-\d+)*', ' bottom centre'), 's+', ' '))" />
                    </xsl:when>
                    <xsl:when test="contains(.,'uR')">
                      <xsl:value-of select="normalize-space(replace(replace(., 'uR(-\d+)*', ' upper right'), 's+', ' '))" />
                    </xsl:when>
                    <xsl:when test="contains(.,'mR')">
                      <xsl:value-of select="normalize-space(replace(replace(., 'mR(-\d+)*', ' middle right'), 's+', ' '))" />
                    </xsl:when>
                    <xsl:when test="contains(.,'bR')">
                      <xsl:value-of select="normalize-space(replace(replace(., 'bR(-\d+)*', ' bottom right'), 's+', ' '))" />
                    </xsl:when>
                  </xsl:choose>
                  
                </xsl:when>
                <xsl:otherwise>
                  <xsl:choose>
                    <xsl:when test="contains(., '1')">
                      <xsl:value-of select="normalize-space(replace(replace(., '1[A-Z]*', ' upper left'), 's+', ' '))" />
                    </xsl:when>
                    <xsl:when test="contains(., '2')">
                      <xsl:value-of select="normalize-space(replace(replace(., '2[A-Z]*', ' lower left'), 's+', ' '))" />
                    </xsl:when>
                    <xsl:when test="contains(., '3')">
                      <xsl:value-of select="normalize-space(replace(replace(., '3[A-Z]*', ' upper right'), 's+', ' '))" />
                    </xsl:when>
                    <xsl:when test="contains(., '4')">
                      <xsl:value-of select="normalize-space(replace(replace(., '4[A-Z]*', ' lower right'), 's+', ' '))" />
                    </xsl:when>
                  </xsl:choose>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:otherwise>
          </xsl:choose>
          <xsl:if test="position() != last()">
            <xsl:text>, </xsl:text>
          </xsl:if>
        </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="distinct" select="distinct-values(tokenize(replace($nat_lang,',\s+',','),','))"/>
      <xsl:for-each select="$distinct">
        <xsl:value-of select="."/>
        <xsl:choose>
          <xsl:when test="position() = count($distinct)"/>
          <xsl:when test="position() &lt; (count($distinct) - 1)">
            <xsl:text>, </xsl:text>
          </xsl:when>
          <xsl:when test="position() = (count($distinct) - 1)">
            <xsl:text>, and </xsl:text>
          </xsl:when>
        </xsl:choose>
      </xsl:for-each>
      <xsl:if test="not(contains($elem,'/'))">
        <xsl:text> </xsl:text>
        <xsl:choose>
          <xsl:when test="count($distinct) > 1">
            <xsl:text>parts</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>part</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:text> of page</xsl:text>
      </xsl:if>
    </xsl:if>
  </xsl:template>
  
  <xsl:template name="output_practice_name">
    <xsl:param name="practice"/>
    <xsl:param name="consultants"/>
    <xsl:choose>
      <xsl:when test="(lower-case($practice) = 'forman' and (count($consultants) = 1 and 'PERSON2824' = $consultants)) or (lower-case($practice) = 'napier' and (count($consultants) = 1 and 'PERSON5218' = $consultants))">
        <xsl:text>His</xsl:text>
      </xsl:when>
      <xsl:when test="lower-case($practice) = 'forman'">
        <xsl:text>Simon Forman</xsl:text>
      </xsl:when>
      <xsl:when test="lower-case($practice) = 'napier'">
        <xsl:text>Richard Napier</xsl:text>
      </xsl:when>
      <xsl:otherwise/>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template name="add-attr-if-exists">
    <xsl:param name="name"/>
    <xsl:param name="value" />
    
    <xsl:variable name="attrValue" select="normalize-space(string-join(distinct-values($value[normalize-space(.)]),' '))"/>
    
    <xsl:if test="normalize-space($attrValue)!=''">
      <xsl:attribute name="{$name}" select="$attrValue" />
    </xsl:if>
  </xsl:template>
  
  <xsl:function name="cudl:outputCertVerb" as="xs:string">
    <xsl:param name="cert_attr"/>
    <xsl:choose>
      <xsl:when test="$cert_attr">
        <xsl:text>may be</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>is</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <xsl:function name="cudl:contains-text-or-displayable-elem" as="xs:boolean">
    <xsl:param name="node" />
    
    <xsl:variable name="non_displayable_elems" select="if ($viewMode='normalised') then ('del') else ()"/>
    <xsl:sequence select="xs:boolean(($node/normalize-space() or $node/*[not(local-name()=($special_app_children, $non_displayable_elems))]))"/>
  </xsl:function>
  
  
  <xsl:function name="cudl:write_lacuna_or_witness_msg">
    <xsl:param name="elems"/>
    <xsl:param name="pos_in_seq"/>
    
    <xsl:variable name="return_val">
      <xsl:for-each select="$elems">
        <xsl:variable name="elem" select="."/>
        
        <xsl:variable name="element_name" select="$elem/local-name()"/>
        <xsl:variable name="elem_wit_vals" select="$elem/ancestor::*[local-name()=('rdg','lem')][1]/tokenize(@wit,'\s+')"/>
        <xsl:variable name="unique_elem_wit_names" select="cudl:get_unique_witness_names($elem_wit_vals)"/>
        <xsl:variable name="elem_built_wit_string" select="cudl:write_shelfmark_list($unique_elem_wit_names)"/>
        <xsl:variable name="more_than_one_elem_wit" select="count($unique_elem_wit_names)>1" as="xs:boolean"/>
        
        <xsl:variable name="lem_wit_vals" select="$elem/ancestor::tei:app[1]/tei:lem/tokenize(@wit,'\s+')" />
        <xsl:variable name="unique_lem_wit_names" select="cudl:get_unique_witness_names($lem_wit_vals)"/>
        <xsl:variable name="lem_built_wit_string" select="cudl:write_shelfmark_list($unique_lem_wit_names)"/>
        
        <xsl:variable name="noun">
          <xsl:choose>
            <xsl:when test="matches($element_name, '^lacuna')">
              <xsl:text>lacuna</xsl:text>
              <xsl:if test="$more_than_one_elem_wit">
                <xsl:text>e</xsl:text>
              </xsl:if>
            </xsl:when>
            <xsl:when test="matches($element_name, '^wit')">
              <xsl:text>witness</xsl:text>
              <xsl:if test="$more_than_one_elem_wit">
                <xsl:text>es</xsl:text>
              </xsl:if>
            </xsl:when>
            <xsl:when test="matches($element_name, '^handShift')">
              <xsl:text>hand</xsl:text>
            </xsl:when>
          </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="verb">
          <xsl:choose>
            <xsl:when test="matches($element_name, 'End$')">
              <xsl:text>end</xsl:text>
            </xsl:when>
            <xsl:when test="matches($element_name, 'Start$') or $element_name = 'handShift'">
              <xsl:text>start</xsl:text>
            </xsl:when>
          </xsl:choose>
          <xsl:if test="$more_than_one_elem_wit = false()">
            <xsl:text>s</xsl:text>
          </xsl:if>
        </xsl:variable>
        
        <xsl:variable name="lacuna_witness_msg">
          <xsl:choose>
            <xsl:when test="$more_than_one_elem_wit = false()">
              <xsl:text>A </xsl:text>
              <xsl:value-of select="$noun"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="functx:capitalize-first($noun)"/>
            </xsl:otherwise>
          </xsl:choose>
          
          <xsl:text> in </xsl:text>
          <xsl:value-of select="$elem_built_wit_string"/>
          <xsl:text> </xsl:text>
          <xsl:value-of select="$verb"/>
          <xsl:text> here</xsl:text>
        </xsl:variable>
        
        <xsl:variable name="base_text_msg">
          <xsl:if test="$pos_in_seq=1">
            <xsl:variable name="verbal_root"><xsl:text>provide</xsl:text></xsl:variable>
            
            <xsl:text> and </xsl:text>
            <xsl:choose>
              <xsl:when test="$elem[ancestor::tei:lem]">
                <xsl:choose>
                  <xsl:when test="$more_than_one_elem_wit = false()">
                    <xsl:text>it</xsl:text>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:text>they</xsl:text>
                  </xsl:otherwise>
                </xsl:choose>
                <xsl:text> </xsl:text>
                <xsl:value-of select="$verbal_root"/>
                <xsl:if test="$more_than_one_elem_wit = false()">
                  <xsl:text>s</xsl:text>
                </xsl:if>
              </xsl:when>
              <xsl:when test="$elem[ancestor::tei:rdg]">
                <xsl:value-of select="$lem_built_wit_string"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="$verbal_root"/>
                <xsl:if test="count(distinct-values($unique_lem_wit_names))=1">
                  <xsl:text>s</xsl:text>
                </xsl:if>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="$elem_built_wit_string"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="$verbal_root"/>
                <xsl:if test="count(distinct-values($unique_lem_wit_names))=1">
                  <xsl:text>s</xsl:text>
                </xsl:if>
              </xsl:otherwise>
            </xsl:choose>
            <xsl:text> the best reading</xsl:text>
          </xsl:if>
        </xsl:variable>
        
        <xsl:value-of select="concat($lacuna_witness_msg,$base_text_msg,'.')"/>
      </xsl:for-each>
    </xsl:variable>
    
    <xsl:value-of select="string-join($return_val,' ')"/>
  </xsl:function>
  
  <xsl:function name="cudl:get_unique_witness_names" as="xs:string*">
    <xsl:param name="elem_wit_attr"/>
    <xsl:variable name="wit_attrs_sorted" select="cudl:sort_wit_attrs($elem_wit_attr)" />
    
    <xsl:variable name="return_val" as="xs:string*">
      <xsl:for-each select="$wit_attrs_sorted">
        <xsl:variable name="i" select="."/>
        <xsl:sequence select="$witness_names[@pointer_to= $i]/@short_name"/>
      </xsl:for-each>
    </xsl:variable>
    <xsl:sequence select="distinct-values($return_val)"/>
  </xsl:function>
  
  <xsl:function name="cudl:write_shelfmark_list" as="xs:string">
    <xsl:param name="wits"/>
    <xsl:variable name="num_wits" select="count($wits)"/>
    <xsl:variable name="return_val" as="xs:string*">
      <xsl:for-each select="$wits">
        <xsl:variable name="i" select="."/>
        <xsl:variable name="pos" select="position()"/>
        <xsl:variable name="joiner">
          <xsl:choose>
            <xsl:when test="$pos > 1 and ($pos &lt; $num_wits)">
              <xsl:text>, </xsl:text>
            </xsl:when>
            <xsl:when test="$pos >1 and ($pos = $num_wits)">
              <xsl:text> and </xsl:text>
            </xsl:when>
          </xsl:choose>
        </xsl:variable>
        <xsl:value-of select="concat($joiner, $i)"/>
      </xsl:for-each>
    </xsl:variable>
    <xsl:value-of select="string-join($return_val,'')"/>
  </xsl:function>
  
  <xsl:function name="cudl:sort_wit_attrs" as="xs:string*">
    <xsl:param name="elem_wit_attr"/>
    <xsl:for-each select="$elem_wit_attr">
      <xsl:sort select="index-of($witnesses,.)[1]"/>
      <xsl:sequence select="."/>
    </xsl:for-each>
  </xsl:function>
  
  <xsl:function name="cudl:write_handShift_msg">
    <xsl:param name="handShift_elems"/>
    <xsl:param name="in_app_msg"/>
    
    <xsl:variable name="hand_name" select="$hands[@pointer_to=$handShift_elems/@new]"/>
    <xsl:value-of select="$hand_name"/>
    <xsl:if test="not(matches($hand_name,'(hand|mechanically printed text)','i'))"><xsl:text>&#x2019;s hand</xsl:text></xsl:if>
    <xsl:text> starts </xsl:text>
    <xsl:choose>
      <xsl:when test="$in_app_msg=false()">here</xsl:when>
      <xsl:when test="$in_app_msg=true()">
        <xsl:text>in </xsl:text>
        <xsl:variable name="wit_attrs"
          select="$handShift_elems/(ancestor::tei:lem|ancestor::tei:rdg)[1]/tokenize(@wit,'\s+')"/>
        <xsl:variable name="wit_names" select="cudl:get_unique_witness_names($wit_attrs)"/>
        <xsl:value-of select="cudl:write_shelfmark_list($wit_names)"/>
      </xsl:when>
    </xsl:choose>
  </xsl:function>
</xsl:stylesheet>