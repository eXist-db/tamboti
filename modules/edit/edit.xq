xquery version "1.0";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace sm="http://exist-db.org/xquery/securitymanager"; (:TODO move code into security module:)
import module namespace util="http://exist-db.org/xquery/util";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace mods="http://www.loc.gov/mods/v3" at "tabs.xqm";
import module namespace config="http://exist-db.org/mods/config" at "../config.xqm";
import module namespace security="http://exist-db.org/mods/security" at "../search/security.xqm"; (:TODO move security module up one level:)
import module namespace uu="http://exist-db.org/mods/uri-util" at "../search/uri-util.xqm";

declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace e="http://www.asia-europe.uni-heidelberg.de/";
declare namespace mads="http://www.loc.gov/mads/";

(:TODO: Code related to MADS files.:)
(:TODO: Theming of editor.:)

declare function local:create-new-record($id as xs:string, $type-request as xs:string, $target-collection as xs:string) as empty() {
    (:Copy the template into data and store it with the ID as file name.:)
    (:First, get the right template, based on the type-request and the presence or absence of transliteration.:)
    let $transliterationOfResource := request:get-parameter("transliterationOfResource", '')
    let $template-request := 
        if ($type-request = ('related-article-in-periodical', 'related-monograph-chapter', 'related-contribution-to-edited-volume', 'suebs-tibetan', 'insert-templates', 'new-instance', 'mads'))
        (:These document types do not (yet) divide into latin and transliterated.:)
        then $type-request
        else
            (:Append '-transliterated' if there is transliteration, otherwise append '-latin'.:)
            if ($transliterationOfResource and $type-request) 
            then concat($type-request, '-transliterated') 
            else concat($type-request, '-latin') 
    let $template-path := doc(concat($config:edit-app-root, '/instances/', $template-request, '.xml'))
    (:Then give it a name, store it in the temp location and set the right permissions on it.:)
    let $doc-name := concat($id, '.xml')
    let $stored := xmldb:store($config:mods-temp-collection, $doc-name, $template-path)   
    let $null := sm:chmod(xs:anyURI($stored), "rwx------")
    
    (:Get the remaining parameters that are to be stored (aside from transliterationOfResource fetched above).:)
    let $scriptOfResource := request:get-parameter("scriptOfResource", '')
    let $languageOfResource := request:get-parameter("languageOfResource", '')
    let $languageOfCataloging := request:get-parameter("languageOfCataloging", '')
    let $scriptOfCataloging := request:get-parameter("scriptOfCataloging", '')       
    
    (:Parameter 'host' is used when related records are created.:)
    let $host := request:get-parameter('host', '')
    let $doc := doc($stored)
    (:Note that we cannot use "update replace" if we want to keep the default namespace.:)
       return (
          (:Update the record with ID attribute.:)
          update value $doc/mods:mods/@ID with $id,
          update value $doc/mads:mads/@ID with $id
          ,
          (:Save the language and script of the resource.:)
          let $language-insert:=
              <mods:language>
                  <mods:languageTerm authority="iso639-2b" type="code">
                      {$languageOfResource}
                  </mods:languageTerm>
                  <mods:scriptTerm authority="iso15924" type="code">
                      {$scriptOfResource}
                  </mods:scriptTerm>
              </mods:language>
          return
          update insert $language-insert into $doc/mods:mods
          ,
          (:Save the library reference, the creation date, and the language and script of cataloguing:)
          let $recordInfo-insert:=
              <mods:recordInfo lang="eng" script="latn">
                  <mods:recordContentSource authority="marcorg">DE-16-158</mods:recordContentSource>
                  <mods:recordCreationDate encoding="w3cdtf">
                      {current-date()}
                  </mods:recordCreationDate>
                  <mods:recordChangeDate encoding="w3cdtf"/>
                  <mods:languageOfCataloging>
                      <mods:languageTerm authority="iso639-2b" type="code">
                          {$languageOfCataloging}
                      </mods:languageTerm>
                      <mods:scriptTerm authority="iso15924" type="code">
                          {$scriptOfCataloging}
                  </mods:scriptTerm>
                  </mods:languageOfCataloging>
              </mods:recordInfo>            
          return
          update insert $recordInfo-insert into $doc/mods:mods
          ,
          (:Save the name of the template used and transliteration scheme used into mods:extension.:)  
          update insert
              <extension xmlns="http://www.loc.gov/mods/v3" xmlns:e="http://www.asia-europe.uni-heidelberg.de/">
                  <e:template>{$template-request}</e:template>
                  <e:transliterationOfResource>{$transliterationOfResource}</e:transliterationOfResource>                    
              </extension>
          into $doc/mods:mods
          ,
          (:If the user requests to create a related record, a record which refers to the current record being browsed, 
          insert the ID into @xlink:href on <relatedItem>:)
          if ($host)
          then
            (
                update value doc($stored)/mods:mods/mods:relatedItem/@xlink:href with concat('#', $host),
                update value doc($stored)/mods:mods/mods:relatedItem/@type with "host"
            )
          else ()
      )
};

declare function local:create-xf-model($id as xs:string, $tab-id as xs:string, $instance-id as xs:string, $target-collection as xs:string) as element(xf:model) {
    let $instance-src := concat('get-instance.xq?tab-id=', $tab-id, '&amp;id=', $id, '&amp;data=', $config:mods-temp-collection)
    return
        <xf:model>
           <xf:instance xmlns="http://www.loc.gov/mods/v3" src="{$instance-src}" id="save-data"/>
           
           <!--The instance insert-templates contain an almost full embodiment of the MODS schema, version 3.4; 
           the full 3.4 schema is reflected in full-3.4-instance.xml. It is used mainly to insert missing elements and attributes.-->
           <xf:instance xmlns="http://www.loc.gov/mods/v3" src="instances/insert-templates.xml" id='insert-templates' readonly="true"/>
           
           <!--A fairly full selection of elements and attributes from the MODS schema used for default records not using the templates.-->
           <xf:instance xmlns="http://www.loc.gov/mods/v3" src="instances/new-instance.xml" id='new-instance' readonly="true"/>
           
           <!--A selection of elements and attributes from the MADS schema used for default records.-->
           <xf:instance xmlns="http://www.loc.gov/mads/" src="instances/mads.xml" id='mads' readonly="true"/>
    
           <!--Elements and attributes for insertion into the compact forms.-->
           <!--NB: These will all be in insert-templates.xml and are not needed.-->
           <xf:instance xmlns="http://www.loc.gov/mods/v3" src="instances/compact-template.xml" id='compact-template' readonly="true"/> 
           
           <!--Only load the code-tables that are used by the active tab. Long code-tables are the prime reason for the slowness of the editor.-->
           <xf:instance id="code-tables" src="codes-for-tab.xq?tab-id={$instance-id}" readonly="true"/>
           
           <!--Having binds would prevent a tab from being saved when clicking on another tab, so binds are not used.--> 
           <!--
           <xf:bind nodeset="instance('save-data')/mods:titleInfo/mods:title" required="true()"/>       
           -->
           
           <xf:submission id="save-submission" method="post"
              ref="instance('save-data')"
              action="save.xq?collection={$config:mods-temp-collection}&amp;action=save" replace="instance"
              instance="save-results">
           </xf:submission>
           
           <xf:submission id="save-and-close-submission" method="post"
              ref="instance('save-data')"
              action="save.xq?collection={$target-collection}&amp;action=close" replace="instance"
              instance="save-results">
           </xf:submission>
           
           <xf:submission id="cancel-submission" method="post"
              ref="instance('save-data')"
              action="save.xq?collection={$config:mods-temp-collection}&amp;action=cancel" replace="instance"
              instance="save-results">
           </xf:submission>
        </xf:model>
};
(:To change from eXist to Tamboti "theme" in the editor, close all eXist-begin and eXist-end, and open all Tamboti-begin and Tamboti-end.:)
declare function local:assemble-form($dummy-attributes as attribute()*, $style as node()*, $model as node(), $content as node()+, $debug as xs:boolean) as node()+ 
{
    let $log := util:log("DEBUG", ("##$dummy-attributes): ", $dummy-attributes))
    let $log := util:log("DEBUG", ("##$dummy-attributes): ", $dummy-attributes))
    return
    util:declare-option('exist:serialize', 'method=xhtml media-type=text/xml indent=yes process-xsl-pi=no')
    ,
    processing-instruction xml-stylesheet {concat('type="text/xsl" href="', request:get-context-path(), '/xforms/xsltforms/xsltforms.xsl"')}
    ,
    if ($debug) then 
        processing-instruction xsltforms-options {'debug="yes"'}
    else ()
    ,
    <html xmlns="http://www.w3.org/1999/xhtml" xmlns:xf="http://www.w3.org/2002/xforms" xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:mods="http://www.loc.gov/mods/v3">{$dummy-attributes}
        <head>
            <title>
            <!--eXist-begin
                eXist Bibliographical Demo - MODS Editor
                eXist-end-->
            <!--Tamboti-begin-->
                Tamboti Metadata Framework - MODS Editor
            <!--Tamboti-end-->
            </title>
            <script type="text/javascript" src="libs/scripts/jquery/jquery-1.6.2.min.js"></script> 
            <script type="text/javascript" src="../session.js.xql"></script>
            <link rel="stylesheet" type="text/css" href="edit.css"/>
            <!--Tamboti-begin-->
                <link rel="stylesheet" type="text/css" href="tamboti.css"/>
            <!--Tamboti-end-->        
            {$style}
            {$model}
        </head>
        <body>
        <div id="page-head">
        
        <!--Tamboti-begin-->
        <div id="page-head-left">
            <a href="../.." style="text-decoration: none">
                <img 
                    src="../../themes/tamboti/images/tamboti.png" 
                    title="Tamboti Metadata Framework" 
                    alt="Tamboti Metadata Framework" 
                    style="border-style: none;"/>
            
            </a>
        <div class="documentation"><a href="../../docs/index.xml" style="text-decoration: none" target="_blank">Help</a></div>
        </div>
        <div id="page-head-right">
            <a href="http://www.asia-europe.uni-heidelberg.de/en/home.html" target="_blank">
                <img 
                    src="../../themes/tamboti/images/cluster_logo.png" 
                    title="The Cluster of Excellence &quot;Asia and Europe in a Global Context: Shifting Asymmetries in Cultural Flows&quot; at Heidelberg University" 
                    alt="The Cluster of Excellence &quot;Asia and Europe in a Global Context: Shifting Asymmetries in Cultural Flows&quot; at Heidelberg University" 
                    width="200" style="border-style: none"/>
            </a>
        </div>
        <!--Tamboti-end-->
        <!--eXist-begin
                <a href="../.." style="text-decoration: none">
                    <img src="../../themes/default/images/logo.jpg" title="eXist-db: Open Source Native XML Database" style="border-style: none;text-decoration: none"/>
                </a>
                <div id="navbar">
                    <h1>Open Source Native XML Database</h1>
                </div>
                <div class="documentation"><a href="../../docs/index.xml" style="text-decoration: none" target="_blank">Help</a></div>
            eXist-end-->            
            </div>
            <div>
            <div class="container">
                <div>
                    {$content}
                </div>
            </div>
            </div>
        </body>
    </html>
};

declare function local:create-page-content($id as xs:string, $tab-id as xs:string, $type-request as xs:string, $target-collection as xs:string, $instance-id as xs:string, $record-data as xs:string, $type-data as xs:string) as element(div) {
    (:Get the part of the form that belongs to the active tab.:)
    let $form-body := collection(concat($config:edit-app-root, '/body'))/div[@tab-id = $instance-id],
    (:Get the relevant information to display in the info-line, the label for the tamplate chosen (if any) and the hint belonging to it (if any).:)
    $type-label := doc($type-data)/code-table/items/item[value = $type-request]/label,
    $type-hint := doc($type-data)/code-table/items/item[value = $type-request]/hint,
    (:Display the bottom tabs belonging to the active tab.:)
    $tab-data := concat($config:edit-app-root, '/tab-data.xml'),
    $bottom-tab-label := doc($tab-data)/tabs/tab[tab-id=$tab-id]/*[local-name() = $type-request],
    $bottom-tab-label := 
    	if ($bottom-tab-label)
    	then $bottom-tab-label
    	else doc($tab-data)/tabs/tab[tab-id=$tab-id]/label    	
    return
        <div class="content">
            <span class="info-line">
            {
                if ($type-request)
                then (
                    'Editing record of type ', 
                    <strong>{$type-label}</strong>,
                    if ($type-hint) 
                    then
                        <span class="xforms-help">
                            <span onmouseover="XsltForms_browser.show(this, 'hint', true)" onmouseout="XsltForms_browser.show(this, 'hint', false)" class="xforms-hint-icon"/>
                            <div class="xforms-help-value">{$type-hint}</div>
                        </span>
                    else ()
                ) else 'Editing record'
                ,
                let $publication-title := concat(doc($record-data)/mods:mods/mods:titleInfo[string-length(@type) = 0][1]/mods:nonSort, ' ', doc($record-data)/mods:mods/mods:titleInfo[string-length(@type) = 0][1]/mods:title) return
                    if ($publication-title != ' ') 
                    then (' with the title ', <strong>{$publication-title}</strong>) 
                    else ()
                }, on the <strong>{$bottom-tab-label}</strong> tab, to be saved in <strong> {
                    let $target-collection-display := replace(replace($target-collection, '/db/resources/users/', ''), '/db/resources/commons/', '') 
                    return
                        if ($target-collection-display eq security:get-user-credential-from-session()[1])
                        then 'resources/Home'
                        else concat('resources/', $target-collection-display)
                }</strong>.
            </span>
            <!--Here values are passed to the URL.-->
            {mods:tabs($tab-id, $id, $target-collection)}
        
            <div class="save-buttons">    
                <xf:submit submission="save-submission">
                    <xf:label class="xforms-group-label-centered-general">Save</xf:label>
                </xf:submit>
             
                <xf:trigger>
                    <xf:label class="xforms-group-label-centered-general">Save and Close</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="save-and-close-submission"/>
                        <xf:load resource="../../modules/search/index.html?filter=ID&amp;value={$id}&amp;collection={replace($target-collection, '/db', '')}" show="replace"/>
                    </xf:action>
                </xf:trigger>
             
                <xf:trigger>
                    <xf:label class="xforms-group-label-centered-general">Cancel Editing</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="cancel-submission"/>
                        <xf:load resource="../../?reload=true" show="replace"/>
                    </xf:action>
                 </xf:trigger>
             
                <span class="xforms-hint">
                    <span onmouseover="XsltForms_browser.show(this, 'hint', true)" onmouseout="XsltForms_browser.show(this, 'hint', false)" class="xforms-hint-icon"/>
                    <div class="xforms-hint-value">
                        <p>There is generally no need to click the &quot;Save&quot; button. </p>
                        <p>Be aware, however, that you are only logged in for a certain period of time (30 minutes) and when your session times out, what you have input cannot be retrieved. 
                        You can keep your session alive by clicking any tab. When your session is about to expire, you are prompted to keep it alive.</p> 
                        <p>If you know that you may not be able to finish a record, it is best to click &quot;Save and Close&quot; and return to finish the record later.</p>
                        <p>When you click the &quot;Save and Close&quot; button, the record is saved inside the folder you marked before opening the editor or the folder from which you opened it for re-editing.</p>
                        <p>You can continue editing the record by finding it and clicking the &quot;Edit Record&quot; button inside the record&apos;s detail view.</p>
                        <p>If you wish to discard what you have input and return to the search function, click &quot;Cancel Editing&quot;.</p>
                    </div>
                </span>
            </div>
            
            <!-- Import the correct form body for the tab called. -->
            {$form-body}
            
            <!--Displays button below as well.-->
            <div class="save-buttons">    
                <xf:submit submission="save-submission">
                    <xf:label class="xforms-group-label-centered-general">Save</xf:label>
                </xf:submit>
             
                <xf:trigger>
                    <xf:label class="xforms-group-label-centered-general">Save and Close</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="save-and-close-submission"/>
                        <xf:load resource="../../modules/search/index.html?filter=ID&amp;value={$id}&amp;collection={$target-collection}" show="replace"/>
                    </xf:action>
                </xf:trigger>
             
                <xf:trigger>
                    <xf:label class="xforms-group-label-centered-general">Cancel Editing</xf:label>
                    <xf:action ev:event="DOMActivate">
                        <xf:send submission="cancel-submission"/>
                        <xf:load resource="../../?reload=true" show="replace"/>
                    </xf:action>
                 </xf:trigger>
             
                <span class="xforms-hint">
                    <span onmouseover="XsltForms_browser.show(this, 'hint', true)" onmouseout="XsltForms_browser.show(this, 'hint', false)" class="xforms-hint-icon"/>
                    <div class="xforms-hint-value">
                        <p>There is generally no need to click the &quot;Save&quot; button. </p>
                        <p>Be aware, however, that you are only logged in for a certain period of time (30 minutes) and when your session times out, what you have input cannot be retrieved. 
                        You can keep your session alive by clicking any tab. When your session is about to expire, you are prompted to keep it alive.</p> 
                        <p>If you know that you may not be able to finish a record, it is best to click &quot;Save and Close&quot; and return to finish the record later.</p>
                        <p>When you click the &quot;Save and Close&quot; button, the record is saved inside the folder you marked before opening the editor or the folder from which you opened it for re-editing.</p>
                        <p>You can continue editing the record by finding it and clicking the &quot;Edit Record&quot; button inside the record&apos;s detail view.</p>
                        <p>If you wish to discard what you have input and return to the search function, click &quot;Cancel Editing&quot;.</p>
                    </div>
                </span>
            </div>
        </div>
};

(:The compact-a template (in 00-compact-main) is the same for all resource types; 
filtering is performed inside the form to display the elements needed for a particular template.
The compact-b temples (in 00-compact-related-X) are different according to their resource type; 
the only filtering that is performed is for transliteration.
The compact-c temples (in 00-compact-contents) is the same for all resource types; 
the only filtering that is performed is for transliteration.:)
declare function local:get-tab-id($tab-id as xs:string, $type-request as xs:string) {
    if ($tab-id ne 'compact-b')
    (:Only treat compact-b types.:)
    then $tab-id
    else
	    if ($type-request eq 'article-in-periodical')
	    then 'compact-b-article' 
	    else 
		    if ($type-request eq 'contribution-to-edited-volume')
		    then 'compact-b-contribution'
		    else
    		    if ($type-request eq 'monograph')
    		    then 'compact-b-monograph'
    		    else
        		    if ($type-request eq 'edited-volume')
        		    then 'compact-b-monograph'
        		    else
        			    if ($type-request eq 'book-review')
        			    then 'compact-b-review'
        			    else 
        				    if ($type-request eq 'suebs-tibetan')
        				    then 'compact-b-suebs-tibetan'
        				    else
        				        if ($type-request eq 'mads')
        				        then 'mads'
        				        else 'compact-b-xlink'
};

(:Main:)
(:Find the record.:)
let $record-id := request:get-parameter('id', '')
let $temp-record-path := concat($config:mods-temp-collection, "/", $record-id,'.xml')

(:If the record has been made with Tamoboti, it will have a template stored in <mods:extension>. 
If a new record is being created, the template name has to be retrieved from the URL in order to serve the right subform.:)

(:Get the type parameter which shows which record template has been chosen.:) 
let $type-request := request:get-parameter('type', ())

(:Clean it for any '-latin' and '-transliterated' suffixes.:)
(:NB: Is this necessary?:)
let $type-request := replace(replace($type-request, '-latin', ''), '-transliterated', '')

(:Get the path to the document containing the document type information.:)
let $type-data := concat($config:edit-app-root, '/code-tables/document-type-codes.xml')

(:Sorting data is retrieved from the type-data.:)
(:If type-sort is '1', it is a compact form and the Basic Input Forms should be shown; 
if type-sort is 3, it is a mads record and the MADS forms should be shown; 
otherwise it is a record not made with Tamboti and Title Information should be shown.:)
let $type-sort := doc($type-data)/code-table/items/item[value = $type-request]/sort

(:Get the tab-id for the upper tab to be shown. 
If no tab is specified, default to the compact-a tab when there is a template to be used with Basic Input Forms;
otherwise default to Title Information.:)
let $tab-id :=
    if ($type-sort = 1)
    then 'compact-a'
    else
        if ($type-sort = 3)
        then 'mads'
        else 'title'        
(:However, if a tab-id is passed, use this instead of the default.:)
let $tab-id := request:get-parameter('tab-id', $tab-id)

(:Get the chosen location for the record.:)
let $target-collection := uu:escape-collection-path(request:get-parameter("collection", ''))

(:Get the id of the record, if it has one; otherwise mark it "new" in order to give it one.:)
let $id-param := request:get-parameter('id', 'new')
let $new-record := xs:boolean($id-param = '' or $id-param = 'new')
(:If we do not have an incoming ID (the record has been made outside Tamboti) or if the record is new (made with Tamboti), then create an ID with util:uuid().:)
let $id :=
	if ($new-record)
    then concat("uuid-", util:uuid())
    else $id-param

(:If we are creating a new record, then we need to call get-instance.xq with new=true to tell it to get a new template and store it in temp; 
if we are editing an existing record, we copy the record from the target collection to temp, unless there is already a record in temp with the same name.:)
(:NB: What if A edits a certain record, leaving it in temp, and B edits the same record - does B then start off where A left off?:)
let $create-new-from-template :=
	if ($new-record) 
	(:Create a new record, knows its type and target-collection (but store it for the time being in temp.:)
	then local:create-new-record($id, $type-request, $target-collection)
	else
	    (:If it is an old record and the document is not in temp already, copy it there.:)
   		if (not(doc-available(concat($config:mods-temp-collection, '/', $id, '.xml'))))
   		(:Otherwise copy the old record to temp.:)
   		then xmldb:copy($target-collection, $config:mods-temp-collection, concat($id, '.xml'))
   		else ()

(:For a compact-b form, determine which subform to serve, based on the template.:)
let $instance-id := local:get-tab-id($tab-id, $type-request)
(:NB: $style appears to be introduced in order to use the xf namespace in css.:)
let $style := <style type="text/css"><![CDATA[@namespace xf url(http://www.w3.org/2002/xforms);]]></style>
let $model := local:create-xf-model($id, $tab-id, $instance-id, $target-collection)
let $content := local:create-page-content($id, $tab-id, $type-request, $target-collection, $instance-id, $temp-record-path, $type-data)
return 
    local:assemble-form(attribute {'mods:dummy'} {'dummy'}, $style, $model, $content, false())