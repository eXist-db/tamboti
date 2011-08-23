xquery version "1.0";

import module namespace json="http://www.json.org";
import module namespace request = "http://exist-db.org/xquery/request";
import module namespace session = "http://exist-db.org/xquery/session";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace xmldb = "http://exist-db.org/xquery/xmldb";

import module namespace config="http://exist-db.org/mods/config" at "../config.xqm";
import module namespace security="http://exist-db.org/mods/security" at "security.xqm";
import module namespace sharing="http://exist-db.org/mods/sharing" at "sharing.xqm";
import module namespace uu="http://exist-db.org/mods/uri-util" at "uri-util.xqm";

declare namespace exist = "http://exist.sourceforge.net/NS/exist";
declare namespace group = "http://commons/sharing/group";
declare namespace col = "http://library/search/collections";

declare option exist:serialize "method=json media-type=text/javascript";

declare function local:get-sharing($collection-path as xs:string) as element(aaData) {

    let $acl := sm:get-permissions($collection-path)/sm:permission/sm:acl return
        if(xs:integer($acl/@entries) eq 0)then
            local:empty()
        else
            <aaData>{
                for $ace in $acl/sm:ace return
                    element json:value {
                        if(xs:integer($acl/@entries) eq 1) then
                            attribute json:array { true() }
                        else(),
                        
                        <json:value>{text{$ace/@target}}</json:value>,
                        <json:value>{text{$ace/@who}}</json:value>,
                        <json:value>{text{$ace/@access_type}}</json:value>,
                        <json:value>{text{$ace/@mode}}</json:value>,
                        <json:value>removeMe</json:value>
                    }
            }</aaData>
};

declare function local:empty() {
    <aaData json:array="true"/>
};

<json:value>
    {
    if(request:get-parameter("collection",()))then
        local:get-sharing(uu:escape-collection-path(request:get-parameter("collection",())))
    else
        local:empty()
    }
</json:value>