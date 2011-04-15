xquery version "1.0";

module namespace config="http://exist-db.org/mods/config";

(: 
    Determine the application root collection from the current module load path.
:)
declare variable $config:app-root := 
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    return
        substring-before($modulePath, "/modules")
;

declare variable $config:mods-root := "/db/resources";
declare variable $config:mods-commons := fn:concat($config:mods-root, "/commons");

declare variable $config:search-app-root := concat($config:app-root, "/modules/search");
declare variable $config:edit-app-root := concat($config:app-root, "/modules/edit");
declare variable $config:force-lower-case-usernames as xs:boolean := true();

declare variable $config:users-collection := fn:concat($config:mods-root, "/users");
declare variable $config:groups-collection := fn:concat($config:mods-root, "/groups");

declare variable $config:mods-temp-collection := "/db/resources/temp";
declare variable $config:mads-collection := "/db/resources/mads";

declare variable $config:themes := concat($config:app-root, "/themes");

declare variable $config:resources := concat($config:app-root, "/resources");
declare variable $config:images := concat($config:app-root, "/resources/images");

(: email invitation settings :)
declare variable $config:send-notification-emails := false();
declare variable $config:smtp-server := "smtp.yourdomain.com";
declare variable $config:smtp-from-address := "exist@yourdomain.com";

(:~ Credentials for the dba admin user :)
declare variable $config:dba-credentials := ("admin", ());