xquery version "1.0";

import module namespace security="http://exist-db.org/mods/security" at "security.xqm";
import module namespace sharing="http://exist-db.org/mods/sharing" at "sharing.xqm";
import module namespace config="http://exist-db.org/mods/config" at "../config.xqm";

declare namespace request = "http://exist-db.org/xquery/request";
declare namespace response = "http://exist-db.org/xquery/response";

declare function local:authenticate($user as xs:string, $password as xs:string?) as element()
{
    if(security:login($user, $password))then(
        <ok/>
    )
    else (
        response:set-status-code(403),
        <span>Wrong username or wrong password.</span>
    )
};

declare function local:collection-relationship($user as xs:string, $collection as xs:string) as element(relationship)
{
    <relationship user="{$user}" collection="{$collection}">
        <read>{ security:can-read-collection($user, $collection) }</read>
        <write>{
            if($collection = ($config:groups-collection, $config:users-collection))then (
                false()
            ) else (
                security:can-write-collection($user, $collection)
            )
        }</write>
        <home>{ $collection eq security:get-home-collection-uri($user) }</home>
        <owner>{ security:is-collection-owner($user, $collection) }</owner>
    </relationship>
};

declare function local:user-is-collection-owner($user as xs:string, $collection as xs:string) as element(result)
{
    <result>{security:is-collection-owner($user, $collection)}</result>
};

if(request:get-parameter("action",()))then
(
    let $action := request:get-parameter("action", ()) return
        if($action eq "is-collection-owner")then
            local:user-is-collection-owner(security:get-user-credential-from-session()[1], request:get-parameter("collection",()))
        else if($action eq "collection-relationship")then
            local:collection-relationship(security:get-user-credential-from-session()[1], request:get-parameter("collection",()))
        else
        (
            response:set-status-code(403),
            <unknown action="{$action}"/>
        )
)
else
    local:authenticate(request:get-parameter("user", ()), request:get-parameter("password", ()))