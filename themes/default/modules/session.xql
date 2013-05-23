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
    return
        <tr class="pagination-item detail" xmlns="http://www.w3.org/1999/xhtml">
            <td class="pagination-number">{$currentPos}</td>
            <td class="actions-cell">
                <a id="save_{$id}" href="#{$currentPos}" class="save">
                    <img title="{if ($saved) then 'Remove Record from My List' else 'Save Record to My List'}" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                </a>
            </td>
            <td class="magnify detail-type">
            { bs:get-icon($bs:THUMB_SIZE_FOR_DETAIL_VIEW, $item, $currentPos)}
            </td>
            <td class="detail-xml">
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

    return
        <tr class="pagination-item detail" xmlns="http://www.w3.org/1999/xhtml">
            <td class="pagination-number">{$currentPos}</td>
            <td class="actions-cell">
                <a id="save_{$id}" href="#{$currentPos}" class="save">
                    <img title="{if ($saved) then 'Remove Record from My List' else 'Save Record to My List'}" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                </a>
            </td>
            <!--<td class="magnify detail-type">
            { bs:get-icon($bs:THUMB_SIZE_FOR_DETAIL_VIEW, $item, $currentPos)}
            </td>-->
            <td class="detail-xml">
                { bs:toolbar($item, $isWritable, $id) }
                <!--NB: why is this phoney HTML tag used to anchor the Zotero unIPA?-->
                <abbr class="unapi-id" title="{bs:get-item-uri(concat($item, $id-position))}"></abbr>
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
                <abbr class="unapi-id" title="{bs:get-item-uri($item)}"></abbr>
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
            <!--<td class="list-type icon magnify">
            { bs:get-icon($bs:THUMB_SIZE_FOR_GALLERY, $item, $currentPos)}
            </td>-->
            {
            <td class="pagination-toggle">
                <abbr class="unapi-id" title="{bs:get-item-uri(concat($item, $id-position))}"></abbr>
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
                <abbr class="unapi-id" title="{bs:get-item-uri($item)}"></abbr>
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
        case element(tei:bibl) return
            bs:tei-list-view-table($item, $currentPos)
        default return
            bs:plain-list-view-table($item, $currentPos)
};

declare function bs:toolbar($item as element(), $isWritable as xs:boolean, $id as xs:string) {
    let $home := security:get-home-collection-uri($bs:USER)
    (:If there is a MODS @ID, use it; otherwise take a VRA @id.:)
    let $id := $item/@ID
    let $id := 
        if ($id) 
        then $id 
        else $item/vra:work/@id
    return
        <div class="actions-toolbar">
            <a target="_new" href="source.xql?id={$id}&amp;clean=yes">
                <img title="View XML Source of Record" src="theme/images/script_code.png"/>
            </a>
            {
                (: if the item's collection is writable, display edit/delete and move buttons :)
                if ($isWritable) 
                then (
                    (:remove '-compact' from type, used previously.:)
                    <a href="../edit/edit.xq?id={$item/@ID}&amp;collection={util:collection-name($item)}&amp;type={replace($item/mods:extension/*:template, '-compact', '')}">
                        <img title="Edit Record" src="theme/images/page_edit.png"/>
                    </a>
                    ,
                    <a class="remove-resource" href="#{$id}"><img title="Delete Record" src="theme/images/delete.png"/></a>,
                    <a class="move-resource" href="#{$id}"><img title="Move Record" src="theme/images/shape_move_front.png"/></a>
                    )
                else ()
            }
            {
                (: button to add a related item :)
                if ($bs:USER ne "guest") 
                then
                    <a class="add-related" href="#{if ($isWritable) then util:collection-name($item) else $home}#{$item/@ID}">
                        <img title="Create Related Record" src="theme/images/page_add.png"/>
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
declare function bs:retrieve($start as xs:int, $count as xs:int) {
    let $mode := request:get-parameter("mode", "gallery")
    let $cached := session:get-attribute("mods:cached")
    let $stored := session:get-attribute("personal-list")
    let $total := count($cached)
    let $available :=
        if ($start + $count gt $total) then
            $total - $start + 1
        else
            $count
    return
        (: A single entry is always shown in table view for now :)
        if ($mode eq "ajax" and $count eq 1) then
            bs:view-table($cached, $stored, $start, $count, $available)
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
let $start0 := request:get-parameter("start", ())
let $start := xs:int(if ($start0) then $start0 else 1)
let $count0 := request:get-parameter("count", ())
let $count := xs:int(if ($count0) then $count0 else 10)
return
    bs:retrieve($start, $count)