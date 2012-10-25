xquery version "1.0";

import module namespace theme="http://exist-db.org/xquery/biblio/theme" at "../theme.xqm";

(: Disable the betterFORM XForms filter on all requests. We use XSLTForms for tamboti. :)
request:set-attribute("betterform.filter.ignoreResponseBody", "true"),

if (starts-with($exist:path, "/theme")) then
    let $path := theme:resolve($exist:prefix, $exist:root, substring-after($exist:path, "/theme"))
    let $themePath := replace($path, "^(.*)/[^/]+$", "$1")
    return
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{$path}">
                <set-attribute name="theme-collection" value="{$themePath}"/>
            </forward>
        </dispatch>
    
(: paths starting with /libs/ will be loaded from the webapp directory on the file system :)
else if (starts-with($exist:path, "/libs/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/{substring-after($exist:path, 'libs/')}" absolute="yes"/>
    </dispatch>

else
    (: everything else is passed through :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </dispatch>