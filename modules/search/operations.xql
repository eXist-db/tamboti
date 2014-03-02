xquery version "1.0";

import module namespace security="http://exist-db.org/mods/security" at "security.xqm";
import module namespace sharing="http://exist-db.org/mods/sharing" at "sharing.xqm";
import module namespace config="http://exist-db.org/mods/config" at "../config.xqm";

declare namespace group = "http://commons/sharing/group";
declare namespace op="http://exist-db.org/xquery/biblio/operations";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

declare namespace mods="http://www.loc.gov/mods/v3";
declare namespace vra="http://www.vraweb.org/vracore4.htm";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace functx="http://www.functx.com"; 

declare variable $HTTP-FORBIDDEN := 403;

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

(:TODO: if collection names use higher Unicode characters, 
the buttons do not show up (except Delete Folder).:)

(:~
: Creates a collection inside a parent collection
:
: The new collection inherits the owner, group and permissions of the parent
:
: @param $parent-collection-uri the parent collection uri
: @param $new-collection-name the name for the new collection
:)
(:NB: creation does not take place if the new name is already taken.:)
(:TODO: notify user if the new name is already taken.:)
declare function op:create-collection($parent-collection-uri as xs:string, $new-collection-name as xs:string) as element(status) {

    let $new-collection := xmldb:create-collection(xmldb:encode-uri($parent-collection-uri), xmldb:encode-uri($new-collection-name))
    
    (:just the owner has write access to start with:)
    let $null := sm:chmod(xs:anyURI($new-collection), "rwxr-xr-x")
    
    (:if this collection was created inside a different user's collection,
    allow the owner of the parent collection access:)
    let $null := security:grant-parent-owner-access-if-foreign-collection($new-collection)
    
    return
		<status id="created">{xmldb:decode-uri($new-collection)}</status>
};

(:TODO: Perform search for contents of collection after it has been moved.:)
(:TODO: List is wrong: a collection cannot be moved into itself, nor can it be moved into a subfolder.:)
declare function op:move-collection($collection-to-move as xs:string, $new-parent-collection as xs:string) as element(status) {
    
    let $collection-to-move := xmldb:encode-uri($collection-to-move)
    let $new-parent-collection := xmldb:encode-uri($new-parent-collection)

    return
        let $null := xmldb:move($collection-to-move, $new-parent-collection) return
        
            (:if this collection was created inside a different user's collection,
            allow the owner of the parent collection access:)
            let $null := security:grant-parent-owner-access-if-foreign-collection($new-parent-collection) 
            
            return
                <status id="moved" from="{xmldb:decode-uri($collection-to-move)}">{xmldb:decode-uri($new-parent-collection)}</status>
};

(:NB: name change does not take place if the new name is already taken.:)
(:TODO: notify user if the new name is already taken.:)
declare function op:rename-collection($collection-uri as xs:string, $new-collection-name as xs:string) as element(status) {

    let $null := xmldb:rename(xmldb:encode-uri($collection-uri), xmldb:encode-uri($new-collection-name)) 
    return
        <status id="renamed" from="{xmldb:decode-uri($collection-uri)}">{xmldb:decode-uri($new-collection-name)}</status>
};

(:TODO: After removal, perform search in Home collection:)
(:TODO: Implement for VRA records:)
declare function op:remove-collection($collection as xs:string) as element(status) {

    (:Only allow deletion of a collection if none of the MODS records in it are referred to in xlinks outside the collection itself.:)
    (:Get the ids of the records in the collection that the user wants to delete.:)
    let $collection := xmldb:encode-uri($collection)
    let $collection-ids := collection($collection)//@ID
    (:Get the ids of the records that are linked to the records in the collection that the user wants to delete.:)
    let $xlinked-rec-ids :=
        string-join(
        for $collection-id in $collection-ids
            let $xlink := concat('#', $collection-id)
            let $xlink-recs := collection($config:mods-root-minus-temp)//mods:relatedItem[@xlink:href eq $xlink]/ancestor::mods:mods/@ID
            return
                (:It is OK to delete a record using an ID as an xlink if the record is inside the folder to be deleted.:)
                if (not($xlink-recs = $collection-ids))
                then $xlink-recs
                else ''
                (:This should return '' for each iteration for deletion to proceed.:)
                )
    let $null := 
        (:If $xlinked-rec-ids is not empty, do not delete.:)
        if ($xlinked-rec-ids)
        then ()
        else xmldb:remove($collection) 
    return
        if ($xlinked-rec-ids)
        then <status id="removed">{xmldb:decode-uri($collection)}</status>
        else <status id="not-removed">{xmldb:decode-uri($collection)}</status>
};

(:~
:
: @resource-id is the UUID of the MODS or VRA record
TODO: Perform search for contents of the collection that the removed resource belonged to.
:)
declare function op:remove-resource($resource-id as xs:string) as element(status)* {
    let $mods-record := collection($config:mods-root-minus-temp)//mods:mods[@ID eq $resource-id]
    let $xlink-to-mods-record := concat('#', $resource-id)
    (:since xlinks are also inserted manually, check also for cases when the pound sign has been forgotten:)
    let $xlinked-mods-records := collection($config:mods-root-minus-temp)//mods:relatedItem[@xlink:href = ($xlink-to-mods-record, $resource-id)]
    
    let $vra-work-record := collection($config:mods-root-minus-temp)//vra:vra/vra:work[@id eq $resource-id]
    (:NB: we assume that @relids (plural) can hold several values:)
    let $vra-image-records := collection($config:mods-root-minus-temp)//vra:vra[vra:image/vra:relationSet/vra:relation[contains(@relids, $resource-id)]]
    (:NB: we assume that all image files are in the same collection as their metadata 
    and that all image records belonging to a work record are in the same collection:)
    let $vra-image-record-collection := util:collection-name($vra-image-records[1])
    let $vra-binary-file-names := $vra-image-records/vra:image/@href    
    let $vra-records := ($vra-work-record, $vra-image-records)
    
    let $records := 
        if ($mods-record) 
        then $mods-record 
        else $vra-records 
    
    for $record in $records 
    return
    (
        (:do not remove records which erroneously have the same ID:)
        (:TODO: inform user that this is the case:)
        if (count($record) eq 1)
        then
            (:do not remove a record which is xlinked to from one or more other records:)
            (:TODO: inform user that this is the case:)
            if (count($xlinked-mods-records) eq 0) 
            then xmldb:remove(util:collection-name($record), util:document-name($record))
            else ()
        else ()
        ,
        if (count($vra-binary-file-names) gt 0) 
        then
            for $vra-binary-name in $vra-binary-file-names
            return
                (:NB: since this iterates inside another iteration, files are attempted deleted which have been deleted already, 
                causing the script to halt. However, the existence of the file to be deleted should first be checked, 
                in order to prevent the function from halting in case the file does not exist.:)
                if (util:binary-doc-available(concat($vra-image-record-collection, '/', $vra-binary-name))) 
                then xmldb:remove($vra-image-record-collection, $vra-binary-name)
                else ()
        else ()
        ,
        response:set-status-code($HTTP-FORBIDDEN),
        <p>Unknown action: Movee.</p>
    )
};



(:~
: @ resource-id has the format db-document-path#node-id e.g. /db/mods/eXist/exist-articles.xml#1.36
TODO: Perform search for record after it has been moved. 
:)
declare function op:move-resource($resource-id as xs:string, $destination-collection as xs:string) as element(status) {

    let $mods-record := collection($config:mods-root-minus-temp)//mods:mods[@ID eq $resource-id]
    let $mods-record-collection := base-uri($mods-record)
    let $mods-record-collection := functx:substring-before-last($mods-record-collection, '/')
    let $mods-record-collection := xmldb:encode-uri($mods-record-collection)
    let $destination-collection := xmldb:encode-uri($destination-collection) 
    let $id := 
        if (contains($resource-id, "#"))
        then substring-after($resource-id, "#")
        else $resource-id
    let $path := 
        if (contains($destination-collection, "#"))
        then substring-before($destination-collection, "#")
        else $destination-collection
    let $destination-resource-name := concat($id, ".xml")
    let $destination-path := concat($destination-collection, "/", $destination-resource-name)
    let $sourceDoc := doc($destination-path)
    return
        (:if (contains($id, ".")) 
        then
            let $resource := util:node-by-id($sourceDoc, $id)
            let $mods-destination := 
                if (doc-available($destination-path))
                then
                    doc($destination-path)/mods:modsCollection
                else
                    let $mods-collection-doc-path := xmldb:store($destination-collection, $destination-resource-name, <modsCollection xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.loc.gov/mods/v3 ../../webapp/WEB-INF/entities/mods-3-3.xsd"/>) 
                    return
                        let $null := security:apply-parent-collection-permissions($mods-collection-doc-path) 
                        return
                            doc($mods-collection-doc-path)/mods:modsCollection
            return
            (
                update insert util:node-by-id(doc($path), $id) into $mods-destination,
                update delete util:node-by-id(doc($path), $id),
                
                <status id="moved" from="{$resource-id}">{$destination-path}</status>
            )
        else:)
            let $moved := xmldb:move($mods-record-collection, $destination-collection, $destination-resource-name) 
            return
                let $null := security:apply-parent-collection-permissions($destination-path) 
                return
                    <status id="moved" from="{$resource-id}">{$destination-path}</status>
};

declare function op:set-ace-writeable($collection as xs:anyURI, $id as xs:int, $is-writeable as xs:boolean) as element(status) {
  
    if(exists(sharing:set-collection-ace-writeable($collection, $id, $is-writeable)))then  
        <status id="ace">updated</status>
    else(
        response:set-status-code($HTTP-FORBIDDEN),
        <status id="ace">Permission Denied</status>
    )
};

declare function op:remove-ace($collection as xs:anyURI, $id as xs:int) as element(status) {
  
    if(exists(sharing:remove-collection-ace($collection, $id)))then
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

declare function op:get-child-collection-paths($start-collection as xs:anyURI) {
    for $child-collection in xmldb:get-child-collections($start-collection)
        return
            (concat($start-collection, '/', $child-collection), 
            op:get-child-collection-paths(concat($start-collection, '/', $child-collection) cast as xs:anyURI))
};

(:TODO: A collection cannot be moved into itself, nor can it be moved into a subfolder, 
so it is necessary to check against the path of collection that is to be moved.:)
declare function op:get-move-folder-list($chosen-collection as xs:anyURI) as element(select) {
    <select>{
        (:the user can move records to their home folder and to folders that are shared with the user:)
        let $user := security:get-user-credential-from-session()[1]
        let $available-collection-paths := security:get-home-collection-uri(security:get-user-credential-from-session()[1])
        let $move-folder-list :=
        (:TODO: leave out the folder that the user has marked, since you cannot move something to itself:)
        (:TODO: leave out descendant folders, since you cannot move a folder into a descendant of itself:)
        for $available-collection-path in $available-collection-paths 
        (:NB: Adding the home folder and shared folder here is not ideal, since it gets repeated for each descendant.:)
        return ($available-collection-paths, op:get-child-collection-paths($available-collection-path), sharing:get-shared-collection-roots(true()))
            for $path in distinct-values($move-folder-list)
            let $display-path := substring-after($path, '/db/')
            let $display-path := replace($path, concat('users/', $user), 'Home')
            order by $display-path
            return
                <option value="{xmldb:decode-uri($path)}">{xmldb:decode-uri($display-path)}</option>
    }</select>
};

(:TODO: This builds on the idea that you can move a resource to anywhere you can move a collection,
but this is wrong, since you can move a resource into a descendant collection, whereas this is not possible for a collection.:)
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

let $action := request:get-parameter("action", ())
let $collection := request:get-parameter("collection", ())

return
    if ($action eq "create-collection") then
        op:create-collection($collection, request:get-parameter("name",()))
    else if ($action eq "move-collection") then
        (:op:move-collection($collection, request:get-parameter("path",())):)
        op:move-collection($collection, request:get-parameter("path",()))
    else if ($action eq "rename-collection") then
        op:rename-collection($collection, request:get-parameter("name",()))
    else if ($action eq "remove-collection") then
        op:remove-collection($collection)
    else if ($action eq "remove-resource") then
        op:remove-resource(request:get-parameter("resource",()))
    else if ($action eq "move-resource") then
        op:move-resource(request:get-parameter("resource",()), request:get-parameter("path",()))
    else if ($action eq "set-ace-writeable") then
        op:set-ace-writeable(xs:anyURI($collection), xs:int(request:get-parameter("id",())), xs:boolean(request:get-parameter("is-writeable", false())))
    else if ($action eq "remove-ace") then
        op:remove-ace(xs:anyURI($collection), xs:int(request:get-parameter("id",())))
    else if ($action eq "add-user-ace") then
        op:add-user-ace(xs:anyURI($collection), request:get-parameter("username",()))
    else if ($action eq "is-valid-user-for-share") then
        op:is-valid-user-for-share(request:get-parameter("username",()))
    else if ($action eq "add-group-ace") then
        op:add-group-ace(xs:anyURI($collection), request:get-parameter("groupname",()))
    else if ($action eq "is-valid-group-for-share") then
        op:is-valid-group-for-share(request:get-parameter("groupname",()))
    else if ($action eq "get-move-folder-list") then
        op:get-move-folder-list($collection)
     else if ($action eq "get-move-resource-list") then
        op:get-move-resource-list($collection)
     else
        op:unknown-action($action)
