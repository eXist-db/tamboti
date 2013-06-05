xquery version "3.0";
declare namespace vra="http://www.vraweb.org/vracore4.htm";
declare namespace upload = "http://exist-db.org/eXide/upload";

declare namespace mods="http://www.loc.gov/mods/v3";

import module namespace config="http://exist-db.org/mods/config" at "../../modules/config.xqm";


declare variable $col := $config:mods-root;
declare variable $user := 'admin';
declare variable $userpass := '';
declare variable $rootdatacollection:='/db/resources/';


(:
let $results :=   collection($col)//vra:work[@id="w_186f5b16-e799-5bb5-b0c6-831575278973"]/vra:relationset/vra:relation
let $images := for $entry in $results
                    (:return <img src="{$entry/@relids}"/>:)
                    let $image := collection($col)//vra:image[@id=$entry/@relids]
                   return <img src="{concat(request:get-scheme(),'://',request:get-server-name(),':',request:get-server-port(),request:get-context-path(),'/rest', util:collection-name($image),"/" ,$image/@href)}" />
     
     
let $result_set := if (not($results)) then <xml>image uuid not found</xml> else ($results)


:)
 
 declare function upload:determine-type($workrecord){
    
    let $vra_image := collection($rootdatacollection)//vra:work[@id=$workrecord]/@id
    let $type := if (exists($vra_image))
    then 
    ('vra')
    else(
    let $mods := collection($rootdatacollection)//mods:mods[@ID=$workrecord]/@ID
    let $mods_type := if (exists($mods))
    then ('mods')
    else ()
    return $mods_type
    
    )
    
    return  $type
}; 
let $x := system:as-user($user, $userpass,xmldb:reindex($rootdatacollection))
let $test := upload:determine-type('uuid-f418d59d-7313-40e3-b90a-a2de6c5829ad')
return <xml>{$test}</xml>
