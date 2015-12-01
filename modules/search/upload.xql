xquery version "3.0";
(: author dulip withanage 
:)

import module namespace config="http://exist-db.org/mods/config" at "../config.xqm";
import module namespace security="http://exist-db.org/mods/security" at "security.xqm";

declare namespace upload = "http://exist-db.org/eXide/upload";
declare namespace functx = "http://www.functx.com";
declare namespace vra="http://www.vraweb.org/vracore4.htm";
declare namespace mods="http://www.loc.gov/mods/v3";

declare variable $root-data-collection :='/db/resources/';
declare variable $message := 'The file has been successfully uploaded';
declare variable $image-collection-name := 'VRA_images';

declare function functx:escape-for-regex($arg as xs:string?)
 as xs:string
 {
     replace($arg, '(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))', '\\$1')
 };
 
declare function functx:substring-after-last($arg as xs:string?, $delim as xs:string)
as xs:string
{
    replace($arg, concat('^.*', functx:escape-for-regex($delim)), '')
};
 
declare function local:generate-vra-image-record($uuid, $file-uuid, $title, $workrecord)
{
    let $vra-content :=
        <vra xmlns="http://www.vraweb.org/vracore4.htm" xmlns:ext="http://exist-db.org/vra/extension" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vraweb.org/vracore4.htm http://cluster-schemas.uni-hd.de/vra-strictCluster.xsd">
            <image id="{ $uuid }" source="Tamboti" refid="" href="{ $file-uuid }">
                <titleSet>
                    <display/>
                    <title type="generalView">{xmldb:decode(concat('Image record ', $title))}</title>
                </titleSet>
                <relationSet>
                    <relation type="imageOf" relids="{ $workrecord }" refid="" source="Tamboti">attachment</relation>
                </relationSet>
             </image>
         </vra>
    return $vra-content
};

declare function upload:generate-object($file-size, $mimetype, $uuid, $title, $file-uuid, $doc-type, $workrecord)
{
    let $vra-content := local:generate-vra-image-record($uuid, $file-uuid, $title, $workrecord)
    let $output :=
        if ($doc-type eq 'image') 
        then $vra-content
        else ()
    return $output
};

declare function upload:mkcol-recursive($collection, $components)
{
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return
            (xmldb:create-collection($collection, $components[1]),
            upload:mkcol-recursive($newColl, subsequence($components, 2)))
    else
        ()
};

(: Helper function to recursively create a collection hierarchy. :)
declare function upload:mkcol($collection, $path)
{
    upload:mkcol-recursive($collection, tokenize($path, "/"))[last()]
};

declare function local:apply-perms($path as xs:string, $username as xs:string, $mode as xs:string)
{
    sm:add-user-ace(xs:anyURI($path), $username, true(), $mode)
};

declare function upload:upload($file-type, $file-size, $file-name, $data, $doc-type, $workrecord) {
    let $new-uuid := concat('i_', util:uuid())
    let $parent-collection :=
        if (exists(collection($root-data-collection)//vra:work[@id=$workrecord]/@id))
        then util:collection-name(collection($root-data-collection)//vra:work[@id=$workrecord]/@id)
        else 
            if (exists(collection($root-data-collection)//mods:mods[@ID=$workrecord]/@ID))
            then util:collection-name(collection($root-data-collection)//mods:mods[@ID=$workrecord]/@ID)
            else ()
    let $parentdoc_path := concat($parent-collection, '/', $workrecord, '.xml')
    let $tag-changed := upload:add-tag-to-parent-doc($parentdoc_path, upload:determine-type($workrecord), $new-uuid)
    
    (:set the image VRA folder by adding the suffix:)
    let $upload :=  
        if (exists($parent-collection))
        then system:as-user($config:dba-credentials[1], $config:dba-credentials[2], 
                let $newcol := $parent-collection
                let $mkdir := if (xmldb:collection-available($newcol)) 
                    then ()
                    else
                        let $null := upload:mkcol('/', $newcol)
                        let $null := security:apply-parent-collection-permissions(xs:anyURI($newcol))
                            return $null
                let $create-image-folder := xmldb:create-collection($newcol, $image-collection-name)
                let $newcol := concat($newcol, '/', $image-collection-name)
                (:creae image folder:)
                let $null := 
                    if (not(xmldb:collection-available($newcol)))
                    then
                        let $null := xmldb:create-collection($newcol, $image-collection-name)
                        let $null := security:apply-parent-collection-permissions(xs:anyURI($newcol))
                            return $null                        
                    else()
                
                (: update the xml object  :)
                let $file-uuid := concat($new-uuid, '.', functx:substring-after-last($file-name, '.'))
                let $xml-object := upload:generate-object($file-size, $file-type, $new-uuid, $file-name, $file-uuid, $doc-type, $workrecord)
                (:save the xml file:)
                let $xml-uuid := concat($new-uuid, '.xml')
                let $xmlupload := xmldb:store($newcol, $xml-uuid, $xml-object)
                (:save binary file:)
                let $upload := xmldb:store($newcol, $file-uuid, $data)
                
                (::let $null := security:apply-parent-collection-permissions(xs:anyURI($newcol)):)
                let $null := sm:chown(xs:anyURI(concat($newcol, '/', $file-uuid)), security:get-user-credential-from-session()[1])
                let $null := sm:chmod(xs:anyURI(concat($newcol, '/', $file-uuid)), 'rwxr-xr-x')
                let $null := sm:chgrp(xs:anyURI(concat($newcol, '/', $file-uuid)), 'biblio.users')
                let $null := sm:chown(xs:anyURI(concat($newcol, '/', $xml-uuid)), security:get-user-credential-from-session()[1])
                let $null := sm:chmod(xs:anyURI(concat($newcol, '/', $xml-uuid)), 'rwxr-xr-x')
                let $null := sm:chgrp(xs:anyURI(concat($newcol, '/', $xml-uuid)), 'biblio.users')
                let $null := security:apply-parent-collection-permissions(xs:anyURI(concat($newcol, '/', $file-uuid)))
                let $null := security:apply-parent-collection-permissions(xs:anyURI(concat($newcol, '/', $xml-uuid)))
                    return concat(xmldb:decode($file-name), ' ' ,$message)
            
        )
       else ()
        return $upload
};
 
declare function upload:add-tag-to-parent-doc($parentdoc_path, $parent_type as xs:string, $myuuid){
 
let $parentdoc := doc($parentdoc_path)
let $add :=
    if ($parent_type eq 'vra')
    then
        let $vra_insert := <vra:relation type="imageIs" relids="{$myuuid}" source="Tamboti" refid=""  pref="true">general view</vra:relation>
        let $relationTag := $parentdoc/vra:vra/vra:work/vra:relationSet
            return
                let $vra-insert := $parentdoc
                let $insert_or_updata := 
                    if (not($relationTag))
                    then 
                        if (sm:has-access($parentdoc_path, 'w'))
                        then update insert  <vra:relationSet></vra:relationSet> into $vra-insert/vra:vra/vra:work
                        else util:log('error', 'no write access')
                    else ()
                let $vra-update := update insert  $vra_insert into $parentdoc/vra:vra/vra:work/vra:relationSet
                    return $vra-update
    else 
        if ($parent_type eq 'mods')
        then
            let $mods-insert := 
                <mods:relatedItem type="constituent">
                    <mods:typeOfResource>still image</mods:typeOfResource>
                    <mods:location>
                        <mods:url displayLabel="Illustration" access="preview">{$myuuid}</mods:url>
                    </mods:location>
                </mods:relatedItem>
            let $mods-update :=
                if (sm:has-access($parentdoc_path, 'w'))
                then update insert  $mods-insert into $parentdoc/mods:mods
                else util:log('error', 'no write access')
                    return  $mods-update 
       else ()
       
            return $add
};

 
declare function upload:determine-type($workrecord) {
 
let $vra_image := collection($root-data-collection)//vra:work[@id = $workrecord]/@id
let $type :=
    if (exists($vra_image)) 
    then 'vra'
    else
        let $mods := collection($root-data-collection)//mods:mods[@ID = $workrecord]/@ID
        let $mods_type :=
            if (exists($mods)) 
            then 'mods'
            else ()
                return $mods_type
     return $type
};


let $image-types := ('png', 'jpg', 'gif', 'tiff', 'jpeg', 'tif')
let $uploadedFile := 'uploadedFile'
let $data := request:get-uploaded-file-data($uploadedFile)
let $filename := request:get-uploaded-file-name($uploadedFile)
let $filesize := request:get-uploaded-file-size($uploadedFile)
let $result := for $x in (1 to count($data))
    let $filetype := functx:substring-after-last($filename[$x], '.')
    let $doc-type := if (ends-with(lower-case($filetype), $image-types))
        then 'image'
        else ''
        return
            if ($doc-type eq 'image')
            then
                let $workrecord := if (fn:string-length(request:get-header('X-File-Parent'))>0)
                then xmldb:encode(request:get-header('X-File-Parent'))
                else ()
                let $upload := 
                    if (exists($workrecord))
                    then upload:upload($filetype, $filesize[$x], xmldb:encode-uri($filename[$x]), $data[$x], $doc-type, $workrecord)
                    else
                        (:record for the collection:)
                        let $collection-folder :=  xmldb:decode(xmldb:encode(request:get-header('X-File-Folder')))
                        (: if the collection file exists in the file folder:)
                        (:read the collection uuid:)
                        let $collection_vra := collection($config:mods-root)//vra:collection
                        let $collection_uuid :=  
                            if (exists($collection_vra))
                            then $collection_vra/@id
                            else concat('c_', util:uuid())
                        
                        (:else generate the new collection file:)
                        let $null := 
                            if (exists($collection_vra/@id))
                            then ()
                            else
                                let $vra-collection-xml := 
                                    <vra xmlns="http://www.vraweb.org/vracore4.htm" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vraweb.org/vracore4.htm http://cluster-schemas.uni-hd.de/vra-strictCluster.xsd" xmlns:ext="http://exist-db.org/vra/extension">
                                    <collection id="{$collection_uuid}" source="" refid="{$collection_uuid}"></collection> </vra>
                                    (:let $store := system:as-user($config:dba-credentials[1], $config:dba-credentials[2], xmldb:store($collection-folder, concat($collection_uuid, '.xml'), $vra-collection-xml))
                                    return $store
                                    :)
                                        return ()
                                        
                        (:generate the  work record, if collection xml exists:)
                        let $work-xml-generate :=
                            if (exists($collection_uuid))
                            then
                                let $work_uuid := concat('w_', util:uuid())
                                let $vra-work-xml := 
                                    <vra xmlns="http://www.vraweb.org/vracore4.htm" xmlns:ext="http://exist-db.org/vra/extension" xmlns:hra="http://cluster-schemas.uni-hd.de" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vraweb.org/vracore4.htm http://cluster-schemas.uni-hd.de/vra-strictCluster.xsd">
                                        <work id="{$work_uuid}" source="Kurs" refid="{$collection_uuid}">
                                        <titleSet>
                                            <display/>
                                            <title type="generalView">{xmldb:decode(concat('Work record ', $filename[$x]))}</title>
                                        </titleSet>  
                                        </work>
                                    </vra>
                                let $store :=  system:as-user($config:dba-credentials[1], $config:dba-credentials[2], xmldb:store($collection-folder, concat($work_uuid, '.xml'), $vra-work-xml))
                                (: let $null := system:as-user($config:dba-credentials[1], $config:dba-credentials[2], security:apply-parent-collection-permissions(xs:anyURI(concat($collection-folder, '/', $work_uuid, '.xml')))) :)
                                let $null := system:as-user($config:dba-credentials[1], $config:dba-credentials[2], sm:chown(xs:anyURI(concat($collection-folder, '/', $work_uuid, '.xml')), security:get-user-credential-from-session()[1]))
                                let $null := system:as-user($config:dba-credentials[1], $config:dba-credentials[2], sm:chmod(xs:anyURI(concat($collection-folder, '/', $work_uuid, '.xml')), 'rwxr-xr-x'))
                                let $null := system:as-user($config:dba-credentials[1], $config:dba-credentials[2], sm:chgrp(xs:anyURI(concat($collection-folder, '/', $work_uuid, '.xml')), 'biblio.users'))
                                (:store the binary file and generate the image vra file:)
                                let $store := upload:upload( $filetype, $filesize[$x], $filename[$x], $data[$x], $doc-type, $work_uuid)
                                
                                    return $message
                            else ()
                                return concat($filename[$x], ' ', $message)
                    return $upload
        else 
            let $upload := 'unsupported file format'
                return $upload
    return $result