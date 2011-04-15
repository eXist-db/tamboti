xquery version "1.0";

import module namespace xdb="http://exist-db.org/xquery/xmldb";

declare variable $home external;
declare variable $dir external;

declare variable $commons-collection-name := "resources";
declare variable $commons-users-collection-name := "users";
declare variable $commons-groups-collection-name := "groups";

declare function local:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xdb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};

declare function local:set-collection-resource-permissions($collection as xs:string, $owner as xs:string, $group as xs:string, $permissions as xs:int) {
    for $resource in xdb:get-child-resources($collection) return
        xdb:set-resource-permissions($collection, $resource, $owner, $group, $permissions)
};

util:log("INFO", ("Running pre-install script ...")),
if (xdb:group-exists("biblio.users")) then ()
else xdb:create-group("biblio.users"),
if (xdb:exists-user("editor")) then ()
else xdb:create-user("editor", "editor", "biblio.users", ()),

util:log("INFO", ("Loading collection configuration ...")),
local:mkcol("/db/system/config", "db/library/modules/edit/code-tables"),
xdb:store-files-from-pattern("/system/config/db/library/modules/edit/code-tables", $dir, "library/modules/edit/code-tables/*.xconf"), (: TODO this file is no longer loaded - should fix :)
local:mkcol("/db/system/config", "db/resources"),
xdb:store-files-from-pattern("/system/config/db/resources", $home, "samples/mods/*.xconf"),

util:log("INFO", ("Creating temp collection ...")),
local:mkcol("/db", "resources/temp"),
xdb:set-collection-permissions("/db/resources/temp", "editor", "biblio.users", util:base-to-integer(0770, 8)),

(:create resources/commons :)
local:mkcol("/db", "resources/commons/samples"),
xdb:set-collection-permissions("/db/resources/commons/samples", "editor", "biblio.users", util:base-to-integer(0744, 8)),
local:mkcol("/db", "resources/commons/eXist"),
xdb:set-collection-permissions("/db/resources/commons/eXist", "editor", "biblio.users", util:base-to-integer(0744, 8)),

local:mkcol("/db", $commons-collection-name),
local:mkcol(fn:concat("/db/", $commons-collection-name), $commons-users-collection-name),
local:mkcol(fn:concat("/db/", $commons-collection-name), $commons-groups-collection-name),
xdb:set-collection-permissions(fn:concat("/db/", $commons-collection-name, "/", $commons-users-collection-name), "editor", "biblio.users", util:base-to-integer(0770, 8)),
xdb:set-collection-permissions(fn:concat("/db/", $commons-collection-name, "/", $commons-groups-collection-name), "editor", "biblio.users", util:base-to-integer(0770, 8)),
xdb:store-files-from-pattern("/db/resources/commons/samples", $home, "samples/mods/*.xml"),
local:set-collection-resource-permissions("/db/resources/commons/samples", "editor", "biblio.users", util:base-to-integer(0744, 8)),
xdb:store-files-from-pattern("/db/resources/commons/eXist", $home, "samples/mods/eXist/*.xml"),
local:set-collection-resource-permissions("/db/resources/commons/eXist", "editor", "biblio.users", util:base-to-integer(0744, 8)),

(: create commons mads collection :)
local:mkcol("/db", "resources/commons/mads"),
xdb:set-collection-permissions("/db/resources/commons/mads", "editor", "biblio.users", util:base-to-integer(0744, 8)),

local:mkcol("/db/system/config", "db/resources/commons/mads")

(: TODO - how to load additional collection.xconf files and where should these be kept in the EXPath Package? :)
(:,
xdb:store-files-from-pattern("/system/config/db/resources/commons/mads", $home, "commons/mads/*.xconf"), 
:)

(: TODO webapp/packages should be deleted, esp. webapp/packages/library :)
