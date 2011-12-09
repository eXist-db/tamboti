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

import module namespace mods="http://www.loc.gov/mods/v3" at "retrieve-mods.xql";
import module namespace jquery="http://exist-db.org/xquery/jquery" at "resource:org/exist/xquery/lib/jquery.xql";
import module namespace security="http://exist-db.org/mods/security" at "security.xqm";
import module namespace sharing="http://exist-db.org/mods/sharing" at "sharing.xqm";
import module namespace clean="http:/exist-db.org/xquery/mods/cleanup" at "cleanup.xql";
import module namespace kwic="http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";
    
declare namespace bs="http://exist-db.org/xquery/biblio/session";
declare namespace functx = "http://www.functx.com";

declare option exist:serialize "method=xhtml media-type=application/xhtml+xml enforce-xhtml=yes";

declare variable $bs:USER := security:get-user-credential-from-session()[1];

declare variable $bs:THUMB_SIZE_GRID := 64;
declare variable $bs:THUMB_SIZE_GALLERY := 128;
declare variable $bs:THUMB_SIZE_DETAIL := 256;

declare function functx:capitalize-first($arg as xs:string?) as xs:string? {       
   concat(upper-case(substring($arg,1,1)),
             substring($arg,2))
};

declare function functx:replace-first( $arg as xs:string?, $pattern as xs:string, $replacement as xs:string )  as xs:string {       
   replace($arg, concat('(^.*?)', $pattern),
             concat('$1',$replacement))
 } ;

declare function bs:collection-is-writable($collection as xs:string) {
    (:if ($collection eq $sharing:groups-collection) then:)
        true ()(:false()
    else
        security:can-write-collection($bs:USER, $collection):)
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
    let $thumbSize := if ($mode eq "gallery") then $bs:THUMB_SIZE_GALLERY else $bs:THUMB_SIZE_GRID
    let $title := mods:get-short-title($item)
    return
        <li class="pagination-item {$mode}" xmlns="http://www.w3.org/1999/xhtml">
            <span class="pagination-number">{ $currentPos }</span>
            <div class="icon pagination-toggle" title="{$title}">
                <img class="magnify icon-magnifier" src="theme/images/search.png" title="Click for full screen image"/>
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

declare function bs:detail-view-table($item as element(mods:mods), $currentPos as xs:int) {
    let $isWritable := bs:collection-is-writable(util:collection-name($item))
    let $id := concat(document-uri(root($item)), '#', util:node-id($item))
    let $stored := session:get-attribute("mods-personal-list")
    let $saved := exists($stored//*[@id = $id])
    return
        <tr class="pagination-item detail" xmlns="http://www.w3.org/1999/xhtml">
            <td class="pagination-number">{$currentPos}</td>
            <td class="actions-cell">
                <a id="save_{$id}" href="#{$currentPos}" class="save">
                    <img title="Save Record to My List" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                </a>
            </td>
            <td class="magnify detail-type">
            { bs:get-icon($bs:THUMB_SIZE_DETAIL, $item, $currentPos)}
            </td>
            <td class="detail-xml">
                { bs:toolbar($item, $isWritable, $id) }
                <abbr class="unapi-id" title="{bs:get-item-uri($item/@ID)}"></abbr>
                {
                    let $collection := util:collection-name($item)
                    let $collection-short := functx:replace-first($collection, '/db/', '')
                    let $clean := clean:cleanup($item)
                    return
                        mods:format-detail-view(string($currentPos), $clean, $collection-short)
                        (: What is $currentPos used for? :)
                }
            </td>
        </tr>
};

declare function bs:mods-list-view-table($item as node(), $currentPos as xs:int) {
    let $id := concat(document-uri(root($item)), '#', util:node-id($item))
    let $stored := session:get-attribute("mods-personal-list")
    let $saved := exists($stored//*[@id = $id])
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
            <td class="list-type icon magnify">
            { bs:get-icon($bs:THUMB_SIZE_GALLERY, $item, $currentPos)}
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
                        mods:format-list-view(string($currentPos), $clean, $collection-short)
                        (: Originally $item was passed to mods:format-list-view() - was there a reason for that? Performance? :)
                }
                </a>
            </td>
            }
        </tr>
};

declare function bs:plain-list-view-table($item as node(), $currentPos as xs:int) {
    let $kwic := kwic:summarize($item/field[1], <config xmlns="" width="40"/>)
    let $id := concat(document-uri(root($item)), '#', util:node-id($item))
    let $stored := session:get-attribute("mods-personal-list")
    let $saved := exists($stored//*[@id = $id])
    let $titleField := ft:get-field($item/@uri, "Title")
    let $title := if ($titleField) then $titleField else replace($item/@uri, "^.*/([^/]+)$", "$1")
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
                { bs:get-icon($bs:THUMB_SIZE_GALLERY, $item, $currentPos)}
                </a>
            </td>
            {
            <td class="pagination-toggle">
                <h3>{$title}</h3>
                { $kwic }
            </td>
            }
        </tr>
};

declare function bs:list-view-table($item as node(), $currentPos as xs:int) {
    typeswitch ($item)
        case element(mods:mods) return
            bs:mods-list-view-table($item, $currentPos)
        default return
            bs:plain-list-view-table($item, $currentPos)
};

declare function bs:toolbar($item as element(mods:mods), $isWritable as xs:boolean, $id as xs:string) {
    let $home := security:get-home-collection-uri($bs:USER)
    return
        <div class="actions-toolbar">
            <a target="_new" href="source.xql?id={$item/@ID}&amp;clean=yes">
                <img title="View XML Source of Record" src="theme/images/script_code.png"/>
            </a>
            {
                (: if the item's collection is writable, display edit/delete and move buttons :)
                if ($isWritable) 
                then (
                    <a href="../edit/edit.xq?id={$item/@ID}&amp;collection={util:collection-name($item)}&amp;type={$item/mods:extension/*:template}">
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
                        <img title="Create Related Item" src="theme/images/page_add.png"/>
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
        ( 
            $item/mods:location/mods:url[@access="preview"]/string(), 
            $item/mods:location/mods:url[@displayLabel="Path to Folder"] 
        )[1]
    let $title := $item/mods:typeOfResource/string()
    let $title := 
        if ($title)
        then functx:capitalize-first($title)
        else
            if (in-scope-prefixes($item) = 'xml')
            then 'Unknown Type'
            else 'Extracted Text'
    return
        if (exists($image-url)) 
        then
            let $image-path := concat(util:collection-name($item), "/", xmldb:encode($image-url))
            return
                if (collection($image-path)) 
                then bs:get-icon-from-folder($size, $image-path)
                else
                    let $imgLink := concat(substring-after(util:collection-name($item), "/db"), "/", $image-url)
                    return
                        <img title="{$title}" src="images/{$imgLink}?s={$size}"/>
        else
            let $type := $item/mods:typeOfResource[1]/string()           
            let $type := 
                (: If there is a typeOfResource, render the icon for it. :)
                if ($type)
                then replace(replace($type,' ','_'),',','')
                else
                    (: If there is no typeOfResource, but the resource is XML, render the default icon for it. :)
                    if (in-scope-prefixes($item) = 'xml')
                    then 'shape_square'
                    (: Otherwise it is non-XML contents extracted from a document by tika. This could be a PDF, a Word document, etc. :) 
                    else 'text-x-changelog'
            return 
                <img title="{$title}" src="theme/images/{$type}.png"/>
};

declare function bs:view-table($cached as item()*, $stored as item()*, $start as xs:int, 
    $count as xs:int, $available as xs:int) {
    <table xmlns="http://www.w3.org/1999/xhtml">
    {
        for $item at $pos in subsequence($cached, $start, $available)
        let $currentPos := $start + $pos - 1
        return
            if ($count eq 1 and $item instance of element(mods:mods)) then
                bs:detail-view-table($item, $currentPos)
            else
                bs:list-view-table($item, $currentPos)
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
    let $stored := session:get-attribute("mods-personal-list")
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