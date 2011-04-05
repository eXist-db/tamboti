module namespace theme="http:/exist-db.org/xquery/biblio/theme";

import module namespace config="http://exist-db.org/mods/config" at "config.xqm";

declare function theme:resolve($root as xs:string, $path as xs:string) {
    concat($root, "/themes", "/default/", substring-after($path, "theme/"))
};