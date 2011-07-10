xquery version "1.0";

import module namespace session ="http://exist-db.org/xquery/session";

import module namespace security="http://exist-db.org/mods/security" at "modules/search/security.xqm";
import module namespace theme="http:/exist-db.org/xquery/biblio/theme" at "modules/theme.xqm";

declare namespace exist = "http://exist.sourceforge.net/NS/exist";

declare variable $exist:controller external;
declare variable $exist:root external;
declare variable $exist:prefix external;
declare variable $exist:path external;
declare variable $exist:resource external;

declare function local:get-item($controller as xs:string, $root as xs:string, $prefix as xs:string?, $path as xs:string, $resource as xs:string?, $username as xs:string?, $password as xs:string?) as element(exist:dispatch) {
    
    let $item-id := fn:replace($path, "/item/([a-z0-9-_]*)", "$1") return
    
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">        
            <forward url="{theme:resolve($prefix, $root, 'pages/index.html')}">
                { local:set-user($username, $password) }
            </forward>
            <forward url="{$controller}/modules/search/search.xql">
                <set-attribute name="xquery.report-errors" value="yes"/>
                
                <set-attribute name="exist:root" value="{$root}"/>
                <set-attribute name="exist:path" value="{$path}"/>
                <set-attribute name="exist:prefix" value="{$prefix}"/>
                
                <add-parameter name="filter" value="ID"/>
                <add-parameter name="value" value="{$item-id}"/>
    		</forward>
    	</dispatch>
};

declare function local:set-user($user as xs:string?, $password as xs:string?) {
    session:create(),
    let $session-user-credential := security:get-user-credential-from-session()
    return
        if ($user) then (
            security:store-user-credential-in-session($user, $password),
            <set-attribute name="xquery.user" value="{$user}"/>,
            <set-attribute name="xquery.password" value="{$password}"/>
        ) else if ($session-user-credential != '') then (
            <set-attribute name="xquery.user" value="{$session-user-credential[1]}"/>,
            <set-attribute name="xquery.password" value="{$session-user-credential[2]}"/>
        ) else (
            <set-attribute name="xquery.user" value="{$security:GUEST_CREDENTIALS[1]}"/>,
            <set-attribute name="xquery.password" value="{$security:GUEST_CREDENTIALS[2]}"/>
        )
};

let 
    $username := request:get-parameter("username",()),
    $password := request:get-parameter("password",())
return

    if ($exist:path eq '/') then
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
    		<redirect url="modules/search/index.html"/>
    	</dispatch>
    
    else if(fn:starts-with($exist:path, "/item/")) then
        local:get-item($exist:controller, $exist:root, $exist:prefix, $exist:path, $exist:resource, $username, $password)
        
    else
        (: everything else is passed through :)
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <cache-control cache="yes"/>
        </dispatch>