module namespace retrieve-vra="http://www.vraweb.org/vracore4.htm";

declare namespace vra="http://www.vraweb.org/vracore4.htm";
declare namespace mads="http://www.loc.gov/mads/v2";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace functx = "http://www.functx.com";
declare namespace ext="http://exist-db.org/mods/extension";
declare namespace hra="http://cluster-schemas.uni-hd.de";

import module namespace config="http://exist-db.org/mods/config" at "../../../modules/config.xqm";
import module namespace uu="http://exist-db.org/mods/uri-util" at "../../../modules/search/uri-util.xqm";
import module namespace vra-common="http://www.vraweb.org/vracore4.htm/common" at "../../../modules/vra-common.xql";

(:The $retrieve-vra:primary-roles values are lower-cased when compared.:)
declare variable $retrieve-vra:primary-roles := ('aut', 'author', 'cre', 'creator', 'composer', 'cmp', 'artist', 'art', 'director', 'drt');

declare option exist:serialize "media-type=text/xml";

(:~
: The functx:substring-before-last-match function returns the part of $arg that appears before the last match of $regex. 
: If $arg does not match $regex, the entire $arg is returned. 
: If $arg is the empty sequence, the empty sequence is returned.
: @author Jenny Tennison
: @param $arg the string to substring
: @param $regex the regular expression (string)
: @return xs:string?
: @see http://www.xqueryfunctions.com/xq/functx_substring-before-last-match.html 
:)
declare function functx:substring-before-last-match($arg as xs:string, $regex as xs:string) as xs:string? {       
   replace($arg,concat('^(.*)',$regex,'.*'),'$1')
} ;
 
(:~
: The functx:camel-case-to-words function turns a camel-case string 
: (one that uses upper-case letters to start new words, as in "thisIsACamelCaseTerm"), 
: and turns them into a string of words using a space or other delimiter.
: Used to transform the camel-case names of VRA elements into space-separated words.
: @author Jenny Tennison
: @param $arg the string to modify
: @param $delim the delimiter for the words (e.g. a space)
: @return xs:string
: @see http://www.xqueryfunctions.com/xq/functx_camel-case-to-words.html
:)
declare function functx:camel-case-to-words($arg as xs:string?, $delim as xs:string ) as xs:string {
   concat(substring($arg,1,1), replace(substring($arg,2),'(\p{Lu})', concat($delim, '$1')))
};

(:~
: The functx:capitalize-first function capitalizes the first character of $arg. 
: If the first character is not a lowercase letter, $arg is left unchanged. 
: It capitalizes only the first character of the entire string, not the first letter of every word.
: @author Jenny Tennison
: @param $arg the word or phrase to capitalize
: @return xs:string?
: @see http://www.xqueryfunctions.com/xq/functx_capitalize-first.html
:)
declare function functx:capitalize-first($arg as xs:string?) as xs:string? {       
   concat(upper-case(substring($arg,1,1)),
             substring($arg,2))
};
 

(:~
: The <b>retrieve-vra:format-detail-view</b> function returns the detail view of a VRA record.
: @param $entry a VRA record, processed by clean:cleanup() in session.xql.
: @param $collection-short the location of the VRA record, with '/db/' removed.
: @param $position the position of the record displayed with the search results (this parameter is not used).
: @return an XHTML table.
:)
declare function retrieve-vra:format-detail-view($position as xs:string, $entry as element(vra:vra), $collection-short as xs:string, $type as xs:string, $id as xs:string) as element(table) {
    <table xmlns="http://www.w3.org/1999/xhtml" class="biblio-full">
    {
    <tr>
        <td class="collection-label">Record Location</td>
        <td><div class="collection">{replace(replace(uu:unescape-collection-path($collection-short), '^resources/commons/', 'resources/'),'^resources/users/', 'resources/')}</div></td>
    </tr>
    ,
    let $format := concat('VRA'
        , 
        if ($type eq 'i')
        then ' Image'
        else
            if ($type eq 'w')
            then ' Work'
            else ' Collection'
        ,
        ' Record')
    return
        <tr>
            <td class="collection-label">Record Format</td>
            <td>{$format}</td>
        </tr>
    ,
    (: titles :)
    for $title in $entry//vra:titleSet/vra:title
        return
            <tr>
                <td class="collection-label">Title</td>
                <td>{$title/text()}</td>
            </tr>
    ,
    (: agents :)
    for $agent in $entry//vra:agentSet/vra:agent
        let $name := $agent/vra:name
        let $role := $agent/vra:role
        let $role := 
            if ($role) 
            then $role
            else 'Agent'
        return
            <tr>
                <td class="collection-label">{$role}</td>
                <td>{$name/text()}</td>
            </tr>
    ,
    (: subjects :)
    for $subject in $entry//vra:subjectSet/vra:subject
        return
            <tr>
                <td class="collection-label">Subject</td><td>{$subject}</td>
            </tr>
    ,
    (: material :)
    for $material in $entry//vra:materialSet/vra:material
        return
            <tr>
                <td class="collection-label">Material</td><td>{$material}</td>
            </tr>
    ,
    (: technique :)
    for $technique in $entry//vra:techniqueSet/vra:technique
        return
            <tr>
                <td class="collection-label">Technique</td><td>{$technique}</td>
            </tr>
    
    }
    </table>
};

(:~
: The <b>retrieve-vra:format-list-view</b> function returns the list view of a sequence of VRA records.
: @param $entry a VRA record, processed by clean:cleanup().
: @param $collection-short the location of the VRA record, with '/db/' removed
: @param $position the position of the record displayed with the search results (this parameter is not used)
: @param $type the type of the record, 'c', 'w', 'i', for colleciton, work, image.
: @param $id the id of the record.
: @return an XHTML span.
:)
declare function retrieve-vra:format-list-view($position as xs:string, $entry as element(vra:vra), $collection-short as xs:string) as element(span) {
    <span>{$entry//vra:titleSet/vra:title/text()}</span>
};