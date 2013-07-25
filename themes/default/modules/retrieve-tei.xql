module namespace retrieve-tei="http://exist-db.org/tei/retrieve";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mads="http://www.loc.gov/mads/v2";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace functx = "http://www.functx.com";
declare namespace ext="http://exist-db.org/mods/extension";
declare namespace hra="http://cluster-schemas.uni-hd.de";

import module namespace config="http://exist-db.org/mods/config" at "../../../modules/config.xqm";
import module namespace tamboti-common="http://exist-db.org/tamboti/common" at "../../../modules/tamboti-common.xql";
import module namespace tei-common="http://exist-db.org/tei/common" at "../../../modules/tei-common.xql";
import module namespace mods-common="http://exist-db.org/mods/common" at "../../../modules/mods-common.xql";

(:The $retrieve-tei:primary-roles values are lower-cased when compared.:)
declare variable $retrieve-tei:primary-roles := ('aut', 'author', 'cre', 'creator', 'composer', 'cmp', 'artist', 'art', 'director', 'drt');

declare option exist:serialize "media-type=text/xml";

(:~
: The <b>retrieve-tei:format-detail-view</b> function returns the detail view of a VRA record.
: @param $position the position of the record displayed with the search results (this parameter is not used).
: @param $entry
: @param $collection-short the location of the TEI record, with '/db/' removed.
: @param $document-uri 
: @param $node-id 
: @return an XHTML table element.
:)
declare function retrieve-tei:format-detail-view($position as xs:string, $entry as element(), $collection-short as xs:string, $document-uri as xs:string, $node-id as xs:string) as element(table) {
    let $result :=
    <table xmlns="http://www.w3.org/1999/xhtml" class="biblio-full">
    {
    let $collection := replace(replace(xmldb:decode-uri($collection-short), '^resources/commons/', 'resources/'),'^resources/users/', 'resources/')
    (:let $log := util:log("DEBUG", ("##$collection): ", $collection)):)
    return
    <tr>
        <td class="collection-label">Record Location</td>
        <td><div class="collection">{$collection}</div></td>
    </tr>
    ,
    let $format := 'TEI Record'
    return
        <tr>
            <td class="collection-label">Record Format</td>
            <td>{$format}</td>
        </tr>
    ,
    let $title := doc($document-uri)/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[1]
    let $document-uri := replace($document-uri, '/db/resources/commons/encyclopedia/', '/db/matumi/data/')
    let $matumi-link := concat('http://kjc-sv006.kjc.uni-heidelberg.de:8080/exist/apps/matumi/entry.html?doc=', $document-uri, '&amp;node=', $node-id)
    let $entry := 
        if ($entry instance of element(tei:TEI) or $entry instance of element(tei:head) or $entry instance of element(tei:div)) 
        then <p>The document is too large to be retrieved. Please access the document in <a href="{$matumi-link}" target="_blank">Matumi</a> or make a search targeting a specific field in Tamboti.</p> 
    else $entry
    (:let $log := util:log("DEBUG", ("##$entry): ", $entry)):)
    return
        <tr>
            <td class="collection-label">Title</td>
            <td>{$title/string()}</td>
        </tr>
        ,
        <tr>
            <td class="collection-label">Text</td>
            <td>
                <span>{tei-common:render($entry)}</span>
                </td>
        </tr>
        ,
        let $document-uri := replace($document-uri, '/db/resources/commons/encyclopedia/', '/db/matumi/data/')
        let $matumi-link := concat('/exist/apps/matumi/entry.html?doc=', $document-uri, '&amp;node=', $node-id)
        (:let $log := util:log("DEBUG", ("##$matumi-link): ", $matumi-link)):)
        return
        <tr>
            <td class="collection-label">Link to Whole Text</td>
            <td>
                <span><a href="{$matumi-link}" target="_blank">Matumi</a></span>
                </td>
        </tr>
        
    }
    </table>
    let $highlight := function($string as xs:string) { <span class="highlight">{$string}</span> }
    let $regex := session:get-attribute('regex')
    let $result := 
        if ($regex) 
        then tamboti-common:highlight-matches($result, $regex, $highlight) 
        else $result
    let $result := mods-common:clean-up-punctuation($result)
    return
        $result
};

(:~
: The <b>retrieve-tei:format-list-view</b> function returns the list view of a sequence of VRA records.
: @param $entry a VRA record, processed by clean:cleanup().
: @param $collection-short the location of the VRA record, with '/db/' removed
: @param $position the position of the record displayed with the search results (this parameter is not used)
: @param $type the type of the record, 'c', 'w', 'i', for colleciton, work, image.
: @param $id the id of the record.
: @return an XHTML span.
:)
declare function retrieve-tei:format-list-view($position as xs:string, $entry as element(), $collection-short as xs:string, $document-uri as xs:string, $node-id as xs:string) as element(span) {
    (:<span>{$entry/tei:teiHeader[1]/tei:fileDesc[1]/tei:titleStmt[1]/tei:title[1]/text()}</span>:)
    (:<span>{$entry/ancestor-or-self::tei:TEI/tei:teiHeader[1]/tei:fileDesc[1]/tei:titleStmt[1]/tei:title[1]/text()}</span>:)
    let $title := doc($document-uri)/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[1]
    let $entry := 
        if ($entry instance of element(tei:TEI)) 
        then <p>The whole document is being retrieved. Please perform your search inside Matumi or make a search targeting a specific field in Tamboti.</p> else $entry
    (:let $log := util:log("DEBUG", ("##$document-uri): ", $document-uri)):)
    (:let $log := util:log("DEBUG", ("##$node-id): ", $node-id)):)

    let $result :=
    <div>
    <span>{$title/string()}</span>
    <span>{tei-common:render($entry)}</span>
    </div>
    let $highlight := function($string as xs:string) { <span class="highlight">{$string}</span> }
    let $regex := session:get-attribute('regex')
    let $result := 
        if ($regex) 
        then tamboti-common:highlight-matches($result, $regex, $highlight) 
        else $result
    let $result := mods-common:clean-up-punctuation($result)
    return
        $result
};