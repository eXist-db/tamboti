module namespace mods-common="http://exist-db.org/mods/common";

declare namespace mods="http://www.loc.gov/mods/v3";
declare namespace mads="http://www.loc.gov/mads/v2";
declare namespace functx="http://www.functx.com";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace ext="http://exist-db.org/mods/extension";

import module namespace retrieve-mods="http://exist-db.org/mods/retrieve" at "../themes/default/modules/retrieve-mods.xql";
import module namespace config="http://exist-db.org/mods/config" at "../themes/default/modules/retrieve-mods.xql";

declare variable $mods-common:given-name-first-languages := ('eng', 'fre', 'ger', 'ita', 'por', 'spa');
declare variable $mods-common:no-word-space-languages := ('chi', 'jpn', 'kor');

(:
Formatting functions:
mods-common:clean-up-punctuation()
mods-common:simple-row()
mods-common:add-part()
mods-common:serialize-list()
mods-common:remove-parent-with-missing-required-node()
functx:capitalize-first()
functx:camel-case-to-words()
functx:trim()

Name-related functions:
mods-common:retrieve-names()
mods-common:format-name()
mods-common:get-name-order()
mods-common:get-role-label-for-list-view()
mods-common:format-multiple-names()
mods-common:retrieve-name()
mods-common:retrieve-mads-names()    
mods-common:names-full()
mods-common:get-roles-for-detail-view()
mods-common:get-role-terms-for-detail-view()
mods-common:get-role-term-label-for-detail-view()

Language-related function:
mods-common:get-language-label()
mods-common:get-script-label()

Subject-related functions:
mods-common:format-subjects()

Title-related functions:
mods-common:get-short-title()

Related Items-related functions:
mods-common:format-related-item()

Place, Date, Extent-related functions:
mods-common:get-part-and-origin()
mods-common:get-publisher()
mods-common:get-place()
mods-common:get-date()
mods-common:get-extent()

Related Items-related functions:
mods-common:get-related-items()


:)


(:~
: Used to clean up unintended sequences of punctuation. These should ideally be removed at the source.   
: @param
: @return
:)
(: Function to clean up unintended punctuation. These should ideally be removed at the source. :)
declare function mods-common:clean-up-punctuation($element as node()) as node() {
	element {node-name($element)}
		{$element/@*,
			for $child in $element/node()
			return
				if ($child instance of text())
				then 
					replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(
						($child)
					(:, '\s*\)', ')'):) (:, '\s*;', ';'):) (:, ',,', ','):) (:, '”\.', '.”'):) (:, '\. ,', ','):) (:, ',\s*\.', ''):) (:,'\.\.', '.'):) (:,'\.”,', ',”'):)
					, '\s*\.', '.')
					, '\s*,', ',')
					, ' :', ':')
					, ' ”', '”')
					, '\.\.', '.')
					, '“ ', '“')
					, '\?\.', '?')
					, '!\.', '!')
					,'\.”\.', '.”')
					,' \)', ')')
					,'\( ', '(')
					, '\.,', ',')
					, '\?:', '?')
					, '\?', '?')
				else mods-common:clean-up-punctuation($child)
      }
};

(:~
: Prepares one or more rows for the detail view.
:
: @author Wolfgang M. Meier
: @param $data
: @param $label
: @return element(tr)
:)
declare function mods-common:simple-row($data as item()?, $label as xs:string) as element(tr)? {
    for $d in $data
    return
        <tr xmlns="http://www.w3.org/1999/xhtml">
            <td class="label">{$label}</td>
            <td class="record">{$d}</td>
        </tr>
};

(:~
: Joins parts.
:
: @author Wolfgang M. Meier
: @param $part
: @param $sep
: @return element(tr)
:)
declare function mods-common:add-part($part, $sep as xs:string?) {
    (:If there is no part or if the first part there is has no string contents.:)
    if (empty($part) or not(string($part[1]))) 
    then ()
    else concat(string-join($part, ' '), $sep)
};


(:~
: Serialises lists according to Oxford/Harvard comma rule. 
: One item is rendered as it is; two items have an ' and ' inserted in between them, 
: three or more items have ', and ' before the last item and ', ' before the rest, except the first.
:
: @author Wolfgang M. Meier
: @author Jens Østergaard Petersen
: @param $sequence A sequence of names or labels
: @param $sequence-count The count of this sequence (also used by the calling function)
: @return A string
:)
declare function mods-common:serialize-list($sequence as item()+, $sequence-count as xs:integer) as xs:string {       
    if ($sequence-count eq 1)
        then $sequence
        else
            if ($sequence-count eq 2)
            then concat(
                subsequence($sequence, 1, $sequence-count - 1),
                (:Places " and " before last item.:)
                ' and ',
                $sequence[$sequence-count]
                )
            else concat(
                (:Places ", " after all items that do not come last.:)
                string-join(subsequence($sequence, 1, $sequence-count - 1)
                , ', ')
                ,
                (:Places ", and " before item that comes last.:)
                ', and ',
                $sequence[$sequence-count]
                )
};

(:~
: The <em>mods-common:remove-parent-with-missing-required-node</em> function 
: removes titleIfo, name and relatedItem elements that do not contain children required by the respective elements. 
: @param $node A MODS element, either mods:mods or mods:relatedItem.
: @return The same element, with elements removed that do not have the required children.
:)
declare function mods-common:remove-parent-with-missing-required-node($node as node()) as node() {
element {node-name($node)} 
{
for $element in $node/*
return
    if ($element instance of element(mods:titleInfo) and not($element/mods:title/text())) 
    then ()
    else
        if ($element instance of element(mods:name) and not($element/mods:namePart/text()))
        then ()
        else
            if ($element instance of element(mods:relatedItem))
            then 
            	if (not($element/mods:titleInfo/mods:title/text() or $element/@xlink:href/string()))
            	then ()
            	else $element
	        else $element
}
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
declare function functx:capitalize-first($arg as xs:string?) as xs:string {       
   concat(upper-case(substring($arg,1,1)), substring($arg,2))
};

(:~
: The functx:camel-case-to-words function turns a camel-case string 
: (one that uses upper-case letters to start new words, as in "thisIsACamelCaseTerm"), 
: and turns them into a string of words using a space or other delimiter.
: Used to transform the camel-case names of MODS elements into space-separated words.
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
: The functx:trim function removes whitespace at the beginning and end of a string. 
: Unlike the built-in fn:normalize-space function, it only removes leading and trailing whitespace, 
: not whitespace in the middle of the value. 
: Whitespace is defined as it is in XML, namely as space, tab, carriage return and line feed characters. 
: If $arg is the empty sequence, it returns a zero-length string.
: @author Jenny Tennison
: @param $arg the string to trim
: @return A string
: @see http://www.xqueryfunctions.com/xq/functx_trim.html
:)
declare function functx:trim($arg as xs:string?) as xs:string {       
   replace(replace($arg,'\s+$',''),'^\s+','')
};
 
(:~
: The <b>mods-common:title-full</b> function returns 
: a full title for detail view.
: The function seeks to approach the Chicago style.
:
: @author Wolfgang M. Meier
: @author Jens Østergaard Petersen
: @see http://www.loc.gov/standards/mods/userguide/titleinfo.html
: @see http://www.loc.gov/standards/mods/userguide/relateditem.html
: @see http://www.loc.gov/standards/mods/userguide/subject.html#titleinfo
: @param $titleInfo A MODS titleInfo element
: @return The titleInfo formatted as XHTML.
:)
declare function mods-common:title-full($titleInfo as element(mods:titleInfo)) as element() {
let $transliteration := $titleInfo/@transliteration
let $global-transliteration := $titleInfo/../mods:extension/ext:transliterationOfResource
let $type := $titleInfo/@type
let $type := 
    if (not($type))
    then ()
    else
        if ($type eq 'alternative')
        then 'alternative'
        else
            if ($type eq 'uniform')
            then 'uniform'
            else
                if ($type eq 'abbreviated')
                then 'abbreviated'
                else
                    (:First, demand that type is 'translated'; 
                    second, since type 'translated' may also used for transliterations, 
                    demand that it is not the case that there is an explicit transliteration scheme indicated 
                    or that it is not the case that there is an implicit transliteration scheme indicated 
                    (using empty or "unspecified" @transliteration with transliteration scheme indicated in extension).:)
                    if ($type eq 'translated' and (not($transliteration) or ($transliteration = ('', 'unspecified') and $global-transliteration eq ''))) 
                    then 'translated'
                    else
                        (:Either there is explicit indication of transliteration scheme used on the element 
                        or the transliteration scheme used is indicated in the extension 
                        and one of two ways to show that some transliteration scheme is used on the element.:)
                        if (($transliteration/string() and $transliteration ne 'unspecified') or ($transliteration = ('', 'unspecified') and $global-transliteration ne ''))
                        then 'transliterated'
                        else ()
    return
    <tr xmlns="http://www.w3.org/1999/xhtml">
        <!--Left column-->
        <!--Main label-->
        <td class="label">
        {
            if ($type eq 'translated') 
            then 'Translated Title'
            else   
                if ($type eq 'transliterated')
                then 'Transliterated Title'
                else
                    if ($type eq 'alternative') 
                    then 'Alternative Title'
                    else 
                        if ($type eq 'uniform') 
                        then 'Uniform Title'
                        else 
                            (:NB: In retrieve-mods:format-detail-view(), titleInfo with @type eq 'abbreviated' are removed.:) 
                            if ($type eq 'abbreviated') 
                            then 'Abbreviated Title'
                            (:Default value, if no type is indicated.:)
                            else 'Title'
        }
        <span class="deemph">
        <!--Language sublabel-->
        {
        let $lang := string($titleInfo/@lang)
        let $xml-lang := string($titleInfo/@xml:lang)
        (: Prefer @lang to @xml:lang. :)
        let $lang := if ($lang) then $lang else $xml-lang
        return
            if ($lang)
            then        
                (
                <br/>, 'Language: '
                ,
                mods-common:get-language-label($lang)
                )
            else ()
        }
        <!--Transliteration sublabel-->
        {
        let $transliteration := string($titleInfo/@transliteration)
        let $global-transliteration := $titleInfo/../mods:extension/ext:transliterationOfResource/text()
        (:Prefer local transliteration to global.:)
        let $transliteration := 
        	if ($transliteration)
        	then $transliteration
        	else $global-transliteration
        return
        (:The local transliteration attribute may be empty, so we check if it is there anyway. 
        If it is there, but empty, we use the global value.:)
        if ($titleInfo/@transliteration and $transliteration)
        then
            (<br/>, 'Transliteration: ',
            let $transliteration-label := doc(concat($config:edit-app-root, '/code-tables/transliteration-codes.xml'))/*:code-table/*:items/*:item[*:value eq $transliteration]/*:label
            return
                if ($transliteration-label)
                then $transliteration-label
                else $transliteration
            )
        else
        ()
        }
        </span>
        </td>
        <!--Right column-->
        <td class='record'>
        {
        if ($titleInfo/mods:partNumber | $titleInfo/mods:partName)
        then 
	        concat(
	        concat(
	        concat(
	        	$titleInfo/mods:nonSort, 
	        	' ', 
	        	$titleInfo/mods:title), 
	        		(
	        			if ($titleInfo/mods:subTitle) 
	        			then ': ' 
	        			else ()
	        		), 
	        	string-join($titleInfo/mods:subTitle, '; ')), 
	        	'. ', 
	        	string-join(($titleInfo/mods:partNumber, $titleInfo/mods:partName),
	        	': ')
	        	)
        else 
        	concat(
        	concat(
        	$titleInfo/mods:nonSort, ' ', 
        	$titleInfo/mods:title), 
        		(
        			if ($titleInfo/mods:subTitle) 
        			then ': ' 
        			else ()
        		), 
        	string-join($titleInfo/mods:subTitle, '; '))
        }
        </td>
    </tr>
};


(:~
: The <b>mods-common:get-short-title</b> function returns 
: a compact title for list view, for subject in detail view, and for related items in list and detail view.
: The function seeks to approach the Chicago style.
:
: @author Wolfgang M. Meier
: @author Jens Østergaard Petersen
: @see http://www.loc.gov/standards/mods/userguide/titleinfo.html
: @see http://www.loc.gov/standards/mods/userguide/relateditem.html
: @see http://www.loc.gov/standards/mods/userguide/subject.html#titleinfo
: @param $entry The MODS entry as a whole or a relatedItem element
: @return The titleInfo formatted as XHTML.
:)
declare function mods-common:get-short-title($entry as element()) {
    (: If the entry has a related item of @type host with an extent in part, it is a periodical article or a contribution to an edited volume and the title should be enclosed in quotation marks. :)
    (: In order to avoid having to iterate through the (extremely rare) instances of multiple elements and in order to guard against cardinality errors in faulty records duplicating elements that are supposed to be unique, a lot of filtering for first child is performed. :)
    
    (: The short title only consists of the main title, which is untyped, and its renditions in transliteration and translation. 
    Filter away the remaining titleInfo @type values. 
    This means that a record without an untyped titleInfo will not display any title. :)
    let $titleInfo := $entry/mods:titleInfo[not(@type = ('abbreviated', 'uniform', 'alternative'))]
    
    (: The main title can be 1) in original language and script, or 2) in transliteration, or 3) in translation. 
    Therefore, split titleInfo into these three, reusing $titleInfo for the untyped titleInfo. 
    Since "transliterated" is not a valid value for @type, we have to deduce the existence of a transliterated titleInfo from the fact that it contains @transliteration. 
    Since the Tamboti editor operates with a global setting for transliteration (in extension), 
    it is necessary to mark a transliterated titleInfo in the instances by means of an empty @transliteration. 
    Since in MODS, a transliterated titleInfo has the @type value "translated", we check for this as well. 
    Hence a titleInfo with @type "translated" with be a translation if it has no @transliteration (empty or not); otherwise it will be a transliteration.
    A translated titleInfo ought to have a @lang, but it is not necessary to check for this. :)
    (: NB: Parsing this would be a lot easier if MODS accepted "transliterated" as value for @type on titleInfo. :)
    let $titleInfo-transliterated := $titleInfo[@transliteration][@type eq 'translated'][1]
    let $titleInfo-translated := $titleInfo[not(@transliteration)][@type eq 'translated'][1]
    let $titleInfo := $titleInfo[not(@type)][1]
    
    (: Split each of the three forms into their components. :)
    let $nonSort := $titleInfo/mods:nonSort[1]
    let $title := $titleInfo/mods:title[1]
    let $subTitle := $titleInfo/mods:subTitle[1]
    let $partNumber := $titleInfo/mods:partNumber[1]
    let $partName := $titleInfo/mods:partName[1]
    
    let $nonSort-transliterated := $titleInfo-transliterated/mods:nonSort[1]
    let $title-transliterated := $titleInfo-transliterated/mods:title[1]
    let $subTitle-transliterated := $titleInfo-transliterated/mods:subTitle[1]
    let $partNumber-transliterated := $titleInfo-transliterated/mods:partNumber[1]
    let $partName-transliterated := $titleInfo-transliterated/mods:partName[1]

    let $nonSort-translated := $titleInfo-translated/mods:nonSort[1]
    let $title-translated := $titleInfo-translated/mods:title[1]
    let $subTitle-translated := $titleInfo-translated/mods:subTitle[1]
    let $partNumber-translated := $titleInfo-translated/mods:partNumber[1]
    let $partName-translated := $titleInfo-translated/mods:partName[1]
        
    (: Format each of the three kinds of titleInfo. :)
    let $title-formatted := 
        (
        if (string($nonSort))
        (: NB: This assumes that nonSort is not used in Asian scripts; otherwise we would have to avoid the space by checking the language. :)
        then concat($nonSort, ' ' , $title)
        else $title
        , 
        if (string($subTitle)) 
        then concat(': ', $subTitle)
        else ()
        ,
        if ($partNumber/text() or $partName/text())
        then
            if ($partNumber/text() and $partName/text()) 
            then concat('. ', $partNumber/text(), ': ', $partName/text())
            else
                if ($partNumber/text())
                then concat('. ', $partNumber/text())
                else concat('. ', $partName/text())
            		
        else ()
        )
    let $title-formatted := string-join($title-formatted, '')
    
    let $title-transliterated-formatted := 
        (
        if ($nonSort-transliterated) 
        then concat($nonSort-transliterated, ' ' , $title-transliterated)
        else $title-transliterated
        , 
        if ($subTitle-transliterated) 
        then concat(': ', $subTitle-transliterated)
        else ()
        ,
        if ($partNumber-transliterated/text() or $partName-transliterated/text())
        then
            if ($partNumber-transliterated/text() and $partName-transliterated/text()) 
            then concat('. ', $partNumber-transliterated/text(), ': ', $partName-transliterated/text())
            else
                if ($partNumber-transliterated/text())
                then concat('. ', $partNumber-transliterated/text())
                else concat('. ', $partName-transliterated/text())
        else ()
        )
    let $title-transliterated-formatted := string-join($title-transliterated-formatted, '')    
    
    let $title-translated-formatted := 
        (
        if ($nonSort-translated) 
        then concat($nonSort-translated, ' ' , $title-translated)
        else $title-translated
        , 
        if ($subTitle-translated) 
        then concat(': ', $subTitle-translated)
        else ()
        ,
        if ($partNumber-translated/text() or $partName-translated/text())
        then
            if ($partNumber-translated/text() and $partName-translated/text()) 
            then concat('. ', $partNumber-translated/text(), ': ', $partName-translated/text())
            else
                if ($partNumber-translated/text())
                then concat('. ', $partNumber-translated/text())
                else concat('. ', $partName-translated/text())
        else ()
        )
    let $title-translated-formatted := string-join($title-translated-formatted, '')
    
    (: Assemble the full short title to display. :)    
    return
        ( 
		if ($title-transliterated)
		(: It is standard (at least in Sinology and Japanology) to first render the transliterated title, then the title in native script. :)
        then (<span xmlns="http://www.w3.org/1999/xhtml" class="title">{$title-transliterated-formatted}</span>, ' ')
        else ()
        , 
        if ($title-transliterated)
        (: If there is a transliterated title, the title in original script should not be italicised. :)
        then <span xmlns="http://www.w3.org/1999/xhtml" class="title-no-italics">{$title-formatted}</span>
        else
        (: If there is no transliterated title, the standard for Western literature. :)
        	if (exists($entry/mods:relatedItem[@type eq 'host'][1]/mods:part/mods:extent[1]) 
        	   or exists($entry/mods:relatedItem[@type eq 'host'][1]/mods:part[1]/mods:detail[1]/mods:number[1]) 
        	   (: NB: Faulty Zotero export has mods:text here; delete when Zotero has corrected this. :)
        	   or exists($entry/mods:relatedItem[@type eq 'host'][1]/mods:part[1]/mods:detail[1]/mods:text[1]))
    	   then <span xmlns="http://www.w3.org/1999/xhtml" class="title-no-italics">“{$title-formatted}”</span>
    	   else <span xmlns="http://www.w3.org/1999/xhtml" class="title">{$title-formatted}</span>
        ,
        if ($title-translated)
        (: Enclose the translated title in parentheses. Titles of @type "translated" are always made by the cataloguer. 
        If a title is translated on the title page, this is recorded as a titleInfo of @type "alternative". :)
        then <span xmlns="http://www.w3.org/1999/xhtml" class="title-no-italics"> ({$title-translated-formatted})</span>
        else ()
        )
};

(:~
: The <b>mods-common:format-location</b> function returns 
: the location of a publication, for display in detail view (except the URL, which is separately formatted).
:
: @see http://www.loc.gov/standards/mods/userguide/location.html#url
: @param $location The MODS location element minus the url child
: @return The location as XHTML a element.
:)
declare function mods-common:format-location($location as element(mods:location), $collection-short as xs:string) as xs:string {
    let $location := $location[not(url)][mods:physicalLocation]
    let $physical-location := $location/mods:physicalLocation
    let $shelf-locator := $location/mods:holdingSimple/mods:copyInformation/mods:shelfLocator
    return 
        concat($physical-location, if ($shelf-locator) then ': ' else (), $shelf-locator)
};


(:~
: The <b>mods-common:format-url</b> function returns 
: a the URL of a publication, for display in detail view.
: Special formatting is provided for image collections.
:
: @see http://www.loc.gov/standards/mods/userguide/location.html#url
: @param $url The MODS url element
: @return The url as XHTML a element.
:)
declare function mods-common:format-url($url as element(mods:url), $collection-short as xs:string) as element() {
let $url := 
    if ($url/@access eq 'preview')
    (:Special formatting for image collections.:)
    then concat('images/',$collection-short,'/',$url,'?s',$config:url-image-size) 
    else $url
let $url-for-display := 
    if ((string-length($url) le 70))
    then $url
    (:avoid too long urls that do not line-wrap:)
    else (substring($url, 1, 70), '...') 
return 
    <a href="{$url}" target="_blank">{$url-for-display}</a>
};



(:~
: The <b>mods-common:get-language-label</b> function returns 
: the <b>human-readable label</b> of the language value passed to it.  
: This value can set in many MODS elements and attributes. 
: The language-string can have two types, text and code.
: Type code can use two different authorities, 
: recorded in the code tables language-2-type-codes.xml and language-3-type-codes.xml, 
: as well as the authority valueTerm noted in language-3-type-codes.xml.
: The function disregards the two types and the various authorities and proceeds by brute force, 
: checking the more common code types first to let the function exit quickly.
: The function returns the human-readable label, based on consecutive searches in the code values and in the label.
:
: @author Jens Østergaard Petersen
: @see http://www.loc.gov/standards/mods/userguide/generalapp.html#top_level
: @see http://www.loc.gov/standards/mods/userguide/language.html
: @param $language-string The string value of an attribute or element recording the language used within a certain element or in the MODS record as a whole, in textual or coded form
: @return $language-label A human-readable language label
:)
declare function mods-common:get-language-label($languageTerm as xs:string) as xs:string* {
        let $language-label :=
            let $language-label := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[value eq $languageTerm]/label
            return
                if ($language-label)
                then $language-label
                else
                    let $language-label := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[valueTwo eq $languageTerm]/label
                    return
                        if ($language-label)
                        then $language-label
                        else
                            let $language-label := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[valueTerm eq $languageTerm]/label
                            return
                                if ($language-label)
                                then $language-label
                                else
                                    let $language-label := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[upper-case(label) eq upper-case($languageTerm)[1]]/label
                                    return
                                        if ($language-label)
                                        then $language-label
                                        else
                                            let $language-label := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[upper-case(label) eq upper-case($languageTerm)]/label
                                            return
                                                if ($language-label)
                                                then $language-label
                                                else concat($languageTerm, ' (unidentified)')
        return $language-label
};

(:~
: The <b>mods-common:get-script-label</b> function returns 
: the <b>human-readable label</b> of the script value passed to it.
: This value can set in many MODS elements and attributes. 
: The language-string can have two types, text and code.
:
: @author Jens Østergaard Petersen 
: @see http://www.loc.gov/standards/mods/userguide/generalapp.html#top_level
: @see http://www.loc.gov/standards/mods/userguide/language.html
: @param $scriptTerm The string value of an element or attribute recording a script, in textual or coded form
: @return $script-label A human-readable script label
:)
declare function mods-common:get-script-label($scriptTerm as xs:string) as xs:string* {
        let $scriptTerm-upper-case := upper-case($scriptTerm)

        let $script-label :=
            let $script-label := doc(concat($config:edit-app-root, '/code-tables/script-codes.xml'))/code-table/items/item[upper-case(value) eq $scriptTerm-upper-case]/label
            return
                if ($script-label)
                then $script-label
                else 
                    let $script-label := doc(concat($config:edit-app-root, '/code-tables/script-codes.xml'))/code-table/items/item[upper-case(label) eq $scriptTerm-upper-case]/label
                    return
                        if ($script-label)
                        then $script-label
                        else concat($scriptTerm, ' (unidentified)')
        return $script-label
};


(: Retrieves names. :)
(: Called from mods-common:format-multiple-names() :)
(:~
: The <b>mods-common:retrieve-names</b> function returns 
: a a sequence of names to be passed to mods-common:retrieve-name().  
: The function seeks to approach the Chicago style.
:
: @author Wolfgang M. Meier
: @author Jens Østergaard Petersen
: @see http://www.loc.gov/standards/mods/userguide/name.html
: @param $entry The MODS element or relatedItem element
: @param $destination The function that calls the format-name function passes here the values 'detail', 'list', or 'list-first' according to its destination
: @param $global-transliteration The value set for the transliteration scheme to be used in the record as a whole, set in ext:extension
: @param $global-language The value set for the language of the resource catalogued, set in language/languageTerm
: @return The name formatted as XHTML.
:)
declare function mods-common:retrieve-names(
        $entry as element()*, $destination as xs:string, 
        $global-transliteration as xs:string?, $global-language as xs:string?) {
    for $name at $position in $entry/mods:name
    return
    <span xmlns="http://www.w3.org/1999/xhtml" class="name">{mods-common:retrieve-name($name, $position, $destination, $global-transliteration, $global-language)}</span>
};

(:~
: The <b>mods-common:format-name</b> function returns 
: a formatted name. The function returns the name as it appears in first place in a list of names, with family name first, 
: and as it appears elsewhere, with given name first. The case of names in a script that is also transliterated is covered.
: If the name has an authoritative form according to a MADS record, this form is rendered.
: The function seeks to approach the Chicago style.
: The namespace is masked because it refers to both the MODS and the mads prefix.
:
: @author Wolfgang M. Meier
: @author Jens Østergaard Petersen
: @see http://www.loc.gov/standards/mods/userguide/name.html
: @see http://www.loc.gov/standards/mads/
: @param $name The MODS name element as it appears as a top level element or as an element elsewhere
: @param $position The position of the name in a list of names
: @param $destination The function that calls the format-name function passes here the values 'detail', 'list', or 'list-first' according to its destination
: @param $global-transliteration The value set for the transliteration scheme to be used in the record as a whole, set in ext:extension
: @param $global-language The value set for the language of the resource catalogued, set in language/languageTerm
: @return The name formatted as XHTML.
:)
declare function mods-common:format-name($name as element()?, $position as xs:integer, $destination as xs:string, $global-transliteration as xs:string?, $global-language as xs:string?) {	
    (: Get the type of the name, personal, corporate, conference, or family. :)
    let $name-language := $name/@lang
    let $name-type := $name/@type
    return   
    (: If the name is of type conference, do nothing, since get-conference-detail-view and get-conference-hitlist take care of conference. 
        The name of a conference does not occur in the same positions as the other name types.:)
        if ($name-type eq 'conference') 
        then ()
        else
            (: If the name is (erroneously) not typed, there is not anything to go by, 
            so just string-join the transliterated name parts and string-join the untransliterated nameParts. :)
            (: NB: One could also decide to treat it as a personal name, since there are most of these. :)
            if (not($name-type))
            then
                concat(
                    string-join($name/*:namePart[exists(@transliteration)], ' ')
                    , ' ', 
                    string-join($name/*:namePart[not(@transliteration)], ' ')
                )
            else
                (: If the name is of type corporate, i.e. if we are dealing with an institution, there is also not much we can do; 
                we must assume that the sequence of name parts is meaningfully constructed, 
                e.g. with the more general term first, and we just string-join the different parts, dividing them with a comma. :)
                if ($name-type eq 'corporate') 
                then
                    concat(
                        string-join(
                        	for $item in $name/*:namePart 
                        	where exists($item/@transliteration) 
                        	return $item
                        , ', ')
                        
                        , ' ', 
                        string-join(
                        	for $item in $name/*:namePart 
                        	where not($item/@transliteration) 
                        	return $item
                        , ', ')
                    )
                else
                    (: If a family as such is responsible for a publication, we must assume that all nameParts will describe the family name.
                    so just string-join any nameParts, dividing them with a comma. :)
                    (: NB: This is the same as type corporate, so the two could be merged. :)
                    if ($name-type eq 'family') 
                    then
                        concat(
                            string-join(
                            	for $item in $name/*:namePart 
                            	where exists($item/@transliteration) 
                            	return $item
                            , ', ')
                            
                            , ' ', 
                            string-join(
                            	for $item in $name/*:namePart 
                            	where not($item/@transliteration) 
                            	return $item
                            , ', ')
                        )
                    (: If the name is type personal. This is the last option, the most common one, and also the most complicated. :)        
                    else
                        (: Split up the name parts into three groups: 
                        1. Basic: those that do not have a transliteration attribute and that do not have a script attribute (or have Latin script).
                        2. Transliteration: those that have transliteration and do not have script (or have Latin script, which all transliterations have implicitly).
                        3. Script: those that do not have transliteration, but have script (but not Latin script, which characterises transliterations). :)
                        (: NB: The assumption is that transliteration is always into Latin script, but - obviously - it may e.g. be in Cyrillic script. :)
                        (: If the above three name groups occur, they should be formatted in the sequence of 1, 2, and 3. 
                        Only in rare cases will 1, 2, and 3 occur together (e.g. a Westerner with name form in Chinese characters or a Chinese with an established Western-style name form different from the transliterated name form. 
                        In the case of persons using Latin script to render their name, only 1 will be used. Here we have typical Western names.
                        In the case of e.g. Chinese or Russian names, only 2 and 3 will be used. 
                        Only 3 will be used if no transliteration is given.
                        Only 2 will be used if only a transliteration is given. :)
                        (: When formatting a name, $position is relevant to the formatting of Base, i.e. to Western names, and to Russian names in Script and Transliteration. 
                        Hungarian is special, in that it uses Latin script, but has the name order family-given. :)
                        (: When formatting a name, the first question to ask is whether the name parts are typed, i.e. are divded into given and family name parts (plus date and terms of address). 
                        If they are not, there is really not much one can do, besides concatenating the name parts and trusting that their sequence is meaningful. :)
                        (: NB: If the name is translated from one language to another (e.g. William the Conqueror, Guillaume le Conquérant), there will be two $name-basic, one for each language. This is not handled. :)
                        (: NB: If the name is transliterated in two ways, there will be two $name-in-transliteration, one for each transliteration scheme. This is not handled. :)
                        (: NB: If the name is rendered in two scripts, there will be two $name-in-non-latin-script, one for each script. This is not handled. :)
        				let $name-contains-transliteration :=         					
        					(:We allow the transliteration attribute to be on name itself. 
        					We allow it to be empty, because we use it with $global-transliteration to signal that a name or namePart is transliterated or contains transliteration.:)
        					if ($name[*:namePart[@transliteration]] or $name[@transliteration])
        					then 1
        					else
        						(: If the record as a whole is marked as having transliteration, use this instead.:)
        						if ($global-transliteration)
        						then 1
        						else 0
                        (:let $log := util:log("DEBUG", ("##$name-contains-transliteration): ", $name-contains-transliteration)):)
                        (: If the name does not contain a namePart with transliteration, it is a basic name, 
                        i.e. a name where the distinction between the name in native script and in transliteration does not arise. 
                        Typical examples are Western names, but this also includes Eastern names where no effort has been taken to distinguish between native script and transliteration. 
                        Filtering like this would leave out names where Westerners have Chinese names, and in order to catch these, 
                        we require that they have language set to one of the common European languages. :)
                        (: NB: The whole notion of names being in different languages is problematic. :)
                        (: NB: Only coded language terms are treated here. :)
                        let $name-basic :=
    	                    if (not($name-contains-transliteration))
    	                    (:If we know for sure that no transliteration is used anywhere in the name, then grab the parts in which Western script is used or in which no script is set.:) 
    	                    then <name>{$name/*:namePart[not(@transliteration)][(not(@script) or @script = ('Latn', 'latn', 'Latin'))]}</name>
                        	(:If we know for sure that transliteration is used somewhere in the name, then grab the untransliterated parts.:)
                        	else <name>{$name/*:namePart[(@lang = $mods-common:given-name-first-languages or not(@lang)) and not(@transliteration)]}</name>
                        	(:else <name>{$name/*:namePart[not(@transliteration)]}</name>:)
                        (:let $log := util:log("DEBUG", ("##$name-basic): ", $name-basic)):)
                        (: If there is transliteration, there are nameParts with transliteration. 
                        To filter these, we seek nameParts which contain the transliteration attribute, 
                        even though this may be empty 
                        (this is special to the templates, since they allow the user to set a global transliteration value, 
                        to be applied whereever an empty transliteration attribute occurs) 
                        and which do not contain the script attribute or which have the script attribute set to Latin (defining of transliterations here). :)
                        (: NB: Should English names be filtered away?:)
                        let $name-in-transliteration := 
                        	if ($name-contains-transliteration)
                        	then <name>{$name/*:namePart[@transliteration][(not(@script) or (@script = ('Latn', 'latn', 'Latin')))]}</name>
                        	else ()
                        (:let $log := util:log("DEBUG", ("##$name-in-transliteration): ", $name-in-transliteration)):)
                        (: If there is transliteration, the presumption must be that all nameParts which are not transliterations (and which do not have the language set to a European language) are names in non-Latin script. 
                        We filter for nameParts which do no have the transliteration attribute or have one with no contents, 
                        and which do not have script set to Latin, and which do not have English as their language. :)
                        let $name-in-non-latin-script := 
    	                    if ($name-contains-transliteration)
    	                    then <name>{$name/*:namePart[(not(@transliteration) or not(string(@transliteration)))][(@script)][not(@script = ('Latn', 'latn', 'Latin'))][not(@lang = $mods-common:given-name-first-languages)]}</name>
    	                    else ()
                        (:let $log := util:log("DEBUG", ("##$name-in-non-latin-script): ", $name-in-non-latin-script)):)
                        (:Switch around $name-in-non-latin-script and $name-basic if there is $name-in-transliteration. 
                        This is necessary because $name-in-non-latin-script looks like $name-basic in a record using global language.:) 
                        let $name-in-non-latin-script1 := 
                            if (string($name-basic) and string($name-in-transliteration) and not(string($name-in-non-latin-script))) 
                        	then $name-basic
                        	else $name-in-non-latin-script
                        let $name-basic := 
                        	if (string($name-basic) and string($name-in-transliteration) and not(string($name-in-non-latin-script)))
                        	then ()
                        	else $name-basic
                        let $name-in-non-latin-script := $name-in-non-latin-script1
                        (:let $log := util:log("DEBUG", ("##$name-basic1): ", $name-basic)):)
                        (:let $log := util:log("DEBUG", ("##$name-in-non-latin-script1): ", string($name-in-non-latin-script))):)
                        (: We assume that there is only one date name part in $name-basic. 
                        Date name parts with transliteration and script are rather theoretical. 
                        This date is attached at the end of the name, to distinguish between identical names. That is why it is set here, not below. :)
                        let $date-basic := $name-basic/*:namePart[@type eq 'date']
                        return
                            concat(
                            (: ## 1 ##:)
                            if (string($name-basic))
                            (: If there are one or more name parts that are not marked as being transliteration and that are not marked as being in a certain script (aside from Latin). :)
                            then
                            (: Filter the name parts according to type. :)
                                let $family-name-basic := <name>{$name-basic/*:namePart[@type eq 'family']}</name>
                                let $given-name-basic := <name>{$name-basic/*:namePart[@type eq 'given']}</name>
                                let $termsOfAddress-basic := <name>{$name-basic/*:namePart[@type eq 'termsOfAddress']}</name>
                                let $untyped-name-basic := <name>{$name-basic/*:namePart[not(@type)]}</name>
                                (: $date-basic already has the date. :)
                                (: To get the name order, get the language of the namePart and send it to mods-common:get-name-order(), along with higher-level language values. :)
                                let $language-basic := 
                                    if ($family-name-basic/*:namePart/@lang)
                                    then $family-name-basic/*:namePart/@lang
                                    else
                                        if ($given-name-basic/*:namePart/@lang)
                                        then $given-name-basic/*:namePart/@lang
                                        else
                                            if ($termsOfAddress-basic/*:namePart/@lang)
                                            then $termsOfAddress-basic/*:namePart/@lang
                                            else
                                                if ($untyped-name-basic/*:namePart/@lang)
                                                then $untyped-name-basic/*:namePart/@lang
                                                else ()
                                (:let $log := util:log("DEBUG", ("##$language-basic): ", $language-basic)):)
                                let $nameOrder-basic := mods-common:get-name-order(distinct-values($language-basic), distinct-values($name-language), $global-language)
                                (:let $log := util:log("DEBUG", ("##$nameOrder-basic): ", $nameOrder-basic)):)
                                return
                                    if (string($untyped-name-basic))
                                    (: If there are name parts that are not typed, there is nothing we can do to order their sequence. 
                                    When name parts are not typed, it is generally because the whole name occurs in one name part, 
                                    pre-formatted for display (usually with a comma between family and given name), 
                                    but a name part may also be untyped when (non-Western) names that cannot (easily) be divided into family and given names are in evidence. 
                                    We trust that any sequence of untyped nameparts are meaningfully ordered and simply string-join them. :)
                                    then string-join($untyped-name-basic/*:namePart, ' ') 
                                    else
                                    (: If the name parts are typed, we have a name divided into given and family name (and so on), 
                                    a name that is not a transliteration and that is not in a non-Latin script, i.e. an ordinary "Western" name. :)
                                        if ($position eq 1 and $destination eq 'list-first')
                                        (: If the name occurs first in author position in list view 
                                        and the name is not a name that occurs in family-given sequence (it is not an Oriental or a Hungarian name), 
                                        then format it with a comma and space between the family name and the given name, 
                                        with the family name placed first, and append the term of address. :)
                                        (: Dates are appended last, once for the whole name. :)
                                        (: Example: "Freud, Sigmund, Dr. (1856-1939)". :)
                                        then
                                            concat
                                            (
                                                (: There may be several instances of the same type of name part; these are joined with a space in between. :)
                                                string-join($family-name-basic/*:namePart, ' ') 
                                                ,
                                                if (string($family-name-basic) and string($given-name-basic))
                                                (: If only one of family and given are evidenced, no comma is needed. :)
                                                then
                                                    if ($nameOrder-basic eq 'family-given')
                                                    then ' '
                                                    else ', '
                                                else ()
                                                ,
                                                string-join($given-name-basic/*:namePart, ' ') 
                                                ,
                                                if (string($termsOfAddress-basic))
                                                (: If there are several terms of address, join them with a comma in between ("Dr., Prof."). :)
                                                then concat(', ', string-join($termsOfAddress-basic/*:namePart, ', ')) 
                                                else ()
                                            )
                                        else
                                            if ($nameOrder-basic eq 'family-given')
                                            (: If the name is Hungarian and does not occur in list-first position. :)
                                            then 
                                                concat
                                                (
                                                    string-join($family-name-basic/*:namePart, ' ') 
                                                    ,
                                                    if (string($family-name-basic) and string($given-name-basic))
                                                    then 
                                                        if ($language-basic eq 'hun')
                                                        then ' '
                                                        else ''
                                                    else ()
                                                    ,
                                                    string-join($given-name-basic/*:namePart, ' ') 
                                                    ,
                                                    if (string($termsOfAddress-basic))
                                                    (: NB: Where do terms of address go in Hungarian? :)
                                                    then concat(', ', string-join($termsOfAddress-basic/*:namePart, ', ')) 
                                                    else ()
                                                )
                                            else
                                            (: In all other situations, the name order is given-family, with a space in between. :)
                                            (: Example: "Dr. Sigmund Freud (1856-1939)". :)
                                                        concat
                                                        (
                                                            if (string($termsOfAddress-basic))
                                                            then concat(string-join($termsOfAddress-basic/*:namePart, ', '), ' ')
                                                            else ()
                                                            ,
                                                            string-join($given-name-basic/*:namePart, ' ')
                                                            ,
                                                            if (string($family-name-basic) and string($given-name-basic))
                                                            then ' '
                                                            else ()
                                                            ,
                                                            string-join($family-name-basic/*:namePart, ' ')
                                                        )
                            (: If there is no $name-basic, output nothing. :)
                            else ()
                            ,
                            (: Add a space. :)
                            ' '
                            , 
                            (: ## 2 ##:)
                            (: If there is a "European" name and an Eastern name, enclose the transliterated and Eastern script name in parenthesis. :)
                            (:Is there a Western name?:)
                            if ($name/*:namePart[not(@type eq 'date')][@lang = $mods-common:given-name-first-languages or not(@lang)])
                            then
                                (:Is there an Eastern name?:)
                                if ($name/*:namePart[not(@type eq 'date')][@lang != $mods-common:given-name-first-languages])
                                then ' ('
                                else ()
                            else ()
                            ,
                            if (string($name-in-transliteration))
                            (: If we have a name in transliteration, e.g. be a Chinese name or a Russian name, filter the name parts according to type. :)
                            then
                                let $untyped-name-in-transliteration := <name>{$name-in-transliteration/*:namePart[not(@type)]}</name>
                                let $family-name-in-transliteration := <name>{$name-in-transliteration/*:namePart[@type eq 'family']}</name>
                                let $given-name-in-transliteration := <name>{$name-in-transliteration/*:namePart[@type eq 'given']}</name>
                                let $termsOfAddress-in-transliteration := <name>{$name-in-transliteration/*:namePart[@type eq 'termsOfAddress']}</name>
                                (: To get the name order, get the language of the namePart and send it to mods-common:get-name-order(), along with higher-level language values. :)
                                let $language-in-transliteration := 
                                    if ($family-name-in-transliteration/*:namePart/@lang)
                                    then $family-name-in-transliteration/*:namePart/@lang
                                    else
                                        if ($given-name-in-transliteration/*:namePart/@lang)
                                        then $given-name-in-transliteration/*:namePart/@lang
                                        else
                                            if ($termsOfAddress-in-transliteration/*:namePart/@lang)
                                            then $termsOfAddress-in-transliteration/*:namePart/@lang
                                            else
                                                if ($untyped-name-in-transliteration/*:namePart/@lang)
                                                then $untyped-name-in-transliteration/*:namePart/@lang
                                                else ()
                                let $nameOrder-in-transliteration := mods-common:get-name-order($language-in-transliteration, distinct-values($name-language), $global-language)                                
                                return       
                                    (: If there are name parts that are not typed, there is nothing we can do to order their sequence. :)
                                    if (string($untyped-name-in-transliteration))
                                    then string-join($untyped-name-in-transliteration/*:namePart, ' ') 
                                    else
                                    (: If the name parts are typed, we have a name that is a transliteration and that is divided into given and family name. 
                                    If the name order is family-given, we have an ordinary Oriental name in transliteration, 
                                    if the name order is given-family, we have e.g. a Russian name in transliteration. :)
                                        if ($position eq 1 and $destination eq 'list-first' and $nameOrder-in-transliteration ne 'family-given')
                                        (: If the name occurs first in list view and the name is not a name that occurs in family-given sequence, e.g. a Russian name, format it with a comma between family name and given name, with family name placed first. :)
                                        then
                                        concat(
                                            string-join($family-name-in-transliteration/*:namePart, ' ') 
                                            , 
                                            if (string($family-name-in-transliteration) and string($given-name-in-transliteration))
                                            then ', '
                                            else ()
                                            ,
                                            string-join($given-name-in-transliteration/*:namePart, ' ') 
                                            ,
                                            if (string($termsOfAddress-in-transliteration)) 
                                            then concat(', ', string-join($termsOfAddress-in-transliteration/*:namePart, ', ')) 
                                            else ()
                                        )
                                        else
                                        (: In all other situations, the name order is given-family; 
                                        the difference is whether there is a space between the name parts and the order of name proper and the address. :)
                                            if ($nameOrder-in-transliteration ne 'family-given')
                                            (: If it is e.g. a Russian name. :)
                                            then
                                                concat(
                                                    if (string($termsOfAddress-in-transliteration)) 
                                                    then concat(', ', string-join($termsOfAddress-in-transliteration/*:namePart, ', ')) 
                                                    else ()
                                                    ,
                                                    string-join($given-name-in-transliteration/*:namePart, ' ')
                                                    ,
                                                    if (string($family-name-in-transliteration) and string($given-name-in-transliteration))
                                                    then ' '
                                                    else ()
                                                    ,
                                                    string-join($family-name-in-transliteration/*:namePart, ' ')
                                                )
                                            else
                                            (: If it is e.g. a Chinese or a Japanese name. :)
                                                concat(
                                                    string-join($family-name-in-transliteration, '')
                                                    ,
                                                    if (string($family-name-in-transliteration) and string($given-name-in-transliteration))
                                                    then ' '
                                                    else ()
                                                    ,
                                                    string-join($given-name-in-transliteration, '')
                                                    ,
                                                    if (string($termsOfAddress-in-transliteration)) 
                                                    then concat(' ', string-join($termsOfAddress-in-transliteration/*:namePart, ' ')) 
                                                    else ()
                                                )
                                else ()
                                , ' ',
                                (: ## 3 ##:)
                                    if (string($name-in-non-latin-script))
                                    then
                                        let $untyped-name-in-non-latin-script := <name>{$name-in-non-latin-script/*:namePart[not(@type)]}</name>
                                        let $family-name-in-non-latin-script := <name>{$name-in-non-latin-script/*:namePart[@type eq 'family']}</name>
                                        let $given-name-in-non-latin-script := <name>{$name-in-non-latin-script/*:namePart[@type eq 'given']}</name>
                                        let $termsOfAddress-in-non-latin-script := <name>{$name-in-non-latin-script/*:namePart[@type eq 'termsOfAddress']}</name>
                                        let $language-in-non-latin-script := 
                                            if ($family-name-in-non-latin-script/*:namePart/@lang)
                                            then $family-name-in-non-latin-script/*:namePart/@lang
                                            else
                                                if ($given-name-in-non-latin-script/*:namePart/@lang)
                                                then $given-name-in-non-latin-script/*:namePart/@lang
                                                else
                                                    if ($termsOfAddress-in-non-latin-script/*:namePart/@lang)
                                                    then $termsOfAddress-in-non-latin-script/*:namePart/@lang
                                                    else
                                                        if ($untyped-name-in-non-latin-script/*:namePart/@lang)
                                                        then $untyped-name-in-non-latin-script/*:namePart/@lang
                                                        else ()
                                        let $nameOrder-in-non-latin-script := mods-common:get-name-order($language-in-non-latin-script, distinct-values($name-language), $global-language)
                                        return       
                                            if (string($untyped-name-in-non-latin-script))
                                            (: If the name parts are not typed, there is nothing we can do to order their sequence. When name parts are not typed, it is generally because the whole name occurs in one name part, formatted for display (usually with a comma between family and given name), but it may also be used when names that cannot be divided into family and given names are in evidence. We trust that any sequence of nameparts are meaningfully ordered and string-join them. :)
                                            then string-join($untyped-name-in-non-latin-script, ' ') 
                                            else
                                            (: If the name parts are typed, we have a name that is not a transliteration, 
                                            that is not in a non-Latin script 
                                            and that is divided into given and family name. An ordinary Western name. :)
                                                if ($position eq 1 and $destination eq 'list-first' and $nameOrder-in-non-latin-script ne 'family-given')
                                                (: If the name occurs first in list view and the name is not a name that occurs in family-given sequence, 
                                                format it with a comma between family name and given name, with family name first. :)
                                                then
                                                concat(
                                                    string-join($family-name-in-non-latin-script/*:namePart, ' ')
                                                    , 
                                                    if (string($family-name-in-non-latin-script) and string($given-name-in-non-latin-script))
                                                    then ', '
                                                    else ()
                                                    ,
                                                    string-join($given-name-in-non-latin-script/*:namePart, ' ')
                                                    ,
                                                    if (string($termsOfAddress-in-non-latin-script)) 
                                                    then concat(', ', string-join($termsOfAddress-in-non-latin-script, ', ')) 
                                                    else ()
                                                )
                                                else
                                                    (: If the name does not occur first in first in list view and if the name does not occur in family-given sequence, 
                                                    format it with a space between given name and family name, with given name placed first. 
                                                    This would be the case with Russian names that are not first in author position in the list view. :)
                                                    if ($nameOrder-in-non-latin-script ne 'family-given')
                                                    then
                                                        concat(
                                                            if (string($termsOfAddress-in-non-latin-script))
                                                            then concat(string-join($termsOfAddress-in-non-latin-script, ', '), ' ')
                                                            else ()
                                                            ,
                                                            string-join($given-name-in-non-latin-script/*:namePart, ' ')
                                                            ,
                                                            if (string($family-name-in-non-latin-script) and string($given-name-in-non-latin-script))
                                                            then ' '
                                                            else ()
                                                            ,
                                                            string-join($family-name-in-non-latin-script/*:namePart, ' ')
                                                        )
                                                    else
                                                    (: $nameOrder-in-non-latin-script eq 'family-given'. 
                                                    Here we have e.g. Chinese names which are the same wherever they occur, with no space or comma between given and family name. :)
                                                        concat(
                                                            string-join($family-name-in-non-latin-script, '')
                                                            ,
                                                            string-join($given-name-in-non-latin-script, '')
                                                            ,
                                                            string-join($termsOfAddress-in-non-latin-script, '')
                                                            (:
                                                            ,
                                                            if (string($dateScript))
                                                            then concat(' (', string-join($dateScript, ', ') ,')')
                                                            else ()
                                                            :)
                                                        )
                                    else ()
                                ,     
    	                        (: Close Chinese alias set in beginning of (: ## 2 ##:).:)
    	                        if ($name/*:namePart[not(@type eq 'date')][@lang = $mods-common:given-name-first-languages or not(@lang)])
                                then
                                    if ($name/*:namePart[not(@type eq 'date')][@lang != $mods-common:given-name-first-languages])
                                    then ') '
                                    else ()
                                else ()
    	                        ,
    	                        (: Finish off by giving the dates of the person, in parenthesis.:)
                                if ($date-basic)
                                then concat(' (', $date-basic, ')')
                                else ()
                                )
    };

(:~
: The <b>mods-common:get-name-order</b> function returns 
: 'family-given' for languages in which the family name occurs,
: according to the code-table language-3-type-codes.xml.
: before the given name.
:
: @author Jens Østergaard Petersen
: @param $namePart-language The string value of the @lang attribute on namePart
: @param $name-language The string value of the @lang attribute on name
: @param $global-language The string value of mods/language/languageTerm
: @return $nameOrder The string 'family-given' or the empty string
:)
declare function mods-common:get-name-order($namePart-language as xs:string*, $name-language as xs:string*, $global-language as xs:string?) {
    let $language :=
        (:This appears to be needed if several namePart have @lang and name does not. We assume that they have the same @lang.:)
        if (distinct-values($namePart-language))
            then distinct-values($namePart-language)
            else
                if (distinct-values($name-language))
                then distinct-values($name-language)
                else
                    if ($global-language)
                    then $global-language
                    else ()
    let $nameOrder := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[value eq $language]/nameOrder/text()
    return $nameOrder
};

(:~
: The <em>mods-common:get-role-label-for-list-view</em> function returns 
: the <em>human-readable value</em> of the roleTerm passed to it.
: Whereas mods:get-role-label-for-detail-view returns the author/creator roles that are placed in front of the title in detail view,
: mods:get-role-label-for-detail-view returns the secondary roles that are placed after the title in list view and in relatedItem in detail view.: The value occurs in mods/name/role/roleTerm.
: It can have two types, text and code.
: Type code can use the marcrelator authority, recorded in the code table role-codes.xml.
: The most commonly used values are checked first, letting the function exit quickly.
: The function returns the human-readable label, based on searches in the code values and in the labelSecondary and label values.  
:
: @param $node A mods element or attribute recording a role term value, in textual or coded form
: @return The role term label string
:)
declare function mods-common:get-role-label-for-list-view($roleTerm as xs:string?) as xs:string* {
        let $roleLabel :=
            let $roleLabel := doc(concat($config:edit-app-root, '/code-tables/role-codes.xml'))/code-table/items/item[upper-case(label) eq upper-case($roleTerm)]/labelSecondary
            (: Prefer labelSecondary, since it contains the form presented in the list view output, e.g. "edited by" instead of "editor". :)
            return
                if ($roleLabel)
                then $roleLabel
                else
                    let $roleLabel := doc(concat($config:edit-app-root, '/code-tables/role-codes.xml'))/code-table/items/item[value eq $roleTerm]/labelSecondary
                    return
                        if ($roleLabel)
                        then $roleLabel
                        else
                            let $roleLabel := doc(concat($config:edit-app-root, '/code-tables/role-codes.xml'))/code-table/items/item[upper-case(label) eq upper-case($roleTerm)]/label
                            (: If there is no labelSecondary, take the label. :)
                            return
                                if ($roleLabel)
                                then $roleLabel
                                else
                                    let $roleLabel := doc(concat($config:edit-app-root, '/code-tables/role-codes.xml'))/code-table/items/item[value eq $roleTerm]/label
                                    return
                                        if ($roleLabel)
                                        then $roleLabel
                                            else $roleTerm
                                            (: Do not present default values in case of absence of $roleTerm, since primary roles are not displayed in list view. :)
        return concat($roleLabel, ' ')
};


(:~
: The <b>mods-common:format-multiple-names</b> function returns
: names for list view and for related items. 
: The function is called from two positions. 
: One is for names of authors etc. that are positioned before the title.
: One is for names of editors etc. that are positioned after the title.
: The $destination param marks where the function is called.
: Names that are positioned before the title have the first name with a comma between family name and given name.
: Names that are positioned after the title have a space between given name and family name throughout. 
: The names positioned before the title are not marked explicitly by use of any role terms.
: The role terms that lead to a name being positioned before the title are author and creator.
: The absence of a role term is also interpreted as the attribution of authorship, so a name without a role term will also be positioned before the title.
: @param $entry A mods entry
: @param $destination A string indication whether the name is to be formatted for use in 'list' or 'detail' view 
: @param $global-transliteration The value set for the transliteration scheme to be used in the record as a whole, set in ext:extension
: @param $global-language The value set for the language of the resource catalogued, set in language/languageTerm
: @return The string rendition of the name
:)
declare function mods-common:format-multiple-names($entry as element()*, $destination as xs:string, $global-transliteration as xs:string?, $global-language as xs:string?) as xs:string? {
    let $names := mods-common:retrieve-names($entry, $destination, $global-transliteration, $global-language)
    let $nameCount := count($names)
    let $formatted :=
        if ($nameCount gt 0) 
        then mods-common:serialize-list($names, $nameCount)
        else ()
    return <span xmlns="http://www.w3.org/1999/xhtml" class="name">{normalize-space($formatted)}</span>
};

(:~
: The <b>mods:retrieve-name</b> function returns 
: a name from the mods:name element and/or from the mads:name element.
: genre, hierarchicalGeographic, cartographics, geographicCode, occupation are represented in subtables.
:
: @author Wolfgang M. Meier
: @author Jens Østergaard Petersen
: @param $name A name element in a MODS record
: @param $position The position of the name in a sequence of names
: @param $destination The function that calls the format-name function passes here the values 'detail', 'list', or 'list-first' according to its destination
: @param $global-transliteration The value set for the transliteration scheme to be used in the record as a whole, set in ext:extension
: @param $global-language The string value of mods/language/languageTerm
: @see http://www.loc.gov/standards/mods/userguide/name.html
: @return 
:)
(: NB: also used in search.xql ?:)
(: Each name in the list view should have an authority name added to it in parentheses, if it exists and is different from the name as given in the MODS record. :)
declare function mods-common:retrieve-name($name as element(), $position as xs:int, $destination as xs:string, 
    $global-transliteration as xs:string?, $global-language as xs:string?) {    
    let $mods-name := mods-common:format-name($name, $position, $destination, $global-transliteration, $global-language)
    let $mads-reference := replace($name/@xlink:href, '^#?(.*)$', '$1')
    return
        if ($mads-reference)
        then
            let $mads-record :=
                if (empty($mads-reference)) 
                then ()        
                else collection($config:mads-collection)/mads:mads[@ID eq $mads-reference]/mads:authority
            let $mads-preferred-name :=
                if (empty($mads-record)) 
                then ()
                else mods-common:format-name($mads-record/mads:name, 1, $destination, $global-transliteration, $global-language)
            let $mads-preferred-name-display :=
                if (empty($mads-preferred-name))
                then ()
                else concat(' (', $mads-preferred-name,')')
            return
                if ($mads-preferred-name eq $mods-name)
                then $mods-name
                else concat($mods-name, $mads-preferred-name-display)
        else $mods-name
};

(:~
: The <b>mods-common:retrieve-mads-names</b> function returns
: the preferred name from the MADS authority file by means of xlink:href.    
: @param $name A name element in a MODS record
: @param $position  The position of the name in a list of names
: @param $destination The function that calls the format-name function passes here the values 'detail', 'list', or 'list-first' according to its destination
: @return A string representation of the preferred name.
:)
declare function mods-common:retrieve-mads-names($name as element(), $position as xs:int, $destination as xs:string) as xs:string {    
    let $mads-reference := replace($name/@xlink:href, '^#?(.*)$', '$1')
    let $mads-record :=
        if (empty($mads-reference)) 
        then ()        
        else collection($config:mads-collection)/mads:mads[@ID eq $mads-reference]
    let $mads-preferred-name :=
        if (empty($mads-record)) 
        then ()
        else $mads-record/mads:authority/mads:name
    let $mads-preferred-name-formatted := mods-common:format-name($mads-preferred-name, 1, 'list-first', '', '')
    let $mads-variant-names := $mads-record/mads:variant/mads:name
    let $mads-variant-name-nos := count($mads-record/mads:variant/mads:name)
    let $mads-variant-names-formatted := 
    	string-join(
	    	for $name in $mads-variant-names 
    		return mods-common:format-name($name, 1, 'list-first', '', '')
    	, ', ')
    return
        if ($mads-preferred-name)
        then 
        	concat
        		(
        		' (Preferred Name: ', 
        		$mads-preferred-name-formatted, 
        			if ($mads-variant-name-nos eq 1) 
        			then '; Variant Name: ' 
        			else '; Variant Names: '
        		, 
        		$mads-variant-names-formatted
        		, 
        		')'
        		)
        else ()
};

(:~
: The <b>mods-common:names-full</b> function returns
: the full representation of a name for the detail view.    
: @param $entry A MODS record
: @param $global-transliteration The value set for the transliteration scheme to be used in the record as a whole, set in ext:extension
: @param $global-language The string value of mods/language/languageTerm
: @return A <tr> with the full representation of a name. 
:)
declare function mods-common:names-full($entry as element(), $global-transliteration, $global-language) {
        (: NB: conference? :)
        let $names := $entry/*:name[@type = ('personal', 'corporate', 'family') or not(@type)]
        for $name in $names
        return
                <tr xmlns="http://www.w3.org/1999/xhtml"><td class="label">
                    {
                    mods-common:get-roles-for-detail-view($name)
                    }
                </td><td class="record">
                    {
                    mods-common:format-name($name, 1, 'list-first', $global-transliteration, $global-language)
                    }
                    {
                    if ($name/@xlink:href)
                    then mods-common:retrieve-mads-names($name, 1,'list-first')
                    else ()
                    }</td>
                
                </tr>
};

(:~
: The <em>mods-common:get-roles-for-detail-view()</em> function returns the roles of the name passed to it.
: It is used in mods-common:names-full().
: It sends these to mods-common:get-role-terms-for-detail-view() to obtain the terms used to designate the roles, 
: and for each of these terms a human-readbale label is found by mods-common:get-role-term-label-for-detail-view().
: Whereas mods-common:get-roles-for-detail-view() returns the author/creator roles that are placed in front of the title in detail view,
: mods-common:get-role-label-for-list-view() returns the secondary roles that are placed after the title in list view and in relatedItem in detail view.
:
: @param $name A mods element recording a name, in code or as a human-readable label
: @return The role term label string
:)
declare function mods-common:get-roles-for-detail-view($name as element()*) as xs:string* {
    if ($name/mods:role/mods:roleTerm/text())
    then
        let $distinct-role-labels := distinct-values(mods-common:get-role-terms-for-detail-view($name/mods:role))
        let $distinct-role-labels-count := count($distinct-role-labels)
            return
                if ($distinct-role-labels-count gt 0)
                then
                    mods-common:serialize-list($distinct-role-labels, $distinct-role-labels-count)
                else ()
    else
        (: Supply a default value in the absence of any role term. :)
        if ($name/@type eq 'corporate')
        then 'Corporate Author'
        else 'Author'
};

(:~
: The <em>mods-common:get-role-terms-for-detail-view()</em> function returns the role terms of the roles passed to it.
: It is used in mods-common:get-roles-for-detail-view().
: It sends these to mods-common:get-role-term-label-for-detail-view() to obtain a human-readbale label.
: Whereas mods-common:get-roles-for-detail-view() returns the author/creator roles that are placed in front of the title in detail view,
: mods-common:get-role-label-for-list-view() returns the secondary roles that are placed after the title in list view and in relatedItem in detail view.
: The function returns a sequences of human-readable labels, based on searches in the code values and in the label values.  
:
: @param $element A mods element recording a role
: @return The role term string
:)
declare function mods-common:get-role-terms-for-detail-view($role as element()*) as xs:string* {
    let $roleTerms := $role/mods:roleTerm
    for $roleTerm in distinct-values($roleTerms)
        return
    	    if ($roleTerm)
    	    then mods-common:get-role-term-label-for-detail-view($roleTerm)
    	    else ()
};

(:~
: The <em>mods-common:get-role-term-label-for-detail-view()</em> function 
: returns the <em>human-readable value</em> of the role term passed to it.
: It is used in mods-common:get-role-terms-for-detail-view().
: Type code can use the marcrelator authority, recorded in the code table role-codes.xml.
: The most commonly used values are checked first, letting the function exit quickly.
: The function returns the human-readable label, based on look-ups in the code values and in the label values.  
:
: @param $node A role term value string
: @return The role term label string
:)
declare function mods-common:get-role-term-label-for-detail-view($roleTerm as xs:string?) as xs:string* {        
        let $roleTermLabel :=
            (: Is the roleTerm itself a role label, i.e. is the full form used in the document? :)
            let $roleTermLabel := doc(concat($config:edit-app-root, '/code-tables/role-codes.xml'))/code-table/items/item[upper-case(label) eq upper-case($roleTerm)]/label
            (: Prefer the label proper, since it contains the form presented in the detail view, e.g. "Editor" instead of "edited by". :)
            return
                if ($roleTermLabel)
                then $roleTermLabel
                else
                    (: Is the roleTerm a coded role term? :)
                    let $roleTermLabel := doc(concat($config:edit-app-root, '/code-tables/role-codes.xml'))/code-table/items/item[value eq $roleTerm]/label
                    return
                        if ($roleTermLabel)
                        then $roleTermLabel
                        else $roleTerm
        return  functx:capitalize-first($roleTermLabel)
};


(:~
: The <em>mods-common:get-conference-hitlist()</em> function 
: returns a string consisting of three parts,
: 'Paper presented at' plus the name of the conference plus the date of the presentation.
:
: @param $node A MODS record
: @return A string containing information about which conference a paper was presented and at which date 
:)
declare function mods-common:get-conference-hitlist($entry as element(mods:mods)) as xs:string {
    let $date := 
        (
            string($entry/mods:originInfo[1]/mods:dateIssued[1]), 
            string($entry/mods:part/mods:date[1]),
            string($entry/mods:originInfo[1]/mods:dateCreated[1])
        )
    let $conference := $entry/mods:name[@type eq 'conference']/mods:namePart
    return
    if ($conference) 
    then
        concat('Paper presented at ', 
            mods-common:add-part(string($conference), ', '),
            mods-common:add-part($entry/mods:originInfo[1]/mods:place[1]/mods:placeTerm[1], ', '),
            $date[1]
        )
    else ()
};

declare function mods-common:get-conference-detail-view($entry as element()) {
    (: let $date := ($entry/mods:originInfo/mods:dateIssued/string()[1], $entry/mods:part/mods:date/string()[1],
            $entry/mods:originInfo/mods:dateCreated/string())[1]
    return :)
    let $conference := $entry/mods:name[@type eq 'conference']/mods:namePart
    return
    if ($conference) 
    then
        concat('Paper presented at ', string($conference)
            (: , mods-common:add-part($entry/mods:originInfo/mods:place/mods:placeTerm, ', '), $date:)
            (: no need to duplicate placeinfo in detail view. :)
        )
    else ()
};



(:~
: The <b>mods-common:format-subjects</b> function returns 
: a table-formatted representation of each MODS subject.
: The values for topic, geographic, temporal, titleInfo, name, 
: genre, hierarchicalGeographic, cartographics, geographicCode, occupation are represented in subtables.
:
: @author Jens Østergaard Petersen
: @param $entry A subject element in a MODS record
: @param $global-transliteration  The value set for the transliteration scheme to be used in the record as a whole, set in ext:extension
: @param $global-language The string value of mods/language/languageTerm
: @see http://www.loc.gov/standards/mods/userguide/subject.html
: @return $nameOrder The string 'family-given' or the empty string
:)
declare function mods-common:format-subjects($entry as element(), $global-transliteration as xs:string?, $global-language as xs:string?) as element()+ {
    for $subject in $entry/mods:subject
    let $authority := 
        if (string($subject/@authority)) 
        then concat('(', (string($subject/@authority)), ')') 
        else ()
    return
        <tr>
            <td class="label subject">Subject {$authority}</td>
            <td class="record">    
            {
            for $item in $subject/mods:*[string(functx:trim(.))]
            let $authority := 
                if (string($item/@authority)) 
                then concat('(', (string($item/@authority)), ')') 
                else ()
            let $encoding := 
                if (string($item/@encoding)) 
                then concat('(', (string($item/@encoding)), ')') 
                else ()
            let $type := 
                if (string($item/@type)) 
                then concat('(', (string($item/@type)), ')') 
                else ()        
            let $point := 
                if (string($item/@point)) 
                then concat('(', (string($item/@point)), ')') 
                else ()
            return
                <table class="subject">
                    <tr><td class="sublabel">
                        {
                        functx:capitalize-first
                        (
                        replace(replace($item/name(), 'mods:',''), 'titleInfo','Work')
                        ),
                        $authority, $encoding, $type, $point
                        }
                        </td>
                        {
                        (: If there is a child. :)
                        if ($item/mods:*)
                        then
                        <td class="subrecord">
                        {
                        (: If it is a name. :)
                            if ($item/local-name() eq 'name')
                            then mods-common:format-name($item, 1, 'list-first', $global-transliteration, $global-language)
                            else
                                (: If it is a titleInfo. :)
                                if ($item/local-name() eq 'titleInfo')
                                then string-join(mods-common:get-short-title(<titleInfo>{$item}</titleInfo>), '')
                                else
                                    (: If it is something else, no special formatting takes place. :)
                                    for $subitem in ($item/mods:*)
                                    let $authority := 
                                        if (string($subitem/@authority)) 
                                        then concat('(', (string($subitem/@authority)), ')') 
                                        else ()
                                    let $encoding := 
                                        if (string($subitem/@encoding)) 
                                        then concat('(', (string($subitem/@encoding)), ')') 
                                        else ()
                                    let $type := 
                                        if (string($subitem/@type)) 
                                        then concat('(', (string($subitem/@type)), ')') 
                                        else ()
                                    let $point := 
                                        if (string($subitem/@point)) 
                                        then concat('(', (string($subitem/@point)), ')') 
                                        else ()
                                    return
                                        <table>
                                            <tr>
                                                <td class="sublabel">
                                                {functx:capitalize-first(functx:camel-case-to-words(replace($subitem/name(), 'mods:',''), ' ')),
                                                $authority, $encoding, $point}
                                                </td>
                                                <td>
                                                <td class="subrecord">                
                                                {string($subitem)}
                                                </td>
                                                </td>
                                            </tr>
                                        </table>
                                    }
                        </td>
                        else
                            if ($item) then
                            <td class="subrecord" colspan="2">{string($item)}</td>
                            else ()
                        }
                    </tr>
                </table>
            }
            </td>
        </tr>
};

(:~
: The <b>mods-common:format-related-item</b> function returns 
: a compact presentation of a relatedItem for the detail view of the item that relates to it.
: The function seeks to approach the Chicago style.
:
: @author Wolfgang M. Meier
: @author Jens Østergaard Petersen
: @see http://www.loc.gov/standards/mods/userguide/relateditem.html
: @param $relatedItem A MODS relatedItem element
: @param $global-language  The value set for the language of the resource catalogued, set in language/languageTerm
: @return The relatedItem formatted as XHTML.
:)
declare function mods-common:format-related-item($relatedItem as element(mods:relatedItem), $global-language as xs:string?, $collection-short as xs:string) as element()? {
	(:Remove related items with no @xlink:href or no titleInfo/title :)
	let $relatedItem := mods-common:remove-parent-with-missing-required-node($relatedItem)
	let $global-transliteration := $relatedItem/../mods:extension/ext:transliterationOfResource/text()
	(:If several terms are used for the same role, we assume them to be synonymous.:)
	let $relatedItem-role-terms := distinct-values($relatedItem/mods:name/mods:role/mods:roleTerm[1])
	let $relatedItem-role-terms := 
	   (
	   for $relatedItem-role-term in $relatedItem-role-terms 
	   return lower-case($relatedItem-role-term)
	   )
	return
        mods-common:clean-up-punctuation
        (
            <result>{(
                (:Display author roles:)
                if ($relatedItem-role-terms = $retrieve-mods:primary-roles or not($relatedItem-role-terms))
                then mods-common:format-multiple-names($relatedItem, 'list-first', $global-transliteration, $global-language)
                else ()
                ,
                if ($relatedItem-role-terms = $retrieve-mods:primary-roles)
                then '. '
                else ()
                ,
                (:Get title:)
                if (contains($collection-short, 'Annotated%20Videos')) 
                then ()
                else mods-common:get-short-title($relatedItem)
                ,
                (:Display secondary roles.:)
                (:Do not display these (editors) for periodicals, here interpreted as publications with issuance "continuing".:)
                let $issuance := $relatedItem/mods:originInfo/mods:issuance
                return
                    if ($issuance eq "continuing")
                    then ()
                    else
                        let $roleTerms := distinct-values($relatedItem/mods:name/mods:role/mods:roleTerm)
                        return
                            for $roleTerm in $roleTerms[. != $retrieve-mods:primary-roles]        
                                    return
                                        let $names := <entry>{$relatedItem/mods:name[mods:role/mods:roleTerm eq $roleTerm]}</entry>
                                            return
                                                if (string($names))
                                                then
                                                    (
                                                    ', '
                                                    ,
                                                    mods-common:get-role-label-for-list-view($roleTerm)
                                                    ,
                                                    mods-common:format-multiple-names($names, 'secondary', $global-transliteration, $global-language)
                                                    )
                                                else '.'
                ,
                mods-common:get-part-and-origin($relatedItem)
                ,                
                let $urls := $relatedItem/mods:location/mods:url
                return
                    if ($urls)
                    then
                        for $url in $urls
                            return
                                concat(' <', $url, '>')
                    else ()
                ,
                if (contains($collection-short, 'Annotated%20Videos')) 
                then 
                    let $notes := $relatedItem/mods:note
                    for $note in $notes
                    return
                    ('(', functx:capitalize-first($note/@type), ':) ', $note)
                else ()
                ,
                if (contains($collection-short, 'Annotated%20Videos')) 
                then 
                    let $extent := $relatedItem/mods:part/mods:physicalDescription/mods:extent
                    return
                    ('(Extent: ', mods-common:get-extent($extent), ')')
                else ()
                ,
                if (contains($collection-short, 'Annotated%20Videos')) 
                then
                    let $subjects := $relatedItem/mods:subject/mods:topic                    
                    return
                        if ($subjects)
                        then
                        ('(Topics: ', for $subject in $subjects return $subjects, ')')
                        else ()
                else ()
        	)}</result>
        )
};

(:~
: The <b>mods-common:get-part-and-origin</b> function returns 
: information relating to where a publication has been published and 
: where in a container publication (periodical, edited volume) another publication occurs.
: The function seeks to approach the Chicago style.
: The problem here is that information derived from different MODS elements, mods:originInfo and mods:part, are intermingled.
: The information occurs after the title and after any secondary names.
: For a book, the information is presented as follows: {Place}: {Publisher}, {Date}. There is no information derived from mods:part.
: For an article in a periodical, the information is presented as follows: {Volume}, no. {Issue} ({Date}), {Extent}.
: For a contribution to an edited volume, the information is presented as follows: {Extent}. {Place}: {Publisher}, {Date}.
: The function is used in list view and in the display of related items in list and detail view.

: @author Wolfgang M. Meier
: @author Jens Østergaard Petersen
: @see http://www.loc.gov/standards/mods/userguide/originInfo.html
: @see http://www.loc.gov/standards/mods/userguide/part.html
: @param $entry A MODS record or a relatedItem
: @return a string
:)
(: NB: This function should be split up in a part and an originInfo function.:)
(: NB: where is the relatedItem type? :)
declare function mods-common:get-part-and-origin($entry as element()) as xs:string* {
    let $originInfo := $entry/mods:originInfo[1]
    (: contains: place, publisher, dateIssued, dateCreated, dateCaptured, dateValid, 
       dateModified, copyrightDate, dateOther, edition, issuance, frequency. :)
    (: has: lang; xml:lang; script; transliteration. :)
    let $place := $originInfo/mods:place[1]
    (: contains: placeTerm. :)
    (: has no attributes. :)
    (: handled by get-place(). :)
    
    let $publisher := $originInfo/mods:publisher[1]
    (: contains no subelements. :)
    (: has no attributes. :)
    (: handled by get-publisher(). :)
    
    let $dateIssued := $originInfo/mods:dateIssued[1]
    (: contains no subelements. :)
    (: has: encoding; point; keyDate; qualifier. :)
    let $dateCreated := $originInfo/mods:dateCreated[1]
    (: contains no subelements. :)
    (: has: encoding; point; keyDate; qualifier. :)
    let $dateCaptured := $originInfo/mods:dateCaptured[1]
    (: contains no subelements. :)
    (: has: encoding; point; keyDate; qualifier. :)
    let $dateValid := $originInfo/mods:dateValid[1]
    (: contains no subelements. :)
    (: has: encoding; point; keyDate; qualifier. :)
    let $dateModified := $originInfo/mods:dateModified[1]
    (: contains no subelements. :)
    (: has: encoding; point; keyDate; qualifier. :)
    let $copyrightDate := $originInfo/mods:copyrightDate[1]
    (: contains no subelements. :)
    (: has: encoding; point; keyDate; qualifier. :)
    let $dateOther := $originInfo/mods:dateOther[1]
    (: contains no subelements. :)
    (: has: encoding; point; keyDate; qualifier. :)
    (: pick the "strongest" value for the hitlist. :)
    let $dateOriginInfo :=
        if ($dateIssued) 
        then $dateIssued 
        else
        	if ($copyrightDate) 
        	then $copyrightDate 
        	else
        		if ($dateCreated) 
        		then $dateCreated 
        		else
			        if ($dateCaptured) 
			        then $dateCaptured 
			        else
				        if ($dateModified) 
				        then $dateModified 
				        else
					        if ($dateValid) 
					        then $dateValid 
					        else
						        if ($dateOther) 
						        then $dateOther 
						        else ()
	let $dateOriginInfo := mods-common:get-date($dateOriginInfo)
	
    (: NB: this should iterate over part, since there are e.g. multi-part installments of articles. :)
    let $parts := $entry/mods:part
    for $part at $i in $parts
    return

    (: contains: detail, extent, date, text. :)
    (: has: type, order, ID. :)
    let $detail := $part/mods:detail
    (: contains: number, caption, title. :)
    (: has: type, level. :)
        let $series := $detail[@type eq 'series']/mods:number[1]
        let $issue := $detail[@type = ('issue', 'number', 'part')]/mods:number[1]
        let $volume := 
        	if ($detail[@type eq 'volume']/mods:number)
        	then $detail[@type eq 'volume']/mods:number[1]
			(: NB: "text" is allowed to accommodate erroneous Zotero export. Only "number" is valid. :)
        	else $detail[@type eq 'volume']/mods:text[1]
        (: NB: Does $page exist? :)
        let $page := $detail[@type eq 'page']/mods:number
        (: $page resembles list. :)
    
    let $extent := $part/mods:extent[1]
    (: contains: start, end, total, list. :)
    (: has: unit. :)
    (: handled by mods-common:get-extent(). :)
    
    (: NB: If the date of a periodical issue is wrongly put in originInfo/dateIssued. Delete when MODS export is corrected.:)
    let $datePart := 
	    if ($part/mods:date[1]) 
	    then mods-common:get-date($part/mods:date)
	    else $dateOriginInfo
    (: contains no subelements. :)
    (: has: encoding; point; qualifier. :)
    
    let $text := $part/mods:text[1]
    (: contains no subelements. :)
    (: has no attributes. :)
    
    return
        (: If there is a part with issue information and a date, i.e. if the publication is an article in a periodical. :)
        if ($datePart and ($volume or $issue or $extent or $page)) 
        then 
            concat(
            ' '
            ,
            if ($series)
            then concat(' (', $series, ') ')
            else ()
            ,
            if ($volume and $issue)
            then concat($volume, ', no. ', $issue
            	,
            	concat(' (', $datePart, ')')    
			    )
            (: concat((if ($part/mods:detail/mods:caption) then $part/mods:detail/mods:caption/string() else '/'), $part/mods:detail[@type='issue']/mods:number) :)
            else
            	if ($volume or $issue)
            	then
                    (: If the year is used as volume. :)
	                if ($issue)
	                then concat(' ', $datePart, ', no. ', $issue)
	                else concat($volume, concat(' (', string-join($datePart, ', '), ')'))
				else
					if ($extent and $datePart)
				    (: We have no volume or issue, but date and extent alone. :)
					then concat(' ', $datePart)
					else ()
				,	
				(: NB: We assume that there will not be both $page and $extent.:)
				if ($extent) 
				(:NB: iterate.:)
				then concat(': ', mods-common:get-extent($extent[1]), if ($i eq count($parts)) then '.' else '; ')
				else
					if ($page) 
					then concat(': ', $page[1], '.')
					else '.'
            )
        else
            (: If there is no issue, but a dateOriginInfo (loaded in $datePart) and a place or a publisher, i.e. if the publication is an an edited volume. :)
            if ($datePart and ($place or $publisher)) 
            then
                (
                if ($volume) 
                then concat(', Vol. ', $volume)
                else ()
                ,
                if ($extent or $page)
                then
                	if ($volume and $extent)
                	then concat(': ', mods-common:get-extent($extent))
                	else
	                	if ($volume and $page)
	                	then concat(': ', $page)
	                	else
	                		if ($extent)
                			then concat(', ', mods-common:get-extent($extent))
		                	else
		                		if ($page)
	                			then concat(': ', $page)
					            else ()
	            else 
	            	if ($volume)
	            	then ', '
	            	else ()
                ,
                if ($place)
                then concat('. ', mods-common:get-place($place))
                else ()
                ,
                if ($place and $publisher)
                then (': ', mods-common:get-publisher($publisher))
                else ()
                ,
                if ($datePart)
                then
	                (', ',
	                for $date in $datePart
	                return
	                	string-join($date, ' and ')
	                )
                else ()
                ,
                '.'
                )
            (: If not a periodical and not an edited volume, we don't really know what it is and just try to extract whatever information there is. :)
            else
                (
                if ($place)
                then mods-common:get-place($place)
                else ()
                ,
                if ($publisher)
                then (
	                	if ($place)
	                	then ': '
	                	else ()
                	, normalize-space(mods-common:add-part(mods-common:get-publisher($publisher), ', '))
                	)
                else ()
                , 
                mods-common:add-part
                (
                    $dateOriginInfo
                    , 
                    if (exists($entry/mods:relatedItem[@type='host']/mods:part/mods:extent) or exists($entry/mods:relatedItem[@type='host']/mods:part/mods:detail))
                    then '.'
                    else ()
                )
                ,
                if (exists($extent/mods:start) or exists($extent/mods:end) or exists($extent/mods:list))
                then (': ', mods-common:get-extent($extent))            
                else ()
                ,
                (: If it is a series:)
                (: NB: elaborate! :)
                if ($volume)
	            then concat(', Vol. ', $volume, '.')
	            else ()
                ,
                if ($text)
                then concat(' ', $text)
                else ()
                )
};


(:~
: The <b>mods-common:get-extent</b> function returns 
: information relating to the number of pages etc. of a publication.
: <extent> belongs to <physicalDescription>, to <part> as a top level element and to <part> under <relatedItem>. 
: Under <physicalDescription>, <extent> has no subelements.
: The function seeks to approach the Chicago style.

: @author Wolfgang M. Meier
: @author Jens Østergaard Petersen
: @see http://www.loc.gov/standards/mods/userguide/originInfo.html
: @see http://www.loc.gov/standards/mods/userguide/part.html
: @param $extent A MODS extent element
: @return a string
:)
declare function mods-common:get-extent($extent as element(mods:extent)?) as xs:string* {
let $unit := $extent/@unit
let $start := $extent/mods:start
let $end := $extent/mods:end
let $total := $extent/mods:total
let $list := $extent/mods:list
return
    if ($start and $end) 
    then 
        (: Chicago does not note units :)
        (:
        concat(
        if ($unit) 
        then concat($unit, ' ')
        else ()
        ,
        :)
        if ($start ne $end)
        then concat($start, '-', $end)
        else $start        
    else 
        if ($start or $end) 
        then 
            if ($start)
            then $start
            else $end
        else
            if ($total) 
            then concat($total, ' ', $unit)
            else
                if ($list) 
                then $list
                else string-join($extent, ' ')    
};

(:~
: The <b>mods-common:get-publisher</b> function returns 
: information relating to the publisher of a publication. 
: The function seeks to approach the Chicago style.

: @author Wolfgang M. Meier
: @author Jens Østergaard Petersen
: @see http://www.loc.gov/standards/mods/userguide/origininfo.html#publisher
: @param $extent A MODS publisher element from originInfo
: @return an item
:)
declare function mods-common:get-publisher($publishers as element(mods:publisher)*) as item()* {
        string-join(
	        for $publisher in $publishers
	        order by $publisher/@transliteration 
	        return
	        	(: NB: Using name here is an expansion of the MODS schema.:)
	            if ($publisher/mods:name)
	            then mods-common:retrieve-name($publisher/mods:name, 1, 'secondary', '', '')
	            else $publisher
        , 
        (: If there is a transliterated publisher and an untransliterated publisher, probably only one publisher is referred to. :)
        if ($publishers[@transliteration] or $publishers[mods:name/@transliteration])
        then ' '
        else
        ' and ')
};


(:~
: The <b>mods-common:get-place</b> function returns 
: information relating to the place of the domicile of the publisher of a publication. 
: The function seeks to approach the Chicago style.

: @author Wolfgang M. Meier
: @author Jens Østergaard Petersen
: @see http://www.loc.gov/standards/mods/userguide/origininfo.html#publisher
: @param $places One or more MODS place elements from originInfo
: @return a string
:)
declare function mods-common:get-place($places as element(mods:place)*) as xs:string {
    mods-common:serialize-list(
        for $place in $places
        let $placeTerms := $place/mods:placeTerm
        return
            string-join(
                for $placeTerm in $placeTerms
                let $order := if ($placeTerm/@transliteration) then 0 else 1
                order by $order
	        	return
    	            if ($placeTerm[@type eq 'text']/text()) 
    	            then concat
    	            	(
    	                $placeTerm[@transliteration]/text()
    	                ,
    	                ' '
    	                ,
    	                $placeTerm[not(@transliteration)]/text()
    	                )
    	            else
    	                if ($placeTerm[@authority eq 'marccountry']/text()) 
    	                then doc(concat($config:edit-app-root, '/code-tables/marc-country-codes.xml'))/code-table/items/item[value eq $placeTerm]/label
    	                else 
    	                    if ($placeTerm[@authority eq 'iso3166']/text()) 
    	                    then doc(concat($config:edit-app-root, '/code-tables/iso3166-country-codes.xml'))/code-table/items/item[value eq $placeTerm]/label
    	                    else $place/mods:placeTerm[not(@type)]/text(),
            ' ')
    , count($places)
    )
};

(:~
: The <b>mods-common:get-date</b> function returns 
: a date, either as a single date or as a span. 
: The function seeks to approach the Chicago style.

: @author Wolfgang M. Meier
: @author Jens Østergaard Petersen
: @see http://www.loc.gov/standards/mods/userguide/origininfo.html#dateissued
: @param $date a date element from originInfo
: @return a string
:)
declare function mods-common:get-date($date as element()*) as xs:string* {
    (: contains no subelements. :)
    (: has: encoding; point; qualifier. :)
    (: NB: some dates have keyDate. :)

let $start := $date[@point eq 'start']
let $end := $date[@point eq 'end']
let $qualifier := $date/@qualifier/string()
(:let $encoding := $date/@encoding/string():)

return
    concat(
    if ($start and $end) 
    then 
        if ($start ne $end)
        then concat($start, '-', $end)
        else $start        
    else 
        if ($start or $end) 
        then 
            if ($start)
            then concat($start, '-?')
            else concat('?-', $end)
        (: if neither $start nor $end. :)
        else $date/string()
    ,
    if ($qualifier) 
    then concat(' (', $qualifier, ')')
    else ()
    )
};

(:~
: The <b>get-related-items</b> function returns 
: the XHTML view of a relatedItem element. 

: @see http://www.loc.gov/standards/mods/userguide/relateditem.html
: @param $entry a MODS record
: @return XHTML formatting of related items with the MODS record.
:)
declare function mods-common:get-related-items($entry as element(mods:mods), $destination as xs:string, $global-language as xs:string?, $collection-short as xs:string) as element()* {
    for $item in $entry/mods:relatedItem
        let $type := string($item/@type) 
        let $titleInfo := $item/mods:titleInfo
        let $displayLabel := string($item/@displayLabel)
        let $label :=
            string(
                if ($displayLabel)
                then $displayLabel
                else
                    if ($type)
                    then functx:capitalize-first(functx:camel-case-to-words($type, ' '))
                    else 'Related Item'
            )
        let $part := $item/mods:part
        let $xlinked-ID := replace($item/@xlink:href, '^#?(.*)$', '$1')
        let $xlinked-record :=
            (: Any MODS record in /db/resources is retrieved if there is a @xlink:href/@ID match and the relatedItem has no string value. If there should be duplicate IDs, only the first record is retrieved.:)
            (: The linked record is only retrieved if there is no title information inside the related item. :)
            if (exists($xlinked-ID) and not($titleInfo))
            then collection($config:mods-root-minus-temp)//mods:mods[@ID eq $xlinked-ID][1]
            else ()
        let $related-item :=
        	(:If the related item is recorded in another record than the current record.:)
        	if ($xlinked-record) 
        	(: NB: There must be a smarter way to merge the retrieved relatedItem with the native part element! :)
        	(: "update insert $part into $xlinked-record2 does not work for in-memory fragments :)
        	then 
        	   <mods:relatedItem displayLabel ="{$displayLabel}" type="{$type}" xlink:href="{$xlinked-ID}">
        	       {($xlinked-record/mods:titleInfo, $part)}
        	   </mods:relatedItem> 
        	else
        	(:If the related item is described with title in the current record.:)
        		if ($item/mods:titleInfo/mods:title)
        		then $item
        		else ()

    return
        if ($related-item)
        then 
            (: Check for the most common types first. :)
            (: If the related item is a periodical, an edited volume, or a series.:) 
            if ($destination eq 'list')
            then
                (: Only display 'host' and 'series' in list view :)
                if ($type = ('host', 'series'))
                then
                    <span xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-span">
                        <span class="relatedItem-record">{mods-common:format-related-item($related-item, $global-language, $collection-short)}</span>
                    </span>
                else ()
            else
            (:If not 'list', $destination will be 'detail'.:)
            (:If the related item is pulled in with an xlink, use this to make a link.:) 
                if ($xlinked-ID)
                then
                    <tr xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-row">
        				<td class="url label relatedItem-label">
                            <a href="?filter=ID&amp;value={$xlinked-ID}">{concat('&lt;&lt; ', $label)}</a>
                        </td>
                        <td class="relatedItem-record">
        					<span class="relatedItem-span">{mods-common:format-related-item($related-item, $global-language, $collection-short)}</span>
                        </td>
                    </tr>
                else
                    (:If the related item is in the record itself, format it without a link.:)	                
                    <tr xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-row">
        				<td class="url label relatedItem-label">In</td>
                        <td class="relatedItem-record">
        					<span class="relatedItem-span">{mods-common:format-related-item($related-item, $global-language, $collection-short)}</span>
                        </td>
                    </tr>
        else ()
};