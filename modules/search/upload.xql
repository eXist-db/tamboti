(: adapted from eXide's modules/upload.xql :)
(:
 :  eXide - web-based XQuery IDE
 :  
 :  Copyright (C) 2011 Wolfgang Meier
 :
 :  This program is free software: you can redistribute it and/or modify
 :  it under the terms of the GNU General Public License as published by
 :  the Free Software Foundation, either version 3 of the License, or
 :  (at your option) any later version.
 :
 :  This program is distributed in the hope that it will be useful,
 :  but WITHOUT ANY WARRANTY; without even the implied warranty of
 :  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 :  GNU General Public License for more details.
 :
 :  You should have received a copy of the GNU General Public License
 :  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 :)
xquery version "3.0";

import module namespace json = "http://www.json.org";

declare namespace expath = "http://expath.org/ns/pkg";
declare namespace upload = "http://exist-db.org/eXide/upload";
import module namespace uu="http://exist-db.org/mods/uri-util" at "uri-util.xqm";

declare option exist:serialize "media-type=application/json";

declare function upload:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xmldb:create-collection($collection, $components[1]),
            upload:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

(: Helper function to recursively create a collection hierarchy. :)
declare function upload:mkcol($collection, $path) {
    upload:mkcol-recursive($collection, tokenize($path, "/"))[last()]
};

declare function upload:store($root as xs:string, $path as xs:string, $data) {
    if (matches($path, "/[^/]+$")) then
        let $split := text:groups($path, "^(.*)/([^/]+)$")
        let $newCol := upload:mkcol($root, $split[2])
        return
            xmldb:store($newCol, $split[3], $data)
    else
        xmldb:store($root, $path, $data)
};

declare function upload:upload($collection, $path, $data) {
    let $upload := 
        (: authenticate as the user account set in the app's repo.xml, since we need write permissions to
         : upload the file.  then set the uploaded file's permissions to allow guest/world to delete the file 
         : for the purposes of the demo :)
        system:as-user('admin', '', 
            (
            let $mkdir := if (xmldb:collection-available($collection)) then() else ()
            let $upload := xmldb:store($collection, $path, $data)
            let $chmod := sm:chmod(xs:anyURI($upload), 'o+rw')
            return ()
            )
        )
    return
        let $result :=
            <result>
               <name>{$path}</name>
               <type>{xmldb:get-mime-type(xs:anyURI(concat($collection, '/', $path)))}</type>
               <size>{xmldb:size($collection, $path)}</size>
               <url>{xs:anyURI(concat($collection, '/', $path))}</url>
              
           </result>
        let $json-output := concat('[', json:xml-to-json($result), ']')
        return 
            $json-output
};

let $collection := uu:escape-collection-path(request:get-parameter("collection", ()))
let $name := request:get-uploaded-file-name('files[]')
let $data := request:get-uploaded-file-data('files[]')
let $result := 
    if (exists($name)) then
        try {
            upload:upload(xmldb:encode-uri($collection), xmldb:encode-uri($name), $data)
        } catch * {
            concat (
                '[',
                json:xml-to-json(
                    <result>
                        <name>{$name}</name>
                        <error>{$err:code, $err:value, $err:description}</error>
                    </result>
                ),
                ']'
            )
        }
    else
        ''
return 
    $result