xquery version "1.0";

module namespace config="http://exist-db.org/mods/config";

declare variable $config:mods-root := "/db/resources";
declare variable $config:app-root := "/db/library";
declare variable $config:search-app-root := "/db/library/modules/search";
declare variable $config:edit-app-root := "/db/library/modules/edit";
declare variable $config:force-lower-case-usernames as xs:boolean := true();

declare variable $config:users-collection := fn:concat($config:mods-root, "/users");
declare variable $config:groups-collection := fn:concat($config:mods-root, "/groups");

declare variable $config:mods-temp-collection := "/db/resources/temp";

declare variable $config:themes := "../themes";

declare variable $config:resources := "../resources";
declare variable $config:images := "../resources/images";

(: email invitation settings :)
declare variable $config:send-notification-emails := false();
declare variable $config:smtp-server := "smtp.yourdomain.com";
declare variable $config:smtp-from-address := "exist@yourdomain.com";

(:~ Credentials for the dba admin user :)
declare variable $config:dba-credentials := ("admin", ());
