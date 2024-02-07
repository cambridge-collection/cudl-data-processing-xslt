<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0" xmlns:tei="http://www.tei-c.org/ns/1.0"
                xmlns:functx="http://www.functx.com" xmlns:xs="http://www.w3.org/2001/XMLSchema"    xmlns:util="http://cudl.lib.cam.ac.uk/xtf/ns/util"
                exclude-result-prefixes="#all">

    <!-- receives param from java AWSLambda_CUDLGenerateTranscriptionHTML_AddEvent function -->
    <xsl:param name="dest_dir" as="xs:string*" required="yes" /><!-- Point to the output directory -->
    <xsl:param name="data_dir" as="xs:string*" required="no" />
    <xsl:param name="num_chunks" as="xs:string*" required="no" /><!-- Set to a value of greater than 1 to break a document into chunks -->
    <xsl:param name="path_to_buildfile" as="xs:string*" required="no"/>
    
    <xsl:output method="xml" encoding="UTF-8" indent="no"/>

    <xsl:include href="prune.xsl"/>

    <xsl:variable name="repo.root" select="string-join(tokenize(replace(document-uri(doc('pagify.xsl')),'^file:',''),'/')[position() lt (last() - 3) ],'/')"/>
    <xsl:variable name="clean_dest_dir" select="util:path-to-directory($dest_dir,$path_to_buildfile)"/>
    <xsl:variable name="clean_data_dir" select="util:path-to-directory($data_dir,$path_to_buildfile)"/>
    <xsl:variable name="chunks" as="xs:integer">
        <xsl:choose>
            <xsl:when test="$num_chunks castable as xs:integer and xs:integer($num_chunks) gt 1">
                <xsl:value-of select="xs:integer($num_chunks)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="1"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:variable name="surfaces_with_content" select="/*/tei:facsimile/tei:surface[not(@xml:id = preceding-sibling::tei:surface/@xml:id)][util:surface-has-content(.)]" as="item()*"/>

    <xsl:key name="pb-by-n" match="tei:pb" use="@n"/>
    <xsl:key name="pb-by-id" match="tei:pb" use="@xml:id"/>
    <xsl:key name="pb-by-facs" match="tei:pb" use="for $x in tokenize(normalize-space(@facs),'\s+') return replace($x,'^#','')"/>
    <xsl:key name="surface-xmlid" match="tei:surface[@xml:id]" use="concat('#',@xml:id)"/>
    <xsl:key name="pb-with-valid-context-by-facs" match="tei:pb[util:has-valid-context(.) and @facs]" use="@facs"/>

    <xsl:template match="/tei:TEI[not(util:document-has-textual-content(.))]|/tei:teiCorpus[not(util:document-has-textual-content(.))]"/>

    <xsl:template match="/tei:TEI[util:document-has-textual-content(.)]|/tei:teiCorpus[util:document-has-textual-content(.)]">
        <xsl:variable name="context" select="." as="node()*"/>
        <xsl:choose>
            <xsl:when test="descendant::tei:div[tokenize(@decls,'\s+')='#unpaginated'] and $chunks gt 1">
                <xsl:message select="util:construct-output-filename-path($context, '','','')" />
                <xsl:result-document method="xml" encoding="UTF-8" indent="no" href="{util:construct-output-filename-path($context, '','','')}">
                    <xsl:copy-of select="."/>
                </xsl:result-document>
            </xsl:when>
            <xsl:when test="util:chunkify-document($context)">
                <xsl:variable name="unique-pb-elems" select="//tei:pb[exists(key('surface-xmlid',@facs))][util:has-valid-context(.)]"/>
                <xsl:variable name="size_of_chunks" select="(count($unique-pb-elems) idiv $chunks, 2)[. != 0][1]"/>
                <xsl:for-each-group select="$unique-pb-elems" group-by="string-join((ancestor::tei:div[@type='translation']/@type,string((position() -1) idiv $size_of_chunks)),'-')">
                    <xsl:variable name="current_surface_elems" select="key('surface-xmlid',current-group()/@facs)" as="item()*"/>
                    <xsl:variable name="matching_pb_elems" select="current-group()" as="item()*"/>
                    
                    <xsl:variable name="type" select="ancestor::tei:div[@type='translation']/@type"/>
                    
                    <xsl:variable name="pbStart_elem" select="key('pb-by-id',util:get-pb-elem($matching_pb_elems[1]/@n, 'start', $context,$type), $context)[1]" as="item()*"/>
                    
                    <xsl:variable name="final-page-in-excerpt" select="$matching_pb_elems[last()]"/>
                    
                    <xsl:variable name="pbEnd_elem" select="key('pb-by-id',util:get-pb-elem($final-page-in-excerpt/@n, 'end', $context,$type), $context)[1]" as="item()*"/>
                    <xsl:variable name="final_node" select="if (not(empty($pbEnd_elem))) then $pbEnd_elem else ($context//node())[last()]" as="item()"/>
                    <xsl:if test="exists($pbStart_elem)">
                        <xsl:variable name="page_xml" as="item()*">
                            <xsl:apply-templates select="util:with-document-root(util:page-content($pbStart_elem,$final_node, $context))" mode="prune"/>
                        </xsl:variable>
                        
                        <xsl:if test="$page_xml[descendant::tei:text[normalize-space(.) or descendant::tei:*[self::tei:gap|self::tei:figure|self::tei:graphic|self::tei:g]] or descendant::tei:sourceDoc[normalize-space(.) or descendant::tei:*[self::tei:gap|self::tei:figure|self::tei:graphic|self::tei:g]]]">
                            <xsl:message
                                select="concat('Creating ', util:construct-output-filename-path($context, $type, $current_surface_elems[1]/@xml:id, ''))" />
                            <xsl:result-document method="xml" encoding="UTF-8" indent="no"
                                href="{util:construct-output-filename-path($context, $type, $current_surface_elems[1]/@xml:id, '')}">
                                
                                <xsl:copy-of select="$page_xml" />
                            </xsl:result-document>
                        </xsl:if>
                    </xsl:if>
                </xsl:for-each-group>
            </xsl:when>
            <xsl:otherwise>
                <!-- Paginate document -->
                <xsl:for-each select="$surfaces_with_content">
                    <xsl:variable name="position" select="position()"/>
                    <xsl:variable name="surface_elem" select="."/>
                    <xsl:variable name="surfaceID" select="@xml:id" as="xs:string*"/>
                    <xsl:variable name="matching_pb_elems" select="key('pb-by-facs',$surfaceID, $context)[util:has-valid-context(.)]" as="item()*"/>
                    
                    <xsl:choose>
                        <xsl:when test="exists($matching_pb_elems[ancestor::tei:div[tokenize(@decls,'\s+')='#unpaginated']])">
                            <!-- This condition is used to create for DCP volumes. It allows us to createa master file for an entire classmark (Dar 93) and have it so that you can scroll through and see all the images and letter transcriptions in that item. A later release will deal with displaying individual letters - a la the Darwin Hooker correspondence -->
                            <!-- Add trap for untyped containers -->
                            <xsl:variable name="unpaginated-containers" select="$matching_pb_elems/ancestor::tei:div[tokenize(@decls,'\s+')='#unpaginated']" as="item()*"/>
                            
                            <xsl:for-each select="$matching_pb_elems/ancestor::tei:div[tokenize(@decls,'\s+')='#unpaginated']">
                                <xsl:variable name="type" select="@type" as="xs:string*"/>
                                <xsl:variable name="current_container" select="."/>
                                <xsl:if test="$matching_pb_elems[. is ($current_container//tei:pb)[1]]">
                                    <xsl:variable name="surface-end" select="($current_container//tei:pb)[last()]/replace(@facs,'^#','')" />
                                    
                                    <xsl:variable name="page_xml" as="item()*">
                                        <xsl:apply-templates select="util:with-document-root(util:unpaginated-content($matching_pb_elems, $context, $type))"  mode="prune" />
                                    </xsl:variable>
                                    <xsl:message select="util:construct-output-filename-path($context, $type,$surfaceID,$surface-end)"></xsl:message>
                                    <xsl:result-document method="xml" encoding="UTF-8" indent="no" href="{util:construct-output-filename-path($context, $type,$surfaceID,$surface-end)}">
                                        <xsl:copy-of select="$page_xml"/>
                                    </xsl:result-document>
                                </xsl:if>
                            </xsl:for-each>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:for-each select="('',$matching_pb_elems/ancestor::tei:div[@type='translation']/@type)">
                                <xsl:variable name="type" select="."/>
                                <xsl:variable name="pbStart_elem" select="key('pb-by-id',util:get-pb-elem($matching_pb_elems[1]/@n, 'start', $context,$type), $context)[1]" as="item()*"/>
                                <xsl:variable name="final-page-in-excerpt" select="if (util:chunkify-document($context) eq false()) then $pbStart_elem else key('pb-by-facs',$surfaces_with_content[position() = ( floor(count($surfaces_with_content) div $chunks) * $position, last())][1]/string(@xml:id), $context)[1]"/>
                                <xsl:variable name="pbEnd_elem" select="key('pb-by-id',util:get-pb-elem($final-page-in-excerpt/@n, 'end', $context,$type), $context)[1]" as="item()*"/>
                                <xsl:variable name="final_node" select="if (not(empty($pbEnd_elem))) then $pbEnd_elem else ($context//node())[last()]" as="item()"/>
                                <xsl:if test="exists($pbStart_elem)">
                                    <xsl:variable name="page_xml" as="item()*">
                                        <xsl:apply-templates select="util:with-document-root(util:page-content($pbStart_elem,$final_node, $context))"  mode="prune"></xsl:apply-templates>
                                    </xsl:variable>
                                    
                                    <xsl:if test="$page_xml[descendant::tei:text[normalize-space(.) or descendant::tei:*[self::tei:gap|self::tei:figure|self::tei:graphic|self::tei:g]] or descendant::tei:sourceDoc[normalize-space(.) or descendant::tei:*[self::tei:gap|self::tei:figure|self::tei:graphic|self::tei:g]]]">
                                        <xsl:result-document method="xml" encoding="UTF-8" indent="no"
                                            href="{util:construct-output-filename-path($context, $type, $surfaceID, '')}">
                                            <xsl:message
                                                select="concat('Creating ', util:construct-output-filename-path($context, $type, $surfaceID, ''))" />
                                            <xsl:copy-of select="$page_xml" />
                                        </xsl:result-document>
                                    </xsl:if>
                                </xsl:if>
                            </xsl:for-each>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!--
    Get a document node containing the specified node.

    If the node is not already rooted at a document, a document node is created with the node as
    the child.

    This can be used where a node must be rooted under a document, for example where key() needs
    to be able to look up values in the node's tree.
    -->
    <xsl:function name="util:with-document-root" as="document-node()">
        <xsl:param name="node" as="node()"/>
        <xsl:choose>
            <xsl:when test="root($node) instance of document-node()">
                <xsl:sequence select="$node"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:document>
                    <xsl:sequence select="$node"/>
                </xsl:document>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>


    <xsl:function name="util:chunkify-document" as="xs:boolean">
        <xsl:param name="context"/>

        <xsl:sequence select="$chunks gt 1
            and
            not(root($context)//tei:div[tokenize(@decls,'\s+')='#unpaginated'])
            " />
        <!-- Jennie, it doesn't really make sense to chunk unpaginated documents.
             Outputting them is already blazingly quick since they output entire divs
             and don't have any expensive preceding/following predicates.
        -->
    </xsl:function>
    
    <xsl:function name="util:unpaginated-content" as="node()*">
        <xsl:param name="pb1" as="node()"/>
        <xsl:param name="node" as="node()"/>
        <xsl:param name="type" as="xs:string*"/>

        <xsl:choose>
            <xsl:when test="$node[self::tei:teiHeader]">
                <xsl:copy-of select="$node"/>
            </xsl:when>
            <xsl:when test="$node[self::tei:facsimile]">
                <xsl:element name="{name($node)}" namespace="{$node/namespace-uri()}">
                    <xsl:copy-of select="$node/@*"/>
                    <xsl:copy-of select="$node/tei:surface[key('pb-by-facs',@xml:id,$pb1/ancestor::tei:div[tokenize(@decls,'\s+')='#unpaginated'][@type=$type])]" />
                </xsl:element>
            </xsl:when>
            <xsl:when test="$node[self::*]">
                <!-- $node is an element() -->
                <xsl:choose>
                    <xsl:when test="$node is $pb1 or $node[self::tei:div[tokenize(@decls,'\s+')='#unpaginated'][@type=$type]][descendant::tei:pb[@xml:id = $pb1/@xml:id]]">
                        <xsl:copy-of select="$node"/>
                    </xsl:when>
                    <xsl:when test="$node[descendant::tei:pb[. is $pb1][ancestor::tei:div[tokenize(@decls,'\s+')='#unpaginated']/@type=$type]]">
                        <xsl:element name="{name($node)}" namespace="{$node/namespace-uri()}">
                            <xsl:sequence select="for $i in ( $node/node() |
                                $node/@* ) return util:unpaginated-content($pb1, $i, $type)"/>
                        </xsl:element>
                    </xsl:when>
                    <xsl:otherwise/>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="$node[count(. | ../@*) = count(../@*)]">
                <!-- $node is an attribute -->
                <xsl:attribute name="{name($node)}">
                    <xsl:sequence select="data($node)"/>
                </xsl:attribute>
            </xsl:when>
            <xsl:otherwise/>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="util:page-content" as="node()*">
        <xsl:param name="pb1" as="node()"/>
        <xsl:param name="pb2" as="node()"/>
        <xsl:param name="node" as="node()"/>

        <xsl:choose>
            <xsl:when test="$node[self::tei:teiHeader]">
                <xsl:copy-of select="$node"/>
            </xsl:when>
            <xsl:when test="$node[self::tei:facsimile]">
                <xsl:element name="{name($node)}" namespace="{$node/namespace-uri()}">
                    <xsl:copy-of select="$node/@*"/>
                    <xsl:copy-of select="$node/tei:surface"/>
                </xsl:element>
            </xsl:when>
            <xsl:when test="$node[self::*]">
                <!-- $node is an element() -->
                <xsl:choose>
                    <xsl:when test="$node is $pb1">
                        <xsl:copy-of select="$node"/>
                    </xsl:when>
                    <!-- some $n in $node/descendant::* satisfies
                        ($n is $pb1 or $n is $pb2) -->
                    <xsl:when test="$node[descendant::tei:pb[. is $pb1 or . is $pb2]]">
                        <xsl:element name="{name($node)}" namespace="{$node/namespace-uri()}">
                            <xsl:sequence select="for $i in ( $node/node() |
                                $node/@* ) return util:page-content($pb1, $pb2, $i)"/>
                        </xsl:element>
                    </xsl:when>
                    <xsl:when test="($node >> $pb1) and ($node &lt;&lt;
                        $pb2)">
                        <xsl:copy-of select="$node"/>
                    </xsl:when>
                    <xsl:otherwise />
                </xsl:choose>
            </xsl:when>
            <xsl:when test="$node[count(. | ../@*) = count(../@*)]">
                <!-- $node is an attribute -->
                <xsl:attribute name="{name($node)}">
                    <xsl:sequence select="data($node)"/>
                </xsl:attribute>
            </xsl:when>
            <xsl:otherwise>
                <xsl:choose>
                    <xsl:when test="($node >> $pb1) and ($node &lt;&lt;
                        $pb2)">
                        <xsl:copy-of select="$node"/>
                    </xsl:when>
                    <xsl:otherwise/>
                </xsl:choose>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="util:get-pb-elem" as="item()*">
        <xsl:param name="opening_name" as="xs:string*" />
        <xsl:param name="boundary_name" as="xs:string*" />
        <xsl:param name="root_elem" as="item()*" />
        <xsl:param name="type" as="xs:string*" />

        <xsl:variable name="potential_pbs" select="key('pb-by-n',$opening_name,$root_elem)[exists(key('surface-xmlid',@facs,root(.)))][util:has-valid-context(.)]" as="item()*"/>
        <xsl:variable name="milestone" select="
            if ($type='translation')
            then (
            $potential_pbs[ancestor::tei:div[@type='translation']],
            $potential_pbs[ancestor::tei:div[tokenize(@decls,'\s+')='#unpaginated']]
            )[1]
            else
            $potential_pbs[not(ancestor::tei:div[@type='translation'])]
            "/>

        <xsl:choose>
            <xsl:when test="$boundary_name = 'start'">
                <xsl:choose>
                    <xsl:when test="$milestone[normalize-space(@next)!='']">
                        <xsl:value-of select="$milestone[normalize-space(@next)!='']/@xml:id"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="$milestone/@xml:id"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="$boundary_name = 'end'">
                <xsl:choose>
                    <xsl:when test="$milestone[@next][replace(@next,'^#','') = root(.)//tei:pb/@xml]">
                        <xsl:value-of select="$milestone[@next]/replace(@next,'^#','')"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="
                            ($milestone/following::tei:pb[exists(key('surface-xmlid',@facs))]
                            [util:has-valid-context(.)]
                            )[1]/@xml:id"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="util:has-valid-context" as="xs:boolean">
        <xsl:param name="context"/>

        <!-- Presume that if @next contains content that it's accurate to increase excecution speed of script -->
        <xsl:sequence select="exists($context[normalize-space(@next)!=''])
            or exists($context[normalize-space(@prev)!=''])
            or exists($context[not(ancestor::tei:add | ancestor::tei:note) and
                               not(util:is-in-add-span($context))])"/>
    </xsl:function>

    <xsl:key name="anchors-by-id" match="tei:anchor[@xml:id]" use="('__all__', concat('#', @xml:id))"/>
    <xsl:key name="add-spans-by-span-to" match="tei:addSpan[@spanTo]" use="('__all__', @spanTo)"/>
    <xsl:function name="util:is-in-add-span" as="xs:boolean">
        <xsl:param name="context" as="node()"/>

        <xsl:variable name="preceding-add-spans"
                      select="key('add-spans-by-span-to', '__all__', root($context))[. &lt;&lt; $context]"/>
        <xsl:variable name="span-ends"
                      select="key('anchors-by-id',
                                  (for $span in $preceding-add-spans return $span/@spanTo),
                                  root($context))[. >> $context]"/>
        <xsl:sequence select="boolean($span-ends)"/>
    </xsl:function>
    
    <xsl:function name="util:surface-has-content" as="xs:boolean">
        <!-- The purpose of this test is to exclude surface elements that don't need to be processed
             from the expensive iteration and pagination process that occurs later.
             
             For the purposes of this text, a surface needs to be procesed if:
             * it is within a div[@decls='#unpaginated']
             OR
             * the first non-whitespace only/comment node after the pb/@facs pointing to that surface 
               is anything but a pb
             OR
             * the pb/@facs pointing to it is the last pb in the document
        -->
        <xsl:param name="surface_elem"/>
        
        <xsl:variable name="facs" select="concat('#',$surface_elem/@xml:id)"/>
        
        <xsl:sequence select="exists(key('pb-with-valid-context-by-facs',$facs, $surface_elem/ancestor::*[last()])
            [
            ancestor::tei:div[tokenize(@decls,'\s+')='#unpaginated']
            or exists((following::node()[not(self::comment()|self::text()[not(normalize-space(.))])])[1][not(self::tei:pb)])
            or . is (//tei:pb)[last()]
            ])"/>
    </xsl:function>

    <xsl:function name="util:document-has-textual-content" as="xs:boolean">
        <xsl:param name="node"/>

        <xsl:sequence select="exists($node[descendant::tei:text[normalize-space(.) or exists(descendant::*[not(self::tei:div|self::tei:body|self::tei:front|self::tei:back|self::tei:pb)])]])" />
    </xsl:function>

    <xsl:function name="util:construct-output-filename-path" as="xs:string">
        <xsl:param name="node" as="item()*"/>
        <xsl:param name="type" as="xs:string*" />
        <xsl:param name="surfaceID" as="xs:string*"/>
        <xsl:param name="supplemental" as="xs:string*"/>
        
        <!-- The only @type value that's accepted into the filename 
             at this time is 'translation' -->
        <xsl:variable name="type_cleaned" select="$type[. = 'translation']" as="xs:string*"/>

        <xsl:variable name="document-uri" select="document-uri(root($node))"/>
        <xsl:variable name="filename-root" select="replace(normalize-space(tokenize(document-uri(root($node)), '/')[last()]),'\..*$','')" as="xs:string"/>
        <xsl:variable name="path-to-filename" select="string-join(tokenize(replace(document-uri(root($node)),'^file:',''), '/')[position() lt last()],'/')" as="xs:string"/>
        <xsl:variable name="output-filename" as="xs:string">
            <xsl:choose>
                <xsl:when test="util:chunkify-document(root($node)/*) eq false() or root($node)//tei:div[tokenize(@decls,'\s+')='#unpaginated'] and $chunks = 1">
                    <xsl:value-of select="concat(string-join(($filename-root,distinct-values(($surfaceID, $supplemental)),$type_cleaned)[.!=''],'-'),'.xml')"/>
                </xsl:when>
                <xsl:when test="root($node)//tei:div[tokenize(@decls,'\s+')='#unpaginated']">
                    <xsl:value-of select="concat($filename-root,'.xml')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="concat(string-join(($filename-root)[.!=''],'-'),'.',string-join(($surfaceID, $supplemental,$type_cleaned)[normalize-space(.)],'-'),'.xml')"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="hierarchy" as="xs:string">
            <xsl:choose>
                <xsl:when test="$clean_data_dir != ''">
                    <xsl:value-of select="replace(replace($path-to-filename,concat('^',$clean_data_dir),''), '^/', '')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$path-to-filename"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:value-of select="string-join(($clean_dest_dir,$hierarchy,$output-filename)[.!=''],'/')"/>

    </xsl:function>
    
    <xsl:function name="util:path-to-directory" as="xs:string">
        <xsl:param name="dir"/>
        <xsl:param name="build_dir"/>

        <xsl:variable name="directory" select="replace(normalize-space($dir),'/$','')"/>
        
        <xsl:choose>
            <xsl:when test="normalize-space($build_dir) !=''">
                <xsl:choose>
                    <xsl:when test="$directory != ''">
                        <xsl:choose>
                            <xsl:when test="matches($directory,'^/')">
                                <!-- directory is absolute path -->
                                <xsl:value-of select="$directory"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <!-- Directory is set in build file and relative to build file -->
                                <xsl:value-of select="replace(resolve-uri(concat(normalize-space($build_dir),'/',$directory)),'^file:','')"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$directory"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
</xsl:stylesheet>