xquery version "1.0";

import module namespace security="http://exist-db.org/mods/security" at "security.xqm";
import module namespace sharing="http://exist-db.org/mods/sharing" at "sharing.xqm";
import module namespace uu="http://exist-db.org/mods/uri-util" at "uri-util.xqm";
declare namespace group = "http://commons/sharing/group";

declare namespace op="http://exist-db.org/xquery/biblio/operations";

declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

declare namespace mods="http://www.loc.gov/mods/v3";

declare variable $HTTP-FORBIDDEN := 403;

(:~
: Creates a collection inside a parent collection
:
: The new collection inherits the owner, group and permissions of the parent
:
: @param $parent the parent collection container
: @param $name the name for the new collection
:)
declare function op:create-collection($parent as xs:string, $name as xs:string) as element(status) {
    
        let $collection := xmldb:create-collection($parent, uu:escape-collection-path($name)),
        
        (: just the owner has full access - to start with :)
        $null := sm:chmod(xs:anyURI($collection), "rwu------"),
        
        (:
        if this collection was created
        inside a different users collection,
        allow the owner of the parent collection access 
        :)
        $null := security:grant-parent-owner-access-if-foreign-collection($collection) return
        
            <status id="created">{uu:unescape-collection-path($collection)}</status>
};

declare function op:move-collection($collection as xs:string, $to-collection as xs:string) as element(status) {
    let $to-collection := uu:escape-collection-path($to-collection) return
        let $null := xmldb:move($collection, $to-collection) return
        
            (:
            if this collection was created
            inside a different users collection,
            allow the owner of the parent collection access 
            :)
            let $null := security:grant-parent-owner-access-if-foreign-collection($to-collection) return
        
                <status id="moved" from="{uu:unescape-collection-path($collection)}">{$to-collection}</status>
};

declare function op:rename-collection($path as xs:string, $name as xs:string) as element(status) {
    let $null := xmldb:rename($path, $name) return
        <status id="renamed" from="{uu:unescape-collection-path($path)}">{$name}</status>
};

declare function op:remove-collection($collection as xs:string) as element(status) {
    let $null := xmldb:remove($collection) return
        <status id="removed">{uu:unescape-collection-path($collection)}</status>
};

(:~
:
: @ resource-id has the format db-document-path#node-id e.g. /db/mods/eXist/exist-articles.xml#1.36
:)
declare function op:remove-resource($resource-id as xs:string) as element(status) {
    
    let $path := substring-before($resource-id, "#")
    let $id := substring-after($resource-id, "#")
    let $doc := doc($path)
    return (
        if ($id eq "1") then
            xmldb:remove(util:collection-name($doc), util:document-name($doc))
        else
            update delete util:node-by-id($doc, $id),
    
        <status id="removed">{$resource-id}</status>
    )
};

(:~
:
: @ resource-id has the format db-document-path#node-id e.g. /db/mods/eXist/exist-articles.xml#1.36
:)
declare function op:move-resource($resource-id as xs:string, $destination-collection as xs:string) as element(status) {
    let $destination-collection := uu:escape-collection-path($destination-collection) return
        let $path := substring-before($resource-id, "#")
        let $id := substring-after($resource-id, "#")
        let $destination-resource-name := replace($path, ".*/", "")
        let $destination-path := concat($destination-collection, "/", $destination-resource-name)
        let $sourceDoc := doc($path)
        return
            if (contains($id, ".")) then
                let $resource := util:node-by-id($sourceDoc, $id)
                let $mods-destination := 
                    if(doc-available($destination-path))then
                        doc($destination-path)/mods:modsCollection
                    else
                        let $mods-collection-doc-path := xmldb:store($destination-collection, $destination-resource-name, <modsCollection xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.loc.gov/mods/v3 ../../webapp/WEB-INF/entities/mods-3-3.xsd"/>) return
                            let $null := security:apply-parent-collection-permissions($mods-collection-doc-path) return
                                doc($mods-collection-doc-path)/mods:modsCollection
                return
                (
                    update insert util:node-by-id(doc($path), $id) into $mods-destination,
                    update delete util:node-by-id(doc($path), $id),
                    
                    <status id="moved" from="{$resource-id}">{$destination-path}</status>
                )
            else
                let $moved := xmldb:move(util:collection-name($sourceDoc), $destination-collection, util:document-name($sourceDoc)) return
                    let $null := security:apply-parent-collection-permissions(fn:document-uri(fn:root($sourceDoc))) return
                
                        <status id="moved" from="{$resource-id}">{$destination-path}</status>
};

declare function op:set-ace-writeable($collection as xs:anyURI, $id as xs:int, $is-writeable as xs:boolean) as element(status) {
  
    if(sharing:set-collection-ace-writeable($collection, $id, $is-writeable))then  
        <status id="ace">updated</status>
    else(
        response:set-status-code($HTTP-FORBIDDEN),
        <status id="ace">Permission Denied</status>
    )
};

declare function op:remove-ace($collection as xs:anyURI, $id as xs:int) as element(status) {
    
    if(sharing:remove-collection-ace($collection, $id))then
        <status id="ace">removed</status>
    else(
        response:set-status-code($HTTP-FORBIDDEN),
        <status id="ace">Permission Denied</status>
    )
};

declare function op:add-user-ace($collection as xs:anyURI, $username as xs:string) as element(status) {

    if(sharing:add-collection-user-ace($collection, $username))then
        <status id="ace">added</status>
    else (
        response:set-status-code($HTTP-FORBIDDEN),
        <status id="ace">Permission Denied</status>
    )
};

declare function op:add-group-ace($collection as xs:anyURI, $groupname as xs:string) as element(status) {
    
    if(sharing:add-collection-group-ace($collection, $groupname))then
        <status id="ace">added</status>
    else (
        response:set-status-code($HTTP-FORBIDDEN),
        <status id="ace">Permission Denied</status>
    )
};

declare function op:is-valid-user-for-share($username as xs:string) as element(status) {
    if(sharing:is-valid-user-for-share($username))then
        <status id="user">valid</status>
    else(
        response:set-status-code($HTTP-FORBIDDEN),
        <status id="user">invalid</status>
    )
};

declare function op:get-move-folder-list($collection as xs:anyURI) as element(select) {
    <select>{
        for $collection-path in (security:get-home-collection-uri(security:get-user-credential-from-session()[1]), sharing:get-shared-collection-roots(true())) return
            if($collection-path ne $collection)then
            (
                <option value="{uu:unescape-collection-path($collection-path)}">{uu:unescape-collection-path($collection-path)}</option>
            )
            else()
    }</select>
};

declare function op:get-move-resource-list($collection as xs:anyURI) as element(select) {
    op:get-move-folder-list($collection)
};

declare function op:is-valid-group-for-share($groupname as xs:string) as element(status) {
    if(sharing:is-valid-group-for-share($groupname))then
        <status id="group">valid</status>
    else(
        response:set-status-code($HTTP-FORBIDDEN),
        <status id="group">invalid</status>
    )
};

declare function op:unknown-action($action as xs:string) {
        response:set-status-code($HTTP-FORBIDDEN),
        <p>Unknown action: {$action}.</p>
};

let $action := request:get-parameter("action", ()),
$collection := uu:escape-collection-path(request:get-parameter("collection", ()))
return
    if($action eq "create-collection")then
        op:create-collection($collection, request:get-parameter("name",()))
    else if($action eq "move-collection")then
        op:move-collection($collection, request:get-parameter("path",()))
    else if($action eq "rename-collection")then
        op:rename-collection($collection, request:get-parameter("name",()))
    else if($action eq "remove-collection")then
        op:remove-collection($collection)
    else if($action eq "remove-resource")then
        op:remove-resource(request:get-parameter("resource",()))
    else if($action eq "move-resource")then
        op:move-resource(request:get-parameter("resource",()), request:get-parameter("path",()))
    else if($action eq "set-ace-writeable")then
        op:set-ace-writeable(xs:anyURI($collection), xs:int(request:get-parameter("id",())), xs:boolean(request:get-parameter("is-writeable", false())))
    else if($action eq "remove-ace")then
        op:remove-ace(xs:anyURI($collection), xs:int(request:get-parameter("id",())))
    else if($action eq "add-user-ace")then
        op:add-user-ace(xs:anyURI($collection), request:get-parameter("username",()))
    else if($action eq "is-valid-user-for-share")then
        op:is-valid-user-for-share(request:get-parameter("username",()))
    else if($action eq "add-group-ace")then
        op:add-group-ace(xs:anyURI($collection), request:get-parameter("groupname",()))
    else if($action eq "is-valid-group-for-share")then
        op:is-valid-group-for-share(request:get-parameter("groupname",()))
    else if($action eq "get-move-folder-list")then
        op:get-move-folder-list($collection)
     else if($action eq "get-move-resource-list")then
        op:get-move-resource-list($collection)
    else
        op:unknown-action($action)