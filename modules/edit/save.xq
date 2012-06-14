xquery version "1.0";

(: XQuery script to save a new MODS record from an incoming HTTP POST :)

import module namespace request = "http://exist-db.org/xquery/request";
import module namespace sm = "http://exist-db.org/xquery/securitymanager";
import module namespace xmldb = "http://exist-db.org/xquery/xmldb";

import module namespace config = "http://exist-db.org/mods/config" at "../config.xqm";
import module namespace security = "http://exist-db.org/mods/security" at "../search/security.xqm"; (: TODO move security module up one level :)
import module namespace uu = "http://exist-db.org/mods/uri-util" at "../search/uri-util.xqm";

declare namespace save = "http:/exist-db.org/xquery/mods/save";
declare namespace clean = "http:/exist-db.org/xquery/mods/cleanup";
declare namespace xf = "http://www.w3.org/2002/xforms";
declare namespace xforms = "http://www.w3.org/2002/xforms";
declare namespace ev = "http://www.w3.org/2001/xml-events";
declare namespace mods = "http://www.loc.gov/mods/v3";
declare namespace e = "http://www.asia-europe.uni-heidelberg.de/";

declare function clean:clean-namespaces($node as node()) {
    typeswitch ($node)
        case element() 
            return
                if (namespace-uri($node) eq "http://www.loc.gov/mods/v3") 
                then element { QName("http://www.loc.gov/mods/v3", local-name($node)) } {
                        $node/@*, 
                        for $child in $node/node() 
                        return clean:clean-namespaces($child)
                    }
                else
                    $node
        default 
            return $node
};

declare function xf:do-updates($item, $doc) {
    (: This first checks to see if we have a titleInfo in the saved document.  
    If we do then it first deletes the titleInfo in the saved document.
    Then it goes through each titleInfo in the incoming record and inserts it in the saved document. 
    If name (the "next" element in the "canonical" order of MODS elements) occurs in the saved document, titleInfo is inserted before name, maintaining order.
    If name does not occur, titleInfo is inserted at the default position, i.e. at the end of the saved document.
    The canonical order is: titleInfo, name, originInfo, part, physicalDescription, targetAudience, typeOfResource, genre, subject, classification, abstract, tableOfContents, note, relatedItem, identifier, location, accessCondition, language, recordInfo, extension. 
    This is then repeated for the remaining elements, in the canonical order.:)
    
    if ($item/mods:titleInfo)
    then
        (
        update delete $doc/mods:titleInfo
        ,
        if ($doc/mods:name)
        then update insert $item/mods:titleInfo preceding $doc/mods:name[1]
        else update insert $item/mods:titleInfo into $doc
        )
    else ()
    ,
    
    if ($item/mods:name)
    then
        (
        update delete $doc/mods:name
        ,
        if ($doc/mods:originInfo)
        then update insert $item/mods:name preceding $doc/mods:originInfo[1]
        else update insert $item/mods:name into $doc
        )
      else ()
    ,
      
    if ($item/mods:originInfo)
    then
        (
        update delete $doc/mods:originInfo
        ,
        if ($doc/mods:part)
        then update insert $item/mods:originInfo preceding $doc/mods:part[1]
        else update insert $item/mods:originInfo into $doc
        )
      else ()
    ,
    
    if ($item/mods:part)
    then
        (
        update delete $doc/mods:part
        ,
        if ($doc/mods:physicalDescription)
        then update insert $item/mods:part preceding $doc/mods:physicalDescription[1]
        else update insert $item/mods:part into $doc
        )
      else ()
    ,
    
    if ($item/mods:physicalDescription)
    then
        (
        update delete $doc/mods:physicalDescription
        ,
        if ($doc/mods:targetAudience)
        then update insert $item/mods:physicalDescription preceding $doc/mods:targetAudience[1]
        else update insert $item/mods:physicalDescription into $doc
        )
    else ()
    ,
    
    if ($item/mods:targetAudience)
    then
        (
        update delete $doc/mods:targetAudience
        ,
        if ($doc/mods:typeOfResource)
        then update insert $item/mods:targetAudience preceding $doc/mods:typeOfResource[1]
        else update insert $item/mods:targetAudience into $doc
        )
    else ()
    ,      
    
    if ($item/mods:typeOfResource)
    then
        (
        update delete $doc/mods:typeOfResource,
        if ($doc/mods:genre)
        then update insert $item/mods:typeOfResource preceding $doc/mods:genre[1]
        else update insert $item/mods:typeOfResource into $doc
        )
    else ()
    ,
    
    if ($item/mods:genre)
    then
        (
        update delete $doc/mods:genre,
        if ($doc/mods:subject)
        then update insert $item/mods:genre preceding $doc/mods:subject[1]
        else update insert $item/mods:genre into $doc
        )
    else ()
    ,
    
    if ($item/mods:subject)
    then
        (
        update delete $doc/mods:subject
        ,
        if ($doc/mods:classification)
        then update insert $item/mods:subject preceding $doc/mods:classification[1]
        else
        update insert $item/mods:subject into $doc
        )
    else ()
    ,      
    
    if ($item/mods:classification)
    then
        (
        update delete $doc/mods:classification
        ,
        if ($doc/mods:abstract)
        then update insert $item/mods:classification preceding $doc/mods:abstract[1]
        else update insert $item/mods:classification into $doc
        )
    else ()
    ,     
    
    if ($item/mods:abstract)
    then
        (
        update delete $doc/mods:abstract
        ,
        if ($doc/mods:tableOfContents)
        then update insert $item/mods:abstract preceding $doc/mods:tableOfContents[1]
        else update insert $item/mods:abstract into $doc
        )
    else ()
    ,
    
    if ($item/mods:tableOfContents)
    then
        (
        update delete $doc/mods:tableOfContents
        ,
        if ($doc/mods:note)
        then update insert $item/mods:tableOfContents preceding $doc/mods:note[1]
        else update insert $item/mods:tableOfContents into $doc
        )
    else ()
    ,
      
    if ($item/mods:note)
    then
        (
        update delete $doc/mods:note
        ,
        if ($doc/mods:relatedItem)
        then update insert $item/mods:note preceding $doc/mods:relatedItem[1]
        else update insert $item/mods:note into $doc
        )
    else ()
    ,
      
    if ($item/mods:relatedItem)
    then
        (
        update delete $doc/mods:relatedItem
        ,
        if ($doc/mods:identifier)
        then update insert $item/mods:relatedItem preceding $doc/mods:identifier[1]
        else update insert $item/mods:relatedItem into $doc
        )
    else ()
    ,
    
    if ($item/mods:identifier)
    then
        (
        update delete $doc/mods:identifier
        ,
        if ($doc/mods:location)
        then update insert $item/mods:identifier preceding $doc/mods:location[1]
        else update insert $item/mods:identifier into $doc
        )
    else ()
    ,
    
    if ($item/mods:location)
    then
        (
        update delete $doc/mods:location
        ,
        if ($doc/mods:accessCondition)
        then update insert $item/mods:location preceding $doc/mods:accessCondition[1] 
        else update insert $item/mods:location into $doc
        )
    else ()
    ,

    if ($item/mods:accessCondition)
    then
        (
        update delete $doc/mods:accessCondition
        ,
        if ($doc/mods:language)
        then update insert $item/mods:accessCondition preceding $doc/mods:language[1] 
        else update insert $item/mods:accessCondition into $doc
        )
    else ()
    ,

    if ($item/mods:language)
    then
        (
        update delete $doc/mods:language
        ,
        if ($doc/mods:recordInfo)
        then update insert $item/mods:language preceding $doc/mods:recordInfo[1]
        else update insert $item/mods:language into $doc
        )
    else ()
    ,
    
    if ($item/mods:recordInfo)
    then
        (
        update delete $doc/mods:recordInfo
        ,
        if ($doc/mods:extension)
        then update insert $item/mods:recordInfo preceding $doc/mods:extension[1]
        else update insert $item/mods:recordInfo into $doc
        )
    else ()
    ,
    
    if ($item/mods:extension)
    then
        (
        update delete $doc/mods:extension
        ,
        update insert $item/mods:extension into $doc
        )
    else ()
};

(: Look for the collection containing the record with the uuid in the users collection and in the commons collection.
This means that the record temporarily in the temp collection is not found. :)
declare function save:find-live-collection-containing-uuid($uuid as xs:string) as xs:string? {
    let $live-record := collection($config:users-collection, $config:mods-commons)/mods:mods[@ID = $uuid] 
    return
        if (not(empty($live-record))) 
        then replace(document-uri(root($live-record)), "(.*)/.*", "$1")
        else ()
};

(: This is where the form "POSTS" documents to this XQuery using the POST method of a submission :)
let $item := clean:clean-namespaces(request:get-data()/element())
(: This service takes an incoming POST and saves the appropriate records :)
(: Note that the incoming @ID is required :)

let $collection := request:get-parameter('collection', ())

(:The default action is save, which means that the recrod is saved in temp each time a tab is clicked.:)
let $action := request:get-parameter('action', 'save')
let $incoming-id := $item/@ID
(: If we do not have an ID, then throw an error. :) 
return
    if (string-length($incoming-id) eq 0)
    then
        <error>
            <message class="warning">ERROR! Attempted to save a record with no ID specified.</message>
        </error>
    else
        (: If there is an ID, we are doing an update to an existing file (unless the action is cancel). :)
        let $file-to-update := concat($incoming-id, '.xml')
        (: This always resolves to /db/resources/temp/ :)
        let $file-path := concat(xmldb:encode-uri($collection), '/', $file-to-update)
        (:This is the document in temp to be updated during save and the document to be saved in the target collection when the editor is being closed.:)
        let $doc := doc($file-path)/mods:mods
        (: If the incoming has any part then we update it in the document with do-updates.
        This has the side effect of adding the mods namespace prefix in the data files. 
        To remedy this, clean:clean-namespaces() is applied to the record. :)
        (: TODO: figure out some way to pass the element name to an XQuery function and then do an eval on the update :)
        let $updates := 
            if ($action eq 'cancel')
            (: Remove the document from temp. :)
            then xmldb:remove($collection, $file-to-update)
            else
                if ($action eq 'close')
                (: If the user terminates editing. :)
                then
                    (:Get the document in temp.:)
                    let $temp-file-path := concat(xmldb:encode-uri($config:mods-temp-collection), '/', $file-to-update)
                    let $doc := doc($temp-file-path)/mods:mods
                    (:Get the target collection. If it's an edit to an existing document, we can find its location by means of its uuid.
                    If it is a new record, the target collection can be captured as the collection parameter passed in the URL. :)
                    let $target-collection := save:find-live-collection-containing-uuid($incoming-id)
                    let $new-target-collection := uu:escape-collection-path(request:get-parameter("collection", ""))
                    let $target-collection :=
                            if ($target-collection)
                            then $target-collection
                            else $new-target-collection
                    return
                    (
                        (:Update the document in temp with $item.:)
                        xf:do-updates($item, $doc),
                        (:Move it from temp to target collection.:)
                        xmldb:move($config:mods-temp-collection, $target-collection, $file-to-update),
                        (:Set the same permissions on the moved file that the parent collection has.:)
                        security:apply-parent-collection-permissions(xs:anyURI(concat($target-collection, "/", $file-to-update)))
                    )
                (:If action is 'save' (the default action):)
                (:$item is the old document, $doc the new one:)
                else
                    xf:do-updates($item, $doc)    
        return ()