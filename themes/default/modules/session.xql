xquery version "3.0";

(:~
    Handles the actual display of the search result. The pagination jQuery plugin in jquery-utils.js
    will call this query to retrieve the next page of search results.
    
    The query returns a simple table with four columns: 
    1) the number of the current record, 
    2) a link to save the current record in "My Lists", 
    3) the type of resource (represented by an icon), and 
    4) the data to display.
:)

import module namespace config="http://exist-db.org/mods/config" at "../../../modules/config.xqm";
import module namespace retrieve-mods="http://exist-db.org/mods/retrieve" at "retrieve-mods.xql";
import module namespace retrieve-vra="http://exist-db.org/vra/retrieve" at "retrieve-vra.xql";
import module namespace retrieve-tei="http://exist-db.org/tei/retrieve" at "retrieve-tei.xql";
import module namespace jquery="http://exist-db.org/xquery/jquery" at "resource:org/exist/xquery/lib/jquery.xql";
import module namespace security="http://exist-db.org/mods/security" at "../../../modules/search/security.xqm";
import module namespace sharing="http://exist-db.org/mods/sharing" at "../../../modules/search/sharing.xqm";
import module namespace clean="http://exist-db.org/xquery/mods/cleanup" at "../../../modules/search/cleanup.xql";
import module namespace kwic="http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";
import module namespace mods-common="http://exist-db.org/mods/common" at "mods-common.xql";

declare namespace mods="http://www.loc.gov/mods/v3";
declare namespace vra = "http://www.vraweb.org/vracore4.htm";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare namespace bs="http://exist-db.org/xquery/biblio/session";
declare namespace functx = "http://www.functx.com";

declare option exist:serialize "method=xhtml media-type=application/xhtml+xml enforce-xhtml=yes";

declare variable $bs:USER := security:get-user-credential-from-session()[1];
declare variable $bs:USERPASS := security:get-user-credential-from-session()[2];

declare variable $bs:THUMB_SIZE_FOR_GRID := 64;
declare variable $bs:THUMB_SIZE_FOR_GALLERY := 128;
declare variable $bs:THUMB_SIZE_FOR_DETAIL_VIEW := 256;


declare function functx:substring-before-last 
  ( $arg as xs:string? ,
    $delim as xs:string )  as xs:string {
       
   if (matches($arg, functx:escape-for-regex($delim)))
   then replace($arg,
            concat('^(.*)', functx:escape-for-regex($delim),'.*'),
            '$1')
   else ''
 } ;
 
 declare function functx:escape-for-regex 
  ( $arg as xs:string? )  as xs:string {
       
   replace($arg,
           '(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','\\$1')
 } ;
 
 declare function functx:substring-after-last 
  ( $arg as xs:string? ,
    $delim as xs:string )  as xs:string {
       
   replace ($arg,concat('^.*',functx:escape-for-regex($delim)),'')
 } ;
 
 declare function functx:capitalize-first($arg as xs:string?) as xs:string? {       
   concat(upper-case(substring($arg,1,1)),
             substring($arg,2))
};

declare function functx:replace-first( $arg as xs:string?, $pattern as xs:string, $replacement as xs:string )  as xs:string {       
   replace($arg, concat('(^.*?)', $pattern),
             concat('$1',$replacement))
 } ;

declare function bs:collection-is-writable($collection as xs:string) {
    if ($collection eq $config:groups-collection) then
        false()
    else
        security:can-write-collection($collection)
};

declare function bs:get-item-uri($item-id as xs:string) {
    fn:concat(
        request:get-scheme(),
        "://",
        request:get-server-name(),
        if((request:get-scheme() eq "http" and request:get-server-port() eq 80) or (request:get-scheme() eq "https" and request:get-server-port() eq 443))then "" else fn:concat(":", request:get-server-port()),
        
        fn:replace(request:get-uri(), "/exist/([^/]*)/([^/]*)/.*", "/exist/$1/$2"),
        
        (:fn:substring-before(request:get-url(), "/modules"), :)
        "/item/",
        $item-id
    )
};

declare function bs:view-gallery-item($mode as xs:string, $item as element(mods:mods), $currentPos as xs:int) {
    let $thumbSize := if ($mode eq "gallery") then $bs:THUMB_SIZE_FOR_GALLERY else $bs:THUMB_SIZE_FOR_GRID
    let $title := mods-common:get-short-title($item)
    return
        <li class="pagination-item {$mode}" xmlns="http://www.w3.org/1999/xhtml">
            <span class="pagination-number">{ $currentPos }</span>
            <div class="icon pagination-toggle" title="{$title}">
                <img class="magnify icon-magnifier" src="theme/images/search.png" title="Click to view full screen image"/>
                { bs:get-icon($thumbSize, $item, $currentPos) }
            </div>
            {
                if ($mode eq "gallery") then
                    <h4>{ $title }</h4>
                else
                    ()
            }
        </li>
};

declare function bs:mods-detail-view-table($item as element(mods:mods), $currentPos as xs:int) {
    let $isWritable := bs:collection-is-writable(util:collection-name($item))
    let $id := concat(document-uri(root($item)), '#', util:node-id($item))
    let $stored := session:get-attribute("personal-list")
    let $saved := exists($stored//*[@id = $id])
    let $results :=  collection($config:mods-root)//mods:mods[@ID=$item/@ID]/mods:relatedItem
    return
        <tr class="pagination-item detail" xmlns="http://www.w3.org/1999/xhtml">
            <td class="pagination-number">{$currentPos}</td>
            <td class="actions-cell">
                <a id="save_{$id}" href="#{$currentPos}" class="save">
                    <img title="{if ($saved) then 'Removes Record from My List' else 'Saves Record to My List'}" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                </a>
            </td>
            <td class="magnify detail-type">
            { bs:get-icon($bs:THUMB_SIZE_FOR_DETAIL_VIEW, $item, $currentPos)}
            </td>
            <td style="vertical-align:top;">
               <div id="image-cover-box" > 
                {
                   let $image-return :=
                   for $entry in $results
                         let $image-is-preview := $entry//mods:typeOfResource eq 'still image' and  $entry//mods:url[@access='preview']
                            let $print-image :=
                            if ($image-is-preview)
                            then 
                            (
                                let $image := collection($config:mods-root)//vra:image[@id=data($entry//mods:url)]
                                return 
                                   <p>{local:return-thumbnail($image)}</p>
                  
                            )
                            else()
                            
                          return $print-image
                   let $elements := for $element in  $item/node()
                        return  $element
                      
                  return $image-return
                  }
                </div>
            </td>
            
            <td class="detail-xml" style="vertical-align:top;">
                { bs:toolbar($item, $isWritable, $id) }
                <abbr class="unapi-id" title="{bs:get-item-uri($item/@ID)}"></abbr>
                {
                    let $collection := util:collection-name($item)
                    let $collection-short := functx:replace-first($collection, '/db/', '')
                    let $clean := clean:cleanup($item)
                    return
                        retrieve-mods:format-detail-view(string($currentPos), $clean, $collection-short)
                        (: What is $currentPos used for? :)
                }
            </td>
        </tr>
};

declare function local:basic-get-http($uri,$username,$password) {
  let $credentials := concat($username,":",$password)
  let $credentials := util:string-to-binary($credentials)
  let $headers  := 
    <headers>
      <header name="Authorization" value="Basic {$credentials}"/>
    </headers>
  return httpclient:get(xs:anyURI($uri),false(), $headers)
};
declare function local:return-thumbnail($image){
(:
let $image-name := $image/@href
let $image-suffix := fn:tokenize($image-name,'.')[2]
let $image-url := <img src="{
                        concat('data:image/',$image-suffix,';base64,',local:basic-get-http(concat(request:get-scheme(),'://',request:get-server-name(),':',request:get-server-port(),request:get-context-path(),'/rest', util:collection-name($image),"/" ,$image-name),$bs:USER,$bs:USERPASS)
                        )
                        }"  width="200px"/>
:)
let $image-url := <img src="http://kjc-ws2.kjc.uni-heidelberg.de/images/service/download_uuid/{$image/@id}?width=150" alt="" class="relatedImage"/>

return $image-url
};

declare function bs:vra-detail-view-table($item as element(vra:vra), $currentPos as xs:int) {
    let $isWritable := bs:collection-is-writable(util:collection-name($item))
    let $id := concat(document-uri(root($item)), '#', util:node-id($item))
    let $id := functx:substring-after-last($id, '/')
    let $id := functx:substring-before-last($id, '.')
    let $type := substring($id, 1, 1)
    let $id-position :=
        if ($type eq 'c')
        then '/vra:collection/@id'
        else 
            if ($type eq 'w')
            then '/vra:work/@id'
            else '/vra:image/@id'
    let $stored := session:get-attribute("personal-list")
    let $saved := exists($stored//*[@id = $id])
    let $vra-work :=  collection($config:mods-root)//vra:work[@id=$id]/vra:relationSet/vra:relation
    
    return
        <tr class="pagination-item detail" xmlns="http://www.w3.org/1999/xhtml">
            <td class="pagination-number">{$currentPos}</td>
            <td class="actions-cell">
                <a id="save_{$id}" href="#{$currentPos}" class="save">
                    <img title="{if ($saved) then 'Remove Record from My List' else 'Save Record to My List'}" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                </a>
            </td>
            <td class="list-type icon magnify">
            { bs:get-icon($bs:THUMB_SIZE_FOR_GALLERY, $item, $currentPos)}
            </td>

            <td style="vertical-align:top;">
                <div id="image-cover-box"> 
                { 
                    if ($vra-work)
                    then
                        for $entry in $vra-work
                        (:return <img src="{$entry/@relids}"/>:)
                        let $image := collection($config:mods-root)//vra:image[@id=$entry/@relids]
                            return
                                <p>{local:return-thumbnail($image)}</p>
                    else 
                        let $image := collection($config:mods-root)//vra:image[@id=$id]
                            return
                                <p>{local:return-thumbnail($image)}</p>
                     (: 
                     return <img src="{concat(request:get-scheme(),'://',request:get-server-name(),':',request:get-server-port(),request:get-context-path(),'/rest', util:collection-name($image),"/" ,$image-name)}"  width="200px"/>
                     :)               
                }
                </div>
            </td>
            <!--<td class="magnify detail-type">
            { bs:get-icon($bs:THUMB_SIZE_FOR_DETAIL_VIEW, $item, $currentPos)}
            </td>-->
            <td class="detail-xml" style="vertical-align:top;">
                { bs:toolbar($item, $isWritable, $id) }
                <!--NB: why is this phoney HTML tag used to anchor the Zotero unIPA?-->
                <!--Zotero does not import vra records <abbr class="unapi-id" title="{bs:get-item-uri(concat($item, $id-position))}"></abbr>-->
                {
                    let $collection := util:collection-name($item)
                    let $collection-short := functx:replace-first($collection, '/db/', '')
                    let $clean := clean:cleanup($item)
                    return
                        retrieve-vra:format-detail-view(string($currentPos), $clean, $collection-short, $type, $id)
                }
            </td>
        </tr>
};


declare function bs:tei-detail-view-table($item as element(), $currentPos as xs:int) {
    let $isWritable := bs:collection-is-writable(util:collection-name($item))
    let $document-uri  := document-uri(root($item))
    let $node-id := util:node-id($item)
    let $id := concat(document-uri(root($item)), '#', util:node-id($item))
    let $id := functx:substring-after-last($id, '/')
    let $id := functx:substring-before-last($id, '.')
    let $type := substring($id, 1, 1)
    let $stored := session:get-attribute("personal-list")
    let $saved := exists($stored//*[@id = $id])

    return
        <tr class="pagination-item detail" xmlns="http://www.w3.org/1999/xhtml">
            <td class="pagination-number">{$currentPos}</td>
            <td class="actions-cell">
                <a id="save_{$id}" href="#{$currentPos}" class="save">
                    <img title="{if ($saved) then 'Remove Record from My List' else 'Save Record to My List'}" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                </a>
            </td>
            <td class="detail-xml">
                { bs:toolbar($item, $isWritable, $id) }
                <!--NB: why is this phoney HTML tag used to anchor the Zotero unIPA?-->
                <!--Zotero does not import tei records <abbr class="unapi-id" title="{bs:get-item-uri(concat($item, $id-position))}"></abbr>-->
                {
                    let $collection := util:collection-name($item)
                    let $collection-short := functx:replace-first($collection, '/db/', '')
                    let $clean := clean:cleanup($item)
                    return
                        retrieve-tei:format-detail-view(string($currentPos), $clean, $collection-short, $document-uri, $node-id)
                }
            </td>
        </tr>
};

declare function bs:mods-list-view-table($item as node(), $currentPos as xs:int) {
    let $id := concat(document-uri(root($item)), '#', util:node-id($item))
    let $stored := session:get-attribute("personal-list")
    let $saved := exists($stored//*[@id = $id])
    return
        <tr xmlns="http://www.w3.org/1999/xhtml" class="pagination-item list">
            <td class="pagination-number">{$currentPos}</td>
            {
            <td class="actions-cell">
                <a id="save_{$id}" href="#{$currentPos}" class="save">
                    <img title="{if ($saved) then 'Remove Record from My List' else 'Save Record to My List'}" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                </a>
            </td>
            }
            <td class="list-type icon magnify">
            { bs:get-icon($bs:THUMB_SIZE_FOR_GALLERY, $item, $currentPos)}
            </td>
            {
            <td class="pagination-toggle">
                <abbr class="unapi-id" title="{bs:get-item-uri($item/@ID)}"></abbr>
                <a>
                {
                    let $collection := util:collection-name($item)
                    let $collection-short := functx:replace-first($collection, '/db/', '')
                    let $clean := clean:cleanup($item)
                    return
                        retrieve-mods:format-list-view(string($currentPos), $clean, $collection-short)
                        (: Originally $item was passed to retrieve-mods:format-list-view() - was there a reason for that? Performance? :)
                }
                </a>
            </td>
            }
        </tr>
};

declare function bs:vra-list-view-table($item as node(), $currentPos as xs:int) {
    let $id := concat(document-uri(root($item)), '#', util:node-id($item))
    let $id := functx:substring-after-last($id, '/')
    let $id := functx:substring-before-last($id, '.')
    let $type := substring($id, 1, 1)
    let $id-position :=
        if ($type eq 'c')
        then '/vra:collection/@id'
        else 
            if ($type eq 'w')
            then '/vra:work/@id'
            else '/vra:image/@id'
    let $stored := session:get-attribute("personal-list")
    let $saved := exists($stored//*[@id eq $id])
        return
            <tr xmlns="http://www.w3.org/1999/xhtml" class="pagination-item list">
                <td class="pagination-number" style="vertical-align:middle">{$currentPos}</td>
                {
                <td class="actions-cell" style="vertical-align:middle">
                    <a id="save_{$id}" href="#{$currentPos}" class="save">
                        <img title="{if ($saved) then 'Remove Record from My List' else 'Save Record to My List'}" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                    </a>
                </td>
                }
                <td class="list-type icon magnify" style="vertical-align:middle">
                { bs:get-icon($bs:THUMB_SIZE_FOR_GALLERY, $item, $currentPos)}
                </td>
                {
                <td class="pagination-toggle" style="vertical-align:middle">
                    <!--Zotero does not import vra records <abbr class="unapi-id" title="{bs:get-item-uri(concat($item, $id-position))}"></abbr>-->
                    <a>
                    {
                        let $collection := util:collection-name($item)
                        let $collection-short := functx:replace-first($collection, '/db/', '')
                        let $clean := clean:cleanup($item)
                        return
                            retrieve-vra:format-list-view(string($currentPos), $clean, $collection-short)
                    }
                    </a>
                </td>
                }
            </tr>
};

declare function bs:tei-list-view-table($item as node(), $currentPos as xs:int) {
    let $document-uri  := document-uri(root($item))
    let $node-id := util:node-id($item)
    let $id := concat($document-uri, '#', $node-id)
    let $id := functx:substring-after-last($id, '/')
    let $id := functx:substring-before-last($id, '.')
    let $type := substring($id, 1, 1)
    let $stored := session:get-attribute("personal-list")
    let $saved := exists($stored//*[@id = $id])
    return
        <tr xmlns="http://www.w3.org/1999/xhtml" class="pagination-item list">
            <td class="pagination-number">{$currentPos}</td>
            {
            <td class="actions-cell">
                <a id="save_{$id}" href="#{$currentPos}" class="save">
                    <img title="{if ($saved) then 'Remove Record from My List' else 'Save Record to My List'}" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                </a>
            </td>
            }
            <td class="list-type icon magnify">
            { bs:get-icon($bs:THUMB_SIZE_FOR_GALLERY, $item, $currentPos)}
            </td>
            {
            <td class="pagination-toggle">
                <!--Zotero does not import tei records <abbr class="unapi-id" title="{bs:get-item-uri(concat($item, $id-position))}"></abbr>-->
                <a>
                {
                    let $collection := util:collection-name($item)
                    let $collection-short := functx:replace-first($collection, '/db/', '')
                    (:let $clean := clean:cleanup($item):)
                    return
                        retrieve-tei:format-list-view(string($currentPos), $item, $collection-short, $document-uri, $node-id)
                }
                </a>
            </td>
            }
        </tr>
};

declare function bs:plain-list-view-table($item as node(), $currentPos as xs:int) {
    let $kwic := kwic:summarize($item, <config xmlns="" width="40"/>)
    let $id := concat(document-uri(root($item)), '#', util:node-id($item))
    let $stored := session:get-attribute("personal-list")
    let $saved := exists($stored//*[@id = $id])
    (:NB: This gives NEP 2013-03-16, but Wolfgang has a fix. :)
    let $titleField := ft:get-field($item/@uri, "Title")
    let $title := if ($titleField) then $titleField else replace($item/@uri, "^.*/([^/]+)$", "$1")
    let $clean := clean:cleanup($item)
    let $collection := util:collection-name($item)
    let $collection-short := functx:replace-first($collection, '/db/', '')
    return
        <tr xmlns="http://www.w3.org/1999/xhtml" class="pagination-item list">
            <td class="pagination-number">{$currentPos}</td>
            {
            <td class="actions-cell">
                <a id="save_{$id}" href="#{$currentPos}" class="save">
                    <img title="Save Record to My List" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                </a>
            </td>
            }
            <td class="list-type">
                <a href="{substring($item/@uri, 2)}" target="_new">
                { bs:get-icon($bs:THUMB_SIZE_FOR_GALLERY, $item, $currentPos)}
                </a>
            </td>
            {
            <td class="pagination-toggle">
                <span>{retrieve-mods:format-list-view(string($currentPos), $clean, $collection-short)}</span>
                <h4>{xmldb:decode-uri($title)}</h4>
                { $kwic }
            </td>
            }
        </tr>
};

(:NB: If an element is returned which is not covered by this typeswitch, the following error occurs, i.e. it defaults to kwic:summarize():
the actual cardinality for parameter 1 does not match the cardinality declared in the function's signature: kwic:summarize($hit as element(), $config as element()) element()*. Expected cardinality: exactly one, got 0. [at line 349, column 34, source: /db/apps/tamboti/themes/default/modules/session.xql]
:)
(:NB: each element checked for here should appear in bs:view-table(), otherwise the detail view will show the list view.:)
declare function bs:list-view-table($item as node(), $currentPos as xs:int) {
    typeswitch ($item)
        case element(mods:mods) return
            bs:mods-list-view-table($item, $currentPos)
        case element(vra:vra) return
            bs:vra-list-view-table($item, $currentPos)
        case element(tei:person) return
            bs:tei-list-view-table($item, $currentPos)
        case element(tei:p) return
            bs:tei-list-view-table($item, $currentPos)
        case element(tei:term) return
            bs:tei-list-view-table($item, $currentPos)
        case element(tei:head) return
            bs:tei-list-view-table($item, $currentPos)
        case element(tei:TEI) return
            bs:tei-list-view-table($item, $currentPos)
        case element(tei:bibl) return
            bs:tei-list-view-table($item, $currentPos)
        default return
            bs:plain-list-view-table($item, $currentPos)
};

declare function bs:toolbar($item as element(), $isWritable as xs:boolean, $id as xs:string) {
    let $home := security:get-home-collection-uri($bs:USER)
    (:determine for image record:)
   

    (:If there is a MODS @ID, use it; otherwise take a VRA @id.:)
    let $collection := util:collection-name($item)
    let $id := $item/@ID
    let $id := 
        if ($id) 
        then $id 
        else (
            (: Handle id from vra:work and vra:image for ziziphus :)
            if (exists($item/vra:work))
            then ($item/vra:work/@id)
            else ($item/vra:image/vra:relationSet/vra:relation/@relids)
         )
     let $workdir := if(contains($collection, 'VRA_images')) then (  functx:substring-before-last($collection, "/")) else ($collection)
     let $workdir := if(ends-with($workdir,'/')) then ($workdir) else ($workdir || '/')
    
     
     let $upload-button:=  
        if (not($item/vra:image/@id))
            then <a class="upload-file-style"  directory="false" href="#{$id}" onclick="updateAttachmentDialog"><img title="Upload Attachment" src="theme/images/database_add.png" /> </a>
        else ()
    return
        <div class="actions-toolbar">
            <a target="_new" href="source.xql?id={$id}&amp;clean=yes">
                <img title="View XML Source of Record" src="theme/images/script_code.png"/>
            </a>
            {
                (: if the item's collection is writable, display edit/delete and move buttons :)
                if ($isWritable) 
                then (
                    if (xmldb:collection-available("/db/apps/ziziphus/") and name($item) eq 'vra')
                    then (
                     <a target="_new" href="/exist/apps/ziziphus/record.html?id={$id}&amp;workdir={$workdir}">
                        <img title="Edit VRA Record" src="theme/images/page_edit.png"/>
                     </a>
                    ) else (),
                    if (name($item) eq 'mods')
                    then
                    <a href="../edit/edit.xq?id={$item/@ID}&amp;collection={util:collection-name($item)}&amp;type={$item/mods:extension/*:template}">
                        <img title="Edit MODS Record" src="theme/images/page_edit.png"/>
                    </a>
                    else ()
                    ,
                    <a class="remove-resource" href="#{$id}"><img title="Delete Record" src="theme/images/delete.png"/></a>,
                    <a class="move-resource" href="#{$id}"><img title="Move Record" src="theme/images/shape_move_front.png"/></a>,
                    $upload-button
                        
                    )
                else ()
            }
            {
                (: button to add a related item :)
                if ($bs:USER ne "guest") 
                then
                    <a class="add-related" href="#{if ($isWritable) then $collection else $home}#{$item/@ID}">
                        <img title="Create Related MODS Record" src="theme/images/page_add.png"/>
                    </a>
                    else ()
            }
        </div>
};

declare function bs:get-icon-from-folder($size as xs:int, $collection as xs:string) {
    let $thumb := xmldb:get-child-resources($collection)[1]
    let $imgLink := concat(substring-after($collection, "/db"), "/", $thumb)
    return
        <img src="images/{$imgLink}?s={$size}"/>
};

(:~
    Get the preview icon for a linked image resource or get the thumbnail showing the resource type.
:)
declare function bs:get-icon($size as xs:int, $item, $currentPos as xs:int) {
    let $image-url :=
    (: NB: Refine criteria for existence of image:)
        ( 
            $item/mods:location/mods:url[@access="preview"]/string(), 
            $item/mods:location/mods:url[@displayLabel="Path to Folder"]/string() 
        )[1]
    let $type := $item/mods:typeOfResource[1]/string()
    let $hint := 
        if ($type)
        then functx:capitalize-first($type)
        else
            if (in-scope-prefixes($item) = 'xml')
            then 'Unknown Type'
            else 'Extracted Text'
    return
        if (string-length($image-url)) 
        (: Only run if there actually is a URL:)
        (: NB: It should be checked if the URL leads to an image described in the record:)
        then
            let $image-path := concat(util:collection-name($item), "/", xmldb:encode($image-url))
            return
                if (collection($image-path)) 
                then bs:get-icon-from-folder($size, $image-path)
                else
                    let $imgLink := concat(substring-after(util:collection-name($item), "/db"), "/", $image-url)
                    return
                        <img title="{$hint}" src="images/{$imgLink}?s={$size}"/>        
        else
        (: For non-image records:)
            let $type := 
                (: If there is a typeOfResource, render the icon for it. :)
                if ($type)
                (: Remove spaces and commas from the image name:)
                then translate(translate($type,' ','_'),',','')
                else
                    (: If there is no typeOfResource, but the resource is XML, render the default icon for it. :)
                    if (in-scope-prefixes($item) = 'xml')
                    then 'shape_square'
                    (: Otherwise it is non-XML contents extracted from a document by tika. This could be a PDF, a Word document, etc. :) 
                    else 'text-x-changelog'
            return 
                <img title="{$hint}" src="theme/images/{$type}.png"/>
};

declare function bs:view-table($cached as item()*, $stored as item()*, $start as xs:int, 
    $count as xs:int, $available as xs:int) {
    <table xmlns="http://www.w3.org/1999/xhtml">
    {
        for $item at $pos in subsequence($cached, $start, $available)
        let $currentPos := $start + $pos - 1
        return
            if ($count eq 1 and $item instance of element(mods:mods)) 
            then bs:mods-detail-view-table($item, $currentPos)
            else
                if ($count eq 1 and $item instance of element(vra:vra)) 
                then bs:vra-detail-view-table($item, $currentPos)
                else 
                    if ($count eq 1 and $item instance of element(tei:TEI)) 
                    then bs:list-view-table($item, $currentPos)
                    else
                        if ($count eq 1 and $item instance of element(tei:person)) 
                        then bs:tei-detail-view-table($item, $currentPos)
                        else
                            if ($count eq 1 and $item instance of element(tei:p)) 
                            then bs:tei-detail-view-table($item, $currentPos)
                            else
                                if ($count eq 1 and $item instance of element(tei:term)) 
                                then bs:tei-detail-view-table($item, $currentPos)
                                else
                                    if ($count eq 1 and $item instance of element(tei:head)) 
                                    then bs:tei-detail-view-table($item, $currentPos)
                                    else
                                        if ($count eq 1 and $item instance of element(tei:bibl)) 
                                        then bs:tei-detail-view-table($item, $currentPos)
                                        else bs:list-view-table($item, $currentPos)
    }
    </table>
};

declare function bs:view-gallery($mode as xs:string, $cached as item()*, $stored as item()*, $start as xs:int, 
    $count as xs:int, $available as xs:int) {
    <ul xmlns="http://www.w3.org/1999/xhtml">
    {
        for $item at $pos in subsequence($cached, $start, $available)
        let $currentPos := $start + $pos - 1
        (: Why does $currentPos have a final "."? Should be removed. :)
        return
            bs:view-gallery-item($mode, $item, $currentPos)
    }
    </ul>
};

(:~
    Main function: retrieves query results from session cache and
    checks which display mode to use.
:)

 declare function bs:get-resource($start as xs:int, $count as xs:int){
 
  let $resouce := session:get-attribute("mods:cached")
 
  return $resouce
 };
 
 
declare function bs:retrieve($start as xs:int, $count as xs:int) {
    let $mode := request:get-parameter("mode", "gallery")
    (:let $log := util:log("DEBUG", ("##$mode): ", $mode)):)
    (:let $log := util:log("DEBUG", ("##$count0): ", $count)):)
    (:let $log := util:log("DEBUG", ("##$start): ", $start)):)
    let $cached := session:get-attribute("mods:cached")
    (:let $log := util:log("DEBUG", ("##$cached): ", $cached)):)
    let $log := util:log("DEBUG", ("##$cached-count): ", count($cached)))
    let $stored := session:get-attribute("personal-list")
    (:let $log := util:log("DEBUG", ("##$stored): ", $stored)):)
    (:let $log := util:log("DEBUG", ("##$stored-count): ", count($stored))):)
    
    let $cached-vra-work := $cached[vra:work]
    let $log := util:log("DEBUG", ("##$cached-vra-work-count): ", count($cached-vra-work)))
    let $cached-vra-image := $cached[vra:image]
    let $log := util:log("DEBUG", ("##$cached-vra-image-count): ", count($cached-vra-image)))
    let $cached-vra-image-work := $cached-vra-image/vra:image/vra:relationSet/vra:relation[@type eq "imageOf"]/@relids
    (:let $log := util:log("DEBUG", ("##$cached-vra-image-work-ids): ", string-join($cached-vra-image-work, '|||'))):)
    (:let $log := util:log("DEBUG", ("##$cached-vra-image-work-ids-count): ", count($cached-vra-image-work))):)
    let $cached-vra-image-work := collection($config:mods-root)//vra:work[@id = $cached-vra-image-work]/..
    let $log := util:log("DEBUG", ("##$cached-vra-image-work): ", $cached-vra-image-work))
    let $log := util:log("DEBUG", ("##$cached-vra-image-work-count): ", count($cached-vra-image-work)))
    let $cached-vra := ($cached-vra-work union $cached-vra-image-work)
    let $log := util:log("DEBUG", ("##$cached-vra-count): ", count($cached-vra)))
    let $cached-mods := $cached[mods:titleInfo]
    let $log := util:log("DEBUG", ("##$cached-mods-count): ", count($cached-mods)))
    let $cached-tei := (($cached except $cached-mods) except $cached-vra)  
    let $log := util:log("DEBUG", ("##$cached-tei-count): ", count($cached-tei)))
    let $cached := ($cached-vra, $cached-mods, $cached-tei)   
    let $total := count($cached)
    let $log := util:log("DEBUG", ("##$total): ", $total))
    
    let $available :=
        if ($start + $count gt $total) then
            $total - $start + 1
        else
            $count
    (:let $log := util:log("DEBUG", ("##$available): ", $available)):)
    (:let $log := util:log("DEBUG", ("##$count): ", $count)):)
    return
        (: A single entry is always shown in table view for now :)
        if ($mode eq "ajax" and $count eq 1) 
        then bs:view-table($cached, $stored, $start, $count, $available)
        else
            switch ($mode)
                case "gallery" return
                    bs:view-gallery($mode, $cached, $stored, $start, $count, $available)
                case "grid" return
                    bs:view-gallery($mode, $cached, $stored, $start, $count, $available)
                default return
                    bs:view-table($cached, $stored, $start, $count, $available)
};

session:create(),
let $start := request:get-parameter("start", ())
let $start := xs:int(if ($start) then $start else 1)
let $count := request:get-parameter("count", ())
let $count := xs:int(if ($count) then $count else 10)
return
    bs:retrieve($start, $count)
