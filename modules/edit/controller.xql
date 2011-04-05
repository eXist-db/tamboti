xquery version "1.0";

import module namespace theme="http:/exist-db.org/xquery/biblio/theme" at "../theme.xqm";

if (starts-with($exist:path, "/theme")) then
    let $path := theme:resolve(concat($exist:controller, "/../.."), $exist:path)
    return
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{$path}"/>
        </dispatch>
else
    (: everything else is passed through :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </dispatch>