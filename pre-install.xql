xquery version "1.0";

(:
    TODO KISS - This file should be removed in favour of a convention based approach + some small metadata for users/groups/permissions (added by AR)
:)

import module namespace util="http://exist-db.org/xquery/util";
import module namespace xdb="http://exist-db.org/xquery/xmldb";

declare variable $home external;
declare variable $dir external;
declare variable $log-level := "INFO";
declare variable $db-root := "/db";
declare variable $system-collection := fn:concat($db-root, "/system/config");

(:~ Biblio security - admin user and users group :)
declare variable $biblio-admin-user := "editor";
declare variable $biblio-users-group := "biblio.users";

(:~ Collection names :)
declare variable $library-collection-name := "library";
declare variable $modules-collection-name := "modules";
declare variable $edit-app-collection-name := "edit";
declare variable $code-tables-collection-name := "code-tables";
declare variable $resources-collection-name := "resources";
declare variable $users-collection-name := "users";
declare variable $groups-collection-name := "groups";
declare variable $temp-collection-name := "temp";
declare variable $commons-collection-name := "commons";
declare variable $commons-samples-collection-name := "sociology";
declare variable $commons-exist-collection-name := "eXist";
declare variable $commons-mads-collection-name := "mads";

(:~ Collection paths :)
declare variable $library-collection := fn:concat($db-root, "/", $library-collection-name);
declare variable $modules-collection := fn:concat($library-collection, "/", $modules-collection-name);
declare variable $editor-app-collection := fn:concat($modules-collection, "/", $edit-app-collection-name);
declare variable $editor-app-code-tables-collection := fn:concat($editor-app-collection, "/", $code-tables-collection-name);
declare variable $resources-collection := fn:concat($db-root, "/", $resources-collection-name);
declare variable $resources-temp-collection := fn:concat($resources-collection, "/", $temp-collection-name);
declare variable $resources-users-collection := fn:concat($resources-collection, "/", $users-collection-name);
declare variable $resources-groups-collection := fn:concat($resources-collection, "/", $groups-collection-name);
declare variable $commons-collection := fn:concat($resources-collection, "/", $commons-collection-name);
declare variable $commons-samples-collection := fn:concat($commons-collection, "/", $commons-samples-collection-name);
declare variable $commons-exist-collection := fn:concat($commons-collection, "/", $commons-exist-collection-name);
declare variable $commons-mads-collection := fn:concat($commons-collection, "/", $commons-mads-collection-name);

declare function local:mkcol-recursive($collection, $components) {
    if (fn:exists($components)) then
        let $newColl := fn:concat(
            $collection, 
            if(fn:starts-with($components[1], "/"))then($components[1])else(fn:concat("/", $components[1]))
        )
        return (
            xdb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, fn:subsequence($components, 2))
        )
    else
        ()
};

declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, fn:tokenize($path, "/"))
};

declare function local:set-collection-resource-permissions($collection as xs:string, $owner as xs:string, $group as xs:string, $permissions as xs:int) {
    for $resource in xdb:get-child-resources($collection) return
        xdb:set-resource-permissions($collection, $resource, $owner, $group, $permissions)
};

declare function local:strip-prefix($str as xs:string, $prefix as xs:string) as xs:string? {
    fn:replace($str, $prefix, "")
};


util:log($log-level, "Script: Running pre-install script ..."),
util:log($log-level, fn:concat("...Script: using $home '", $home, "'")),
util:log($log-level, fn:concat("...Script: using $dir '", $dir, "'")),

(: Create users and groups :)
util:log($log-level, fn:concat("Security: Creating user '", $biblio-admin-user, "' and group '", $biblio-users-group, "' ...")),
    if (xdb:group-exists($biblio-users-group)) then ()
    else xdb:create-group($biblio-users-group),
    if (xdb:exists-user($biblio-admin-user)) then ()
    else xdb:create-user($biblio-admin-user, $biblio-admin-user, $biblio-users-group, ()),
util:log($log-level, "Security: Done."),

(: Load collection.xconf documents :)
util:log($log-level, "Config: Loading collection configuration ..."),
    local:mkcol($system-collection, $editor-app-code-tables-collection),
    xdb:store-files-from-pattern(fn:concat($system-collection, $editor-app-code-tables-collection), $dir, "modules/edit/code-tables/*.xconf"),
    local:mkcol($system-collection, $resources-collection),
    xdb:store-files-from-pattern(fn:concat($system-collection, $resources-collection), $dir, "data/*.xconf"),
    local:mkcol($system-collection, $commons-mads-collection),
    (: TODO - how to load additional collection.xconf files and where should these be kept in the EXPath Package? :)
    (: xdb:store-files-from-pattern("/system/config/db/resources/commons/mads", $home, "commons/mads/*.xconf"), :)
util:log($log-level, "Config: Done."),


(: Create temp collection :)
util:log($log-level, fn:concat("Config: Creating temp collection '", $resources-temp-collection, "'...")),
    local:mkcol($db-root, local:strip-prefix($resources-temp-collection, fn:concat($db-root, "/"))),
    xdb:set-collection-permissions($resources-temp-collection, $biblio-admin-user, $biblio-users-group, util:base-to-integer(0770, 8)),
util:log($log-level, "Config: Done."),


(: Create resources/commons :)
util:log($log-level, fn:concat("Config: Creating commons collection '", $commons-collection, "'...")),
    for $col in ($commons-samples-collection, $commons-exist-collection, $commons-mads-collection) return
    (
        local:mkcol($db-root, local:strip-prefix($col, fn:concat($db-root, "/"))),
        xdb:set-collection-permissions($col, $biblio-admin-user, $biblio-users-group, util:base-to-integer(0755, 8))
    ),
    util:log($log-level, "...Config: Uploading samples data..."),
        xdb:store-files-from-pattern($commons-samples-collection, $dir, "data/sociology/*.xml"),
        local:set-collection-resource-permissions($commons-samples-collection, $biblio-admin-user, $biblio-users-group, util:base-to-integer(0755, 8)),
        xdb:store-files-from-pattern($commons-exist-collection, $dir, "data/eXist/*.xml"),
        local:set-collection-resource-permissions($commons-exist-collection, $biblio-admin-user, $biblio-users-group, util:base-to-integer(0755, 8)),
    util:log($log-level, "...Config: Done Uploading samples data."),
util:log($log-level, "Config: Done."), 


(: Create users and groups collections :)
util:log($log-level, fn:concat("Config: Creating users '", $resources-users-collection, "' and groups '", $resources-groups-collection, "' collections")),
    local:mkcol($db-root, $resources-collection-name),
    for $col in ($resources-users-collection, $resources-groups-collection) return
    (
        local:mkcol($db-root, local:strip-prefix($col, fn:concat($db-root, "/"))),
        xdb:set-collection-permissions($col, $biblio-admin-user, $biblio-users-group, util:base-to-integer(0771, 8))
    ),
util:log($log-level, "Config: Done."),

util:log($log-level, "Script: Done.")
