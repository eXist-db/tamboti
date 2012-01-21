xquery version "1.0";

(:~
    Returns the list of distinct title words, names, dates, and subjects occurring in the result set.
    The query is called via AJAX when the user expands one of the headings in the
    "filter" box.
    The title words are derived from the Lucene index. The names rely on names:format-name() and are therefore expensive.
:)
import module namespace names="http://exist-db.org/xquery/biblio/names"
    at "names.xql";

declare namespace mods="http://www.loc.gov/mods/v3";

declare option exist:serialize "method=xhtml enforce-xhtml=yes";

declare variable $local:MAX_RECORD_COUNT := 13000;
declare variable $local:MAX_RESULTS_TITLES := 1500;
declare variable $local:MAX_TITLE_WORDS := 1000;
declare variable $local:MAX_RESULTS_DATES := 1300;
declare variable $local:MAX_RESULTS_NAMES := 1500;
declare variable $local:MAX_RESULTS_SUBJECTS := 750;

declare function local:key($key, $options) {
    <li><a href="?filter=Title&amp;value={$key}&amp;query-tabs=advanced-search-form">{$key} ({$options[1]})</a></li>
};

declare function local:keywords($results as element()*, $record-count as xs:integer) {
    let $max-terms := 
        if ($record-count ge $local:MAX_RESULTS_TITLES) 
        then $local:MAX_TITLE_WORDS 
        else ()
    let $prefixParam := request:get-parameter("prefix", "")
    let $prefix := if (empty($max-terms)) then "" else $prefixParam
    let $callback := util:function(xs:QName("local:key"), 2)
return
    (: NB: Is there any way to get the number of title words? :)
    if ($record-count gt $local:MAX_RECORD_COUNT) 
    then
        <li>There are too many records ({$record-count}) to process without overloading the server. Please restrict the result set by performing a narrower search. The maximum number is {$local:MAX_RECORD_COUNT}.</li>
    else
        <ul class="{if (empty($max-terms)) then 'complete' else $max-terms}">
        { util:index-keys($results//mods:titleInfo, $prefix, $callback, $max-terms, "lucene-index") }
        </ul>
};

let $type := request:get-parameter("type", ())
let $record-count := count(session:get-attribute("mods:cached"))
(: There is a load problem with setting this variable to the cache each time a facet button is clicked. 
10,000 records amount to about 20 MB and several people could easily access this function at the same time. 
Even if the cache contains too many items and we do not allow it to be processed, it still takes up memory. 
The size has been set to 13,000, to accommodate the largest collection. 
If the result set is larger than that, a message is shown. :)
let $cached := 
    if ($record-count gt $local:MAX_RECORD_COUNT) 
    then ()
    else session:get-attribute("mods:cached")
return
    if ($type eq 'author') 
    then
        <ul>
        {
            let $names := $cached//mods:name
            (: Here we count to string values of the name element, not the formatted result. :)
            let $names-count := count(distinct-values($names))
            return
                if ($names-count gt $local:MAX_RESULTS_NAMES) 
                then
                    <li>There are too many names ({$names-count}) to process without overloading the server. Please restrict the result set by performing a narrower search. The maximum number is {$local:MAX_RESULTS_NAMES}.</li>
                else
                    if ($record-count gt $local:MAX_RECORD_COUNT)
                    then
                        <li>There are too many records ({$record-count}) to process without overloading the server. Please restrict the result set by performing a narrower search. The maximum number is {$local:MAX_RECORD_COUNT}.</li>
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
                    distinct-values(
                    (
                    	$cached/mods:originInfo/mods:dateIssued,
                    	$cached/mods:originInfo/mods:dateCreated,
                    	$cached/mods:originInfo/mods:copyrightDate,
                    	$cached/mods:relatedItem/mods:originInfo/mods:copyrightDate,
                    	$cached/mods:relatedItem/mods:originInfo/mods:dateIssued,
                    	$cached/mods:relatedItem/mods:part/mods:date
                	)
                	)
                let $dates-count := count($dates)
                return
                    if ($dates-count gt $local:MAX_RESULTS_DATES) 
                    then
                        <li>There are too many dates ({$dates-count}) to process without overloading the server. Please restrict the result set by performing a narrower search. The maximum number is {$local:MAX_RESULTS_DATES}.</li>
                    else
                        if ($record-count gt $local:MAX_RECORD_COUNT) 
                        then
                            <li>There are too many records ({$record-count})to process without overloading the server. Please restrict the result set by performing a narrower search. The maximum number is {$local:MAX_RECORD_COUNT}.</li>
                        else
                            for $date in $dates
                            order by $date descending
                            return
                                <li><a href="?filter=Date&amp;value={$date}&amp;query-tabs=advanced-search-form">{$date}</a></li>
             }
             </ul>
        else
            if ($type eq 'subject') 
            then
                <ul>
                {
                    let $subjects := distinct-values($cached/mods:subject)
                    let $subjects-count := count($subjects)
                    return
                        if ($subjects-count gt $local:MAX_RESULTS_SUBJECTS)
                        then
                            <li>There are too many subjects ({$subjects-count}) to process without overloading the server. Please restrict the result set by performing a narrower search. The maximum number is {$local:MAX_RESULTS_SUBJECTS}.</li>
                        else
                            if ($record-count gt $local:MAX_RECORD_COUNT)
                            then
                                <li>There are too many records ({$record-count}) to process without overloading the server. Please restrict the result set by performing a narrower search. The maximum number is {$local:MAX_RECORD_COUNT}.</li>
                            else
                                for $subject in $subjects
                                order by upper-case($subject) ascending
                                return
                                    <li><a href="?filter=Subject&amp;value={$subject}&amp;query-tabs=advanced-search-form">{$subject}</a></li>
                 }
                 </ul>
             else
                 if ($type eq 'keywords')
                 then local:keywords($cached, $record-count)
                 else ()