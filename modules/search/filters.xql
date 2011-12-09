xquery version "1.0";

(:~
    Returns the list of distinct authors, dates etc. occurring in the result set.
    The query is called via AJAX when the user expands one of the headings in the
    "filter" box.
:)
import module namespace names="http://exist-db.org/xquery/biblio/names"
    at "names.xql";

declare namespace mods="http://www.loc.gov/mods/v3";

declare option exist:serialize "method=xhtml enforce-xhtml=yes";

declare variable $local:MAX_RESULTS := 1500;
declare variable $local:MAX_RESULTS_NAMES := 1500;
declare variable $local:MAX_TERMS := 50;
declare variable $local:MAX_RESULTS_SUBJECTS := 5000;

declare function local:key($key, $options) {
    <li><a href="?filter=Title&amp;value={$key}&amp;query-tabs=advanced-search-form">{$key} ({$options[1]})</a></li>
};

declare function local:keywords($results as element()*) {
    let $max := 
        if (count($results) ge $local:MAX_RESULTS) 
        then $local:MAX_TERMS 
        else () (: unlimited :)
    let $prefixParam := request:get-parameter("prefix", "")
    let $prefix := if (empty($max)) then "" else $prefixParam
    let $callback := util:function(xs:QName("local:key"), 2)
    return
        <ul class="{if (empty($max)) then 'complete' else $max}">
        { util:index-keys($results//mods:titleInfo, $prefix, $callback, $max, "lucene-index") }
        </ul>
};

let $type := request:get-parameter("type", ())
(: There is a load problem with setting this attribute to the cache each time a facet button is clicked. 10,000 records is about 20 MB and several people could easily access this function at the same time. Even if the cache contain too many items and we do not allow it to be processed, it still takes up memory. If we check the size of the cache beforehand, we have to have a way to alert the users when is is too big to load. :) 
(: The size has been set to 10,000. :)
let $cache-size := count(session:get-attribute("mods:cached"))
let $cached := 
    if ($cache-size > 10000) 
    then () 
    else session:get-attribute("mods:cached")
return
    if ($type eq 'author') 
    then
        <ul>
        {
            let $names := $cached//mods:name
            return
                (:If the count is zero, the cache-size limit has been reached.:)
                if (count($names) gt $local:MAX_RESULTS_NAMES or count($cached) eq 0) 
                then
                    <li>There are too many names to process without overloading the server. Please restrict the result set by performing a new search.</li>
                else
                    let $authors :=
                        for $author in $names
                        return 
                            names:format-name($author)
                                let $distinct := distinct-values($authors)
                                for $name in $distinct
                                order by upper-case($name) empty greatest
                                return
                                    <li><a href="?filter=Name&amp;value={$name}&amp;query-tabs=advanced-search-form">{$name}</a></li>
        }
        </ul>
    else
        if ($type eq 'date') 
        then
            <ul>
            {
                let $dates :=
                    (
                    	$cached/mods:originInfo/mods:dateIssued,
                    	$cached/mods:originInfo/mods:dateCreated,
                    	$cached/mods:originInfo/mods:copyrightDate,
                    	$cached/mods:relatedItem/mods:originInfo/mods:copyrightDate,
                    	$cached/mods:relatedItem/mods:originInfo/mods:dateIssued,
                    	$cached/mods:relatedItem/mods:part/mods:date
                	)
                return
                    if (count($dates) gt $local:MAX_RESULTS or count($cached) eq 0) 
                    then
                        <li>There are too many dates to process without overloading the server. Please restrict the result set by performing a new search.</li>
                    else
                        for $date in distinct-values($dates)
                        order by $date descending
                        return
                            <li><a href="?filter=Date&amp;value={$date}&amp;query-tabs=advanced-search-form">{$date}</a></li>
             }</ul>
        else
            if ($type eq 'subject') 
            then
                <ul>
                {
                    let $subjects := $cached/mods:subject
                    return
                        if (count($subjects) gt $local:MAX_RESULTS_SUBJECTS or count($cached) eq 0) 
                        then
                            <li>There are too many subjects to process without overloading the server. Please restrict the result set by performing a new search.</li>
                        else
                            for $subject in distinct-values($subjects)
                            order by $subject ascending
                            return
                                <li><a href="?filter=Subject&amp;value={$subject}&amp;query-tabs=advanced-search-form">{$subject}</a></li>
                 }</ul>
             else 
                 if ($type eq 'keywords') 
                 then local:keywords($cached)
                 else ()