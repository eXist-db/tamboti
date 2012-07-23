module namespace mods="http://www.loc.gov/mods/v3";

declare namespace mads="http://www.loc.gov/mads/v2";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace functx = "http://www.functx.com";
declare namespace e = "http://www.asia-europe.uni-heidelberg.de/";

import module namespace config="http://exist-db.org/mods/config" at "../../../modules/config.xqm";
import module namespace uu="http://exist-db.org/mods/uri-util" at "../../../modules/search/uri-util.xqm";
import module namespace modsCommon="http://exist-db.org/mods/common" at "../../../modules/mods-common.xql";

(:The $mods:author-roles values are lower-cased when compared.:)
declare variable $mods:author-roles := ('aut', 'author', 'cre', 'creator', 'composer', 'cmp', 'artist', 'art', 'director', 'drt');
declare variable $mods:secondary-roles := ('com', 'compiler', 'Compiler', 'editor', 'Editor', 'edt', 'trl', 'translator', 'Translator', 'annotator', 'Annotator', 'ann');

declare option exist:serialize "media-type=text/xml";

(: TODO: A lot of restrictions to the first item in a sequence ([1]) have been made; these must all be changed to for-structures or string-joins. :)

(: ### general functions begin ###:)

declare function functx:substring-before-last-match($arg as xs:string, $regex as xs:string) as xs:string? {       
   replace($arg,concat('^(.*)',$regex,'.*'),'$1')
} ;
 
(:~
: Used to transform the camel-case names of MODS elements into space-separated words.  
: @param
: @return
: @see http://www.xqueryfunctions.com/xq/functx_camel-case-to-words.html
:)
declare function functx:camel-case-to-words($arg as xs:string?, $delim as xs:string ) as xs:string {
   concat(substring($arg,1,1), replace(substring($arg,2),'(\p{Lu})', concat($delim, '$1')))
};

(:~
: Used to capitalize the first character of $arg.   
: @param
: @return
: @see http://http://www.xqueryfunctions.com/xq/functx_capitalize-first.html
:)
declare function functx:capitalize-first($arg as xs:string?) as xs:string? {       
   concat(upper-case(substring($arg,1,1)),
             substring($arg,2))
};
 
(:~
: Used to remove whitespace at the beginning and end of a string.   
: @param
: @return
: @see http://http://www.xqueryfunctions.com/xq/functx_trim.html
:)
declare function functx:trim($arg as xs:string?) as xs:string {       
   replace(replace($arg,'\s+$',''),'^\s+','')
};
 

(: ### general functions end ###:)

(:~
: The <em>mods:get-roles-for-detail-view()</em> function returns the roles of the name passed to it.
: It is used in mods:names-full().
: It sends these to mods:get-role-terms-for-detail-view() to obtain the terms used to designate the roles, 
: and for each of these terms a human-readbale label is found by mods:get-role-term-label-for-detail-view().
: Whereas mods:get-roles-for-detail-view() returns the author/creator roles that are placed in front of the title in detail view,
: modsCommon:get-role-label-for-list-view() returns the secondary roles that are placed after the title in list view and in relatedItem in detail view.
:
: @param $name A mods element recording a name, in code or as a human-readable label
: @return The role term label string
:)
declare function mods:get-roles-for-detail-view($name as element()*) as xs:string* {
    if ($name/mods:role/mods:roleTerm/text())
    then
        let $distinct-role-labels := distinct-values(mods:get-role-terms-for-detail-view($name/mods:role))
        let $distinct-role-labels-count := count($distinct-role-labels)
            return
                if ($distinct-role-labels-count gt 0)
                then
                    modsCommon:serialize-list($distinct-role-labels, $distinct-role-labels-count)
                else ()
    else
        (: Supply a default value in the absence of any role term. :)
        if ($name/@type eq 'corporate')
        then 'Corporate Author'
        else 'Author'
};

(:~
: The <em>mods:get-role-terms-for-detail-view()</em> function returns the role terms of the roles passed to it.
: It is used in mods:get-roles-for-detail-view().
: It sends these to mods:get-role-term-label-for-detail-view() to obtain a human-readbale label.
: Whereas mods:get-roles-for-detail-view() returns the author/creator roles that are placed in front of the title in detail view,
: modsCommon:get-role-label-for-list-view() returns the secondary roles that are placed after the title in list view and in relatedItem in detail view.
: The function returns a sequences of human-readable labels, based on searches in the code values and in the label values.  
:
: @param $element A mods element recording a role
: @return The role term string
:)
declare function mods:get-role-terms-for-detail-view($role as element()*) as xs:string* {
    let $roleTerms := $role/mods:roleTerm
    for $roleTerm in distinct-values($roleTerms)
        return
    	    if ($roleTerm)
    	    then mods:get-role-term-label-for-detail-view($roleTerm)
    	    else ()
};

(:~
: The <em>mods:get-role-term-label-for-detail-view(</em> function returns the <em>human-readable value</em> of the role term passed to it.
: It is used in mods:get-role-terms-for-detail-view().
: Type code can use the marcrelator authority, recorded in the code table role-codes.xml.
: The most commonly used values are checked first, letting the function exit quickly.
: The function returns the human-readable label, based on look-ups in the code values and in the label values.  
:
: @param $node A role term value string
: @return The role term label string
:)
declare function mods:get-role-term-label-for-detail-view($roleTerm as xs:string?) as xs:string* {        
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

(: ### <extent> begins ### :)

(: <extent> belongs to <physicalDescription>, to <part> as a top level element and to <part> under <relatedItem>. 
Under <physicalDescription>, <extent> has no subelements.:)

(: ### <originInfo> begins ### :)

(: The DLF/Aquifer Implementation Guidelines for Shareable MODS Records require the use of at least one <originInfo> element with at least one date subelement in every record, one of which must be marked as a key date. <place>, <publisher>, and <edition> are recommended if applicable. These guidelines make no recommendation on the use of the elements <issuance> and <frequency>. This element is repeatable. :)
 (: Application: :)
    (: Problem:  :)
(: Attributes: lang, xml:lang, script, transliteration. :)
    (: Unaccounted for:  :)
(: Subelements: <place> [RECOMMENDED IF APPLICABLE], <publisher> [RECOMMENDED IF APPLICABLE], <dateIssued> [AT LEAST ONE DATE ELEMENT IS REQUIRED], <dateCreated> [AT LEAST ONE DATE ELEMENT IS REQUIRED], <dateCaptured> [NOT RECOMMENDED], <dateValid> [NOT RECOMMENDED], <dateModified> [NOT RECOMMENDED], <copyrightDate> [AT LEAST ONE DATE ELEMENT IS REQUIRED], <dateOther> [AT LEAST ONE DATE ELEMENT IS REQUIRED], <edition> [RECOMMENDED IF APPLICABLE], <issuance> [OPTIONAL], <frequency> [OPTIONAL]. :)
    (: Unaccounted for: . :)
    (: <place> :)
        (: Repeat <place> for recording multiple places. :)
        (: Attributes: type [RECOMMENDED IF APPLICABLE] authority [RECOMMENDED IF APPLICABLE]. :)
            (: @type :)
                (: Values:  :)    
                    (: Unaccounted for:  :)
        (: Subelements: <placeTerm> [REQUIRED]. :)
            (: Attributes: type [REQUIRED]. :)
                (: Values: text, code. :)
    (: <publisher> :)
        (: Attributes: none. :)
    (: dates [AT LEAST ONE DATE ELEMENT IS REQUIRED] :)
        (: The MODS schema includes several date elements intended to record different events that may be important in the life of a resource. :)


(: ### <originInfo> ends ### :)

(: ### <name> begins ### :)

(: The DLF/Aquifer Implementation Guidelines for Shareable MODS Records requires the use of at least one <name> element to describe the creator of the intellectual content of the resource, if available. The guidelines recommend the use of the type attribute with all <name> elements whenever possible for greater control and interoperability. In addition, they require the use of <namePart> as a subelement of <name>. This element is repeatable. :)
 (: Application:  :)
    (: Problem:  :)
(: Attributes: type [RECOMMENDED], authority [RECOMMENDED], xlink, ID, lang, xml:lang, script, transliteration. :)
    (: Unaccounted for: authority, xlink, ID, (lang), xml:lang, script. :)
    (: @type :)
        (: Values: personal, corporate, conference. :)
            (: Unaccounted for: none. :)
(: Subelements: <namePart> [REQUIRED], <displayForm> [OPTIONAL], <affiliation> [OPTIONAL], <role> [RECOMMENDED], <description> [NOT RECOMMENDED]. :)
    (: Unaccounted for: <displayForm>, <affiliation>, <role>, <description>. :)
    (: <namePart> :)
    (: "namePart" includes each part of the name that is parsed. Parsing is used to indicate a date associated with the name, to parse the parts of a corporate name (MARC 21 fields X10 subfields $a and $b), or to parse parts of a personal name if desired (into family and given name). The latter is not done in MARC 21. Names are expected to be in a structured form (e.g. surname, forename). :)
        (: Attributes: type [RECOMMENDED IF APPLICABLE]. :)
            (: @type :)
                (: Values: date, family, given, termsOfAddress. :)    
                    (: Unaccounted for: date, termsOfAddress :)
        (: Subelements: none. :)
    (: <role> :)
        (: Attributes: none. :)
        (: Subelements: <roleTerm> [REQUIRED]. :)
            (: <roleTerm> :)
            (: Unaccounted for: none. :)
                (: Attributes: type [RECOMMENDED], authority [RECOMMENDED IF APPLICABLE]. :)
                (: Unaccounted for: type [RECOMMENDED], authority [RECOMMENDED IF APPLICABLE] :)
                    (: @type :)
                        (: Values: text, code. :)    
                            (: Unaccounted for: text, code :)

(: Both the name as given in the publication and the autority name should be rendered. :)

declare function mods:get-conference-hitlist($entry as element(mods:mods)) {
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
            modsCommon:add-part(string($conference), ', '),
            modsCommon:add-part($entry/mods:originInfo[1]/mods:place[1]/mods:placeTerm[1], ', '),
            $date[1]
        )
    else ()
};

declare function mods:get-conference-detail-view($entry as element()) {
    (: let $date := ($entry/mods:originInfo/mods:dateIssued/string()[1], $entry/mods:part/mods:date/string()[1],
            $entry/mods:originInfo/mods:dateCreated/string())[1]
    return :)
    let $conference := $entry/mods:name[@type eq 'conference']/mods:namePart
    return
    if ($conference) 
    then
        concat('Paper presented at ', string($conference)
            (: , modsCommon:add-part($entry/mods:originInfo/mods:place/mods:placeTerm, ', '), $date:)
            (: no need to duplicate placeinfo in detail view. :)
        )
    else ()
};


declare function mods:get-authority-name-from-mads($mads as element(), $destination as xs:string) {
    let $auth := $mads/mads:authority/mads:name
    return
        modsCommon:format-name($auth, 1, $destination, '', '')   
};


(:~
: Used to retrieve the preferred name from the MADS authority file.    
: @param
: @return
: @see
:)
declare function mods:retrieve-mads-names($name as element(), $position as xs:int, $destination as xs:string) {    
    let $mads-reference := replace($name/@xlink:href, '^#?(.*)$', '$1')
    let $mads-record :=
        if (empty($mads-reference)) 
        then ()        
        else collection($config:mads-collection)/mads:mads[@ID eq $mads-reference]
    let $mads-preferred-name :=
        if (empty($mads-record)) 
        then ()
        else $mads-record/mads:authority/mads:name
    let $mads-preferred-name-formatted := modsCommon:format-name($mads-preferred-name, 1, 'list-first', '', '')
    let $mads-variant-names := $mads-record/mads:variant/mads:name
    let $mads-variant-name-nos := count($mads-record/mads:variant/mads:name)
    let $mads-variant-names-formatted := 
    	string-join(
	    	for $name in $mads-variant-names 
    		return modsCommon:format-name($name, 1, 'list-first', '', '')
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

(: ### <typeOfResource> begins ### :)

declare function mods:return-type($entry ) {
    let $type := string($entry/mods:typeOfResource[1])
    return
        if (exists($type))
        then  
            translate(translate(
            if ($type)
            then $type
            else 'text'
            ,' ','_'),',','')
        else 'text-x-changelog'
};

(: ### <typeOfResource> ends ### :)

(: ### <name> ends ### :)

(: NB! Create function to get <typeOfResource>! :)
(: The DLF/Aquifer Implementation Guidelines for Shareable MODS Records require the use in all records of at least one <typeOfResource> element using the required enumerated values. This element is repeatable. :)
    (: The values for <typeOfResource> are restricted to those in the following list: text, cartographic, notated music, sound recording [if not possible to specify "musical" or "nonmusical"], sound recording-musical, sound recording-nonmusical, still image, moving image, three dimensional object, (software, multimedia) [NB! comma in value], mixed material :)
    (: Subelements: none. :)
    (: Attributes: collection [RECOMMENDED IF APPLICABLE], manuscript [RECOMMENDED IF APPLICABLE]. :)
        (: @collection, @manuscript :)
            (: Values: yes, no. :)
(:
declare function mods:get-resource-type() {
};
:)

(: NB! Create function to get <genre>! :)
(: The DLF /Aquifer Implementation Guidelines for Shareable MODS Records recommend the use of at least one <genre> element in every MODS record and, if a value is provided, require the use of a value from a controlled list and the designation of this list in the authority attribute. This element is repeatable. :)
    (: The values for <typeOfResource> are restricted to those in the following list: text, cartographic, notated music, sound recording [if not possible to specify "musical" or "nonmusical"], sound recording-musical, sound recording-nonmusical, still image, moving image, three dimensional object, software, multimedia, mixed material :)
    (: Subelements: none. :)
    (: Attributes: type, authority [REQUIRED], lang, xml:lang, script, transliteration. :)
(:
declare function mods:get-genre() {
};
:)

(: ### <titleInfo> begins ### :)

(: The DLF/Aquifer Implementation Guidelines for Shareable MODS Records require the use in all records of at least one <titleInfo> element with one <title> subelement. Other subelements of <titleInfo> are recommended when they apply. This element is repeatable. :)
(: Application: <titleInfo> is repeated for each type attribute value. If multiple titles are recorded, repeat <titleInfo><title> for each. The language of the title may be indicated if desired using the xml:lang (RFC3066) or lang (3-character ISO 639-2 code) attributes. :)
    (: Problem: the wrong (2-character) language codes seem to be used in Academy samples. :)
(: 3.3 Attributes: type [RECOMMENDED IF APPLICABLE], authority [RECOMMENDED IF APPLICABLE], displayLabel [OPTIONAL], xlink:simpleLink, ID, lang, xml:lang, script, transliteration. :)
    (: All 3.3 attributes are applied to the <titleInfo> element; none are used on any subelements. 
    In 3.4 all subelements have lang, xml:lang, script, transliteration. :)
    (: Unaccounted for: authority, displayLabel, xlink, ID, xml:lang, script. :)
    (: @type :)
        (: For the primary title of the resource, do not use the type attribute (NB: this does not mean that the attribute should be empty, but absent). For all additional titles, the guidelines recommend using this attribute to indicate the type of the title being recorded. :)
        (: Values: abbreviated, translated, alternative, uniform. :)
        (: NB: added value: transliterated. :)
            (: Unaccounted for: transliterated. :)
(: Subelements: <title> [REQUIRED], <subTitle> [RECOMMENDED IF APPLICABLE], <partNumber> [RECOMMENDED IF APPLICABLE], <partName> [RECOMMENDED IF APPLICABLE], <nonSort> [RECOMMENDED IF APPLICABLE]. :)
    (: Unaccounted for: <nonSort>. :)
    (: <nonSort> :)
        (: The guidelines strongly recommend the use of this element when non-sorting characters are present, rather than including them in the text of the <title> element. :)
    (: <partName> :)
        (: Multiple <partName> elements may be nested in a single <titleInfo> to describe a single part with multiple hierarchical levels. :)

(: !!! function mods:get-title-transliteration !!! :)
(: Constructs a transliterated title for Japanese and Chinese. :)
    (: Problem: What if other languages than Chinese and Japanese occur in a MODS record? :)
    (: Problem: What if several languages with transliteration occur in one MODS record? :)


(: If there is a Japanese or Chinese title, any English title will be a translated title. :) 
    (: Problem: a variant or parallel title in English? :)

(: Constructs title for the detail view. 
It is called by mods:format-detail-view(), which iterates through a sequence of titleInfo elements. :)
declare function mods:title-full($titleInfo as element(mods:titleInfo)) {
if ($titleInfo)
    then
    <tr xmlns="http://www.w3.org/1999/xhtml">
        <td class="label">
        {
            if (($titleInfo/@type eq 'translated') and (not($titleInfo/@transliteration) or string($titleInfo/@lang))) 
            then 'Translated Title'
            else 
                if ($titleInfo/@type eq 'alternative') 
                then 'Alternative Title'
                else 
                    if ($titleInfo/@type eq 'uniform') 
                    then 'Uniform Title'
                    else 
                        if ($titleInfo/@transliteration)
                        then 'Transliterated Title'
                        else
                            (:NB: In mods:format-detail-view(), titleInfo with @type eq 'abbreviated' are removed.:) 
                            if ($titleInfo/@type eq 'abbreviated') 
                            then 'Abbreviated Title'
                            (:Default value.:)
                            else 'Title'
        }
        <span class="deemph">
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
                modsCommon:get-language-label($lang)
                )
            else ()
        }
        {
        let $transliteration := string($titleInfo/@transliteration)
        let $global-transliteration := $titleInfo/../mods:extension/e:transliterationOfResource
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
    else
    ()
};

(: ### <titleInfo> ends ### :)

(: ### <relatedItem> begins ### :)

(: Application: relatedItem includes a designation of the specific type of relationship as a value of the type attribute and is a controlled list of types enumerated in the schema. <relatedItem> is a container element under which any MODS element may be used as a subelement. It is thus fully recursive. :)
(: Attributes: type, xlink:href, displayLabel, ID. :)
(: Values for @type: preceding, succeeding, original, host, constituent, series, otherVersion, otherFormat, isReferencedBy. :)
(: Subelements: any MODS element. :)
(: NB! This function is constructed differently from mods:entry-full; the two should be harmonised. :)

declare function mods:get-related-items($entry as element(mods:mods), $destination as xs:string, $global-language as xs:string, $collection-short as xs:string) {
    for $item in $entry/mods:relatedItem
        let $type := string($item/@type)
        (:NB: do we use @ID on relatedItem?:) 
        let $ID := string($item/@ID)
        let $titleInfo := $item/mods:titleInfo
        let $displayLabel := string($item/@displayLabel)
        let $label-displayed :=
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
            (: Any MODS record in /db/resources is retrieved if there is a @xlink:href/@ID match and the relatedItem has no string value. If there should be duplicated IDs, only the first record is retrieved.:)
            if (exists($xlinked-ID) and not($titleInfo))
            then collection($config:mods-root-minus-temp)//mods:mods[@ID eq $xlinked-ID][1]
            else ()
        let $related-item :=
        	(:If the related item is noted in another record than the current record.:)
        	if ($xlinked-record) 
        	(: NB: There must be a smarter way to merge the retrieved relatedItem with the native part! :)
        	(:update insert $part into $xlinked-record:)
        	then 
        	   <mods:relatedItem ID="{$ID}" displayLabel ="{$displayLabel}" type="{$type}" xlink:href="{$xlinked-ID}">
        	       {($xlinked-record/mods:titleInfo, $part)}
        	   </mods:relatedItem> 
        	else
        	(:If the related item is noted in the current record.:)
        		(:If there is no title, then discard.:)
        		if (string-join($item/mods:titleInfo/mods:title, ''))
        		then $item
        		else ()
    return
        (: Check for the most common types first. :)
        if ($related-item)
        then
            (:If the related item is a periodical, an edited volume, or a series.:) 
	        if ($type = ('host', 'series'))
	        then
	            if ($destination eq 'list')
	            then
	                <span xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-span">
	                	<span class="relatedItem-record">{modsCommon:format-related-item($related-item, $global-language, $collection-short)}</span>
	                </span>
	            else
	                (:If not 'list', $destination will be 'detail'.:)
	                (:If the related item is pulled in with an xlink, use this to make a link.:) 
	                if (string($xlinked-ID))
	                then
	                    <tr xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-row">
							<td class="url label relatedItem-label">
	                            <a href="?filter=ID&amp;value={$xlinked-ID}">&lt;&lt; In</a>
	                        </td>
	                        <td class="relatedItem-record">
								<span class="relatedItem-span">{modsCommon:format-related-item($related-item, $global-language, $collection-short)}</span>
	                        </td>
	                    </tr>
	                else
                        (:If the related item is in the record itself, format it without a link.:)	                
	                    <tr xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-row">
							<td class="url label relatedItem-label">In</td>
	                        <td class="relatedItem-record">
								<span class="relatedItem-span">{modsCommon:format-related-item($related-item, $global-language, $collection-short)}</span>
	                        </td>
	                    </tr>
	        (: if @type is not 'host' or 'series':)
	        else
	            (:If the related item is pulled in with an xlink, use this to make a link.:) 
	            if ($destination eq 'detail' and string($xlinked-ID))
	            then
	                <tr xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-row">
						<td class="url label relatedItem-label">
	                        <a href="?filter=ID&amp;value={$xlinked-ID}">&lt;&lt; {$label-displayed}</a>
	                    </td>
	                    <td class="relatedItem-record">
							<span class="relatedItem-span">{modsCommon:format-related-item($related-item, $global-language, $collection-short)}</span>
	                    </td>
	                </tr>
	            else
	                (:If the related item is in the record itself, format it without a link.:)
	                if ($destination eq 'detail')
	                then
	                <tr xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-row">
	                    <td class="url label relatedItem-label">
	                        {functx:capitalize-first(functx:camel-case-to-words($type, ' '))}
	                    </td>
	                    <td class="relatedItem-record">
	                        <span class="relatedItem-span">{modsCommon:format-related-item($related-item, $global-language, $collection-short)}</span>
	                    </td>
	                </tr>
	                (:Only @type 'host' and 'series' are displayed in list view.:)
	                else ()
        else ()
};

(: ### <relatedItem> ends ### :)

declare function mods:names-full($entry as element(), $global-transliteration, $global-language) {
        (: NB: conference? :)
        let $names := $entry/*:name[@type = ('personal', 'corporate', 'family') or not(@type)]
        for $name in $names
        return
                <tr xmlns="http://www.w3.org/1999/xhtml"><td class="label">
                    {
                    mods:get-roles-for-detail-view($name)
                    }
                </td><td class="record">
                    {
                    modsCommon:format-name($name, 1, 'list-first', $global-transliteration, $global-language)
                    }
                    {
                    if ($name/@xlink:href)
                    then mods:retrieve-mads-names($name, 1,'list-first')
                    else ()
                    }</td>
                
                </tr>
};

declare function mods:format-url($url as element(mods:url), $collection-short as xs:string){
let $url := 
    if ($url/@access eq 'preview')
    (:Special formatting for image collections.:)
    then concat('images/',$collection-short,'/',$url,'?s',$config:url-image-size) 
    else $url
return $url
};

(: Creates view for detail view. :)
(: NB: "mods:format-detail-view()" is referenced in session.xql. :)
declare function mods:format-detail-view($id as xs:string, $entry as element(mods:mods), $collection-short as xs:string) {
	let $ID := $entry/@ID
	(:let $log := util:log("DEBUG", ("##$ID): ", $ID)):)
	let $entry := modsCommon:remove-parent-with-missing-required-node($entry)
	let $global-transliteration := $entry/mods:extension/e:transliterationOfResource/text()
	let $global-language := $entry/mods:language[1]/mods:languageTerm[1]/text()
	return
    <table xmlns="http://www.w3.org/1999/xhtml" class="biblio-full">
    {
    <tr>
        <td class="collection-label">Record Location</td>
        <td><div class="collection">{replace(replace(uu:unescape-collection-path($collection-short), '^resources/commons/', 'resources/'),'^resources/users/', 'resources/')}</div></td>
    </tr>
    ,
    
    (: names :)
    if ($entry/mods:name)
    then mods:names-full($entry, $global-transliteration, $global-language)
    else ()
    ,
    
    (: titles :)
    for $titleInfo in $entry/mods:titleInfo[not(@type eq 'abbreviated')]
    return mods:title-full($titleInfo)
    ,
    
    (: conferences :)
    modsCommon:simple-row(mods:get-conference-detail-view($entry), 'Conference')
    ,

    (: place :)
    for $place in $entry/mods:originInfo[1]/mods:place
        return modsCommon:simple-row(modsCommon:get-place($place), 'Place')
    ,
    
    (: publisher :)
        (: If a transliterated publisher name exists, this probably means that several publisher names are simply different script forms of the same publisher name. Place the transliterated name first, then the original script name. :)
        if ($entry/mods:originInfo[1]/mods:publisher[@transliteration])
        then
	        modsCommon:simple-row(
	            string-join(
		            for $publisher in $entry/mods:originInfo[1]/mods:publisher
		            let $order := 
			            if ($publisher[@transliteration]) 
			            then 0 
			            else 1
		        	order by $order
		        	return modsCommon:get-publisher($publisher)
	        	, ' ')
	        ,
			'Publisher')
		else
		(: Otherwise we have a number of different publishers.:)
			for $publisher in $entry/mods:originInfo[1]/mods:publisher
	        return modsCommon:simple-row(modsCommon:get-publisher($publisher), 'Publisher')
	,
	
    (: dates :)
    (:If a related item has a date, use it instead of a date in originInfo:)   
    if ($entry/mods:relatedItem[@type eq 'host']/mods:originInfo[1]/mods:dateCreated) 
    then ()
    else 
        for $date in $entry/mods:originInfo[1]/mods:dateCreated
            return modsCommon:simple-row($date, 
            concat('Date Created',
                concat(
                if ($date/@point) then concat(' (', functx:capitalize-first($date/@point), ')') else (),
                if ($date/@qualifier) then concat(' (', functx:capitalize-first($date/@qualifier), ')') else ()
                )
                )
            )
    ,
    if ($entry/mods:relatedItem[@type eq 'host']/mods:originInfo[1]/mods:copyrightDate) 
    then () 
    else 
        for $date in $entry/mods:originInfo[1]/mods:copyrightDate
            return modsCommon:simple-row($date, 
            concat('Copyright Date',
                concat(
                if ($date/@point) then concat(' (', functx:capitalize-first($date/@point), ')') else (),
                if ($date/@qualifier) then concat(' (', functx:capitalize-first($date/@qualifier), ')') else ()
                )
                )
            )
    ,
    if ($entry/mods:relatedItem[@type eq 'host']/mods:originInfo[1]/mods:dateCaptured) 
    then () 
    else 
        for $date in $entry/mods:originInfo[1]/mods:dateCaptured
            return modsCommon:simple-row($date, 
            concat('Date Captured',
                concat(
                if ($date/@point) then concat(' (', functx:capitalize-first($date/@point), ')') else (),
                if ($date/@qualifier) then concat(' (', functx:capitalize-first($date/@qualifier), ')') else ()
                )
                )
            )            
    ,
    if ($entry/mods:relatedItem[@type eq 'host']/mods:originInfo[1]/mods:dateValid) 
    then () 
    else 
        for $date in $entry/mods:originInfo[1]/mods:dateValid
            return modsCommon:simple-row($date, 
            concat('Date Valid',
                concat(
                if ($date/@point) then concat(' (', functx:capitalize-first($date/@point), ')') else (),
                if ($date/@qualifier) then concat(' (', functx:capitalize-first($date/@qualifier), ')') else ()
                )
                )
            )
    ,
    if ($entry/mods:relatedItem[@type eq 'host']/mods:originInfo[1]/mods:dateIssued) 
    then () 
    else 
        for $date in $entry/mods:originInfo[1]/mods:dateIssued
            return modsCommon:simple-row($date, 
            concat(
                'Date Issued', 
                concat(
                if ($date/@point) then concat(' (', functx:capitalize-first($date/@point), ')') else (),
                if ($date/@qualifier) then concat(' (', functx:capitalize-first($date/@qualifier), ')') else ()
                )
                )
            )
    ,
    if ($entry/mods:relatedItem[@type eq 'host']/mods:originInfo[1]/mods:dateModified) 
    then () 
    else 
        for $date in $entry/mods:originInfo[1]/mods:dateModified
            return modsCommon:simple-row($date, 
            concat('Date Modified',
                concat(
                if ($date/@point) then concat(' (', functx:capitalize-first($date/@point), ')') else (),
                if ($date/@qualifier) then concat(' (', functx:capitalize-first($date/@qualifier), ')') else ()
                )
                )
            )
    ,
    if ($entry/mods:relatedItem[@type eq 'host']/mods:originInfo[1]/mods:dateOther) 
    then () 
    else 
        for $date in $entry/mods:originInfo[1]/mods:dateOther
            return modsCommon:simple-row($date, 
            concat('Other Date',
                concat(
                if ($date/@point) then concat(' (', functx:capitalize-first($date/@point), ')') else (),
                if ($date/@qualifier) then concat(' (', functx:capitalize-first($date/@qualifier), ')') else ()
                )
                )
            )            
    ,
    (: edition :)
    if ($entry/mods:originInfo[1]/mods:edition) 
    then modsCommon:simple-row($entry/mods:originInfo[1]/mods:edition[1], 'Edition') 
    else ()
    ,
    (: extent :)
    let $extent := $entry/mods:physicalDescription/mods:extent
    return
        if ($extent) 
        then modsCommon:simple-row(
            modsCommon:get-extent($extent), 
            concat('Extent', 
                if ($extent/@unit) 
                then concat(' (', functx:capitalize-first($extent/@unit), ')') 
                else ()
                )
            )    
        else ()
    ,
    (: URL :)
    for $url in $entry/mods:location/mods:url[./text()]
    let $displayLabel := $url/@displayLabel/string()
    let $dateLastAccessed := $url/@displayLabel/string()
    return
        <tr xmlns="http://www.w3.org/1999/xhtml">
            <td class="label"> 
            {
                concat(
                    if ($url/@displayLabel/string())
                    then $url/@displayLabel/string()
                    else 'URL'
                ,
                    if ($url/@dateLastAccessed/string())
                    then concat(' (Last Accessed: ', $url/@dateLastAccessed/string(), ')')
                    else ''
                )
            }
            </td>
            <td class="record">
            <a href="{mods:format-url($url, $collection-short)}" target="_blank">
                {
                    if ((string-length($url) le 70))
                    then $url
                    (:avoid too long urls that do not line-wrap:)
                    else (substring($url, 1, 70), '...')
                }
                </a></td>
        </tr>
    ,
    (: relatedItem :)
    mods:get-related-items($entry, 'detail', $global-language, $collection-short)
    ,
    (: typeOfResource :)
    modsCommon:simple-row(string($entry/mods:typeOfResource[1]), 'Type of Resource')
    ,
    (: internetMediaType :)
    modsCommon:simple-row(
    (
	    let $label := doc(concat($config:edit-app-root, '/code-tables/internet-media-type-codes.xml'))/*:code-table/*:items/*:item[*:value eq $entry/mods:physicalDescription[1]/mods:internetMediaType]/*:label
	    return
	        if ($label) 
	        then $label
	        else $entry/mods:physicalDescription[1]/mods:internetMediaType)
    , 'Internet Media Type')
    ,
    
    (: genre :)
    for $genre in ($entry/mods:genre)
    let $authority := string($genre/@authority)
    return   
        modsCommon:simple-row(
            if ($authority eq 'local')
                then doc(concat($config:edit-app-root, '/code-tables/genre-local-codes.xml'))/*:code-table/*:items/*:item[*:value eq $genre]/*:label
                else
                	if ($authority eq 'marcgt')
                	then doc(concat($config:edit-app-root, '/code-tables/genre-marcgt-codes.xml'))/*:code-table/*:items/*:item[*:value eq $genre]/*:label
					else string($genre)
                , 
                concat(
                    'Genre'
                    , 
                    if ($authority)
                    then
                        if ($authority eq 'marcgt')
                        then ' (MARC Genre Terms)'
                        else concat(' (', $authority, ')')
                    else ()            
            )
    )
    ,

    (: language :)
    let $distinct-language-labels := distinct-values(
        for $language in $entry/mods:language
        for $languageTerm in $language/mods:languageTerm
        return modsCommon:get-language-label($languageTerm/text())
        )
    let $distinct-language-labels-count := count($distinct-language-labels)
        return
            if ($distinct-language-labels-count gt 0)
            then
                modsCommon:simple-row(
                    modsCommon:serialize-list($distinct-language-labels, $distinct-language-labels-count)
                ,
                if ($distinct-language-labels-count gt 1) 
                then 'Languages of Resource' 
                else 'Language of Resource'
                    )
            else ()
    ,

    (: script :)

    let $distinct-script-labels := distinct-values(
        for $language in $entry/mods:language
        for $scriptTerm in $language/mods:scriptTerm
        return modsCommon:get-script-label($scriptTerm/text())
        )
    let $distinct-script-labels-count := count($distinct-script-labels)
        return
            if ($distinct-script-labels-count gt 0)
            then
                modsCommon:simple-row(
                    modsCommon:serialize-list($distinct-script-labels, $distinct-script-labels-count)
                ,
                if ($distinct-script-labels-count gt 1) 
                then 'Scripts of Resource' 
                else 'Script of Resource'
                    )
            else ()
    ,
    
    (: abstract :)
    for $abstract in ($entry/mods:abstract)
    return
    modsCommon:simple-row($abstract, 'Abstract')
    ,
    
    (: note :)
    for $note in $entry/mods:note
    let $displayLabel := string($note/@displayLabel)
    let $type := string($note/@type)
    let $text := $note/text()
    (: The following serves to render html markup in Zotero exports. Stylesheet should be changed to accommodate standard markup. :)
    (:NB: Do $double-escapes occur?:)
    let $double-escapes-fixed := replace(replace(replace($text, '&amp;nbsp;', '&#160;'), '&amp;gt;', '&gt;'), '&amp;lt;', '&lt;')
    let $wrapped-with-span := concat('&lt;span>', $double-escapes-fixed, '</span>')
    return        
        modsCommon:simple-row(util:parse($wrapped-with-span)
	    , 
	    concat('Note', 
	        concat(
	        if ($displayLabel)
	        then concat(' (', $displayLabel, ')')            
	        else ()
	        ,
	        if ($type)
	        then concat(' (', $type, ')')            
	        else ()
	        )
	        )
	    )
    ,
    (: subject :)
    (: We assume that there are no subjects with an empty topic element. If it is empty, we skip processing.:)
    if (normalize-space(string($entry/mods:subject[1])))
    then modsCommon:format-subjects($entry, $global-transliteration, $global-language)    
    else ()
    , 
    (: table of contents :)
    for $table-of-contents in $entry/mods:tableOfContents
    return
        if (string($table-of-contents)) 
        then        
            <tr xmlns="http://www.w3.org/1999/xhtml">
                <td class="label"> 
                {
                    if ($table-of-contents/@displayLabel)
                    then $table-of-contents/@displayLabel
                    else 'Table of Contents'
                }
                </td>
                <td class="record">
                {
                (:Possibly, both text and link could be displayed.:)
                if ($table-of-contents/text())
                then $table-of-contents/text()
                else
                    if (string($table-of-contents/@xlink:href))
                    then
                        <a href="{string($table-of-contents/@xlink:href)}" target="_blank">
                        {
                            if ((string-length(string($table-of-contents/@xlink:href)) le 70)) 
                            then string($table-of-contents/@xlink:href)
                            (:avoid too long urls that do not line-wrap:)
                            else (substring(string($table-of-contents/@xlink:href), 1, 70), '...')}
                        </a>
                    else ()
                }
                </td>
            </tr>
        else ()
    ,

    (: identifier :)
    let $identifiers := $entry/mods:identifier
    for $item in $identifiers
    let $type := $item/@type
    return 
        modsCommon:simple-row
        (
            $item, 
            concat
            (
                'Identifier',
                if (string($type)) 
                then concat(' (', string($type), ')') 
                else ()
                , 
                if ($type eq 'local')
                then
                    let $local-identifiers := collection($config:mods-root-minus-temp)//mods:mods[.//mods:identifier eq $item]/@ID/string()
                    let $local-identifiers := 
                        (for $local-identifier in $local-identifiers where $local-identifier ne $ID return $local-identifier)
                    return
                        if (count($local-identifiers) gt 0)
                        then concat(' NB: This identifier has already been used on record(s) with the following IDs: ', string-join($local-identifiers, ', '))
                        else ()
                else ()
            )
        )
    ,
    
    (: classification :)
    for $item in $entry/mods:classification
    let $authority := 
        if (string($item/@authority)) 
        then concat(' (', (string($item/@authority)), ')') 
        else ()
    return modsCommon:simple-row($item, concat('Classification', $authority))
    ,
    
    (: find records that refer to the current record if this records a periodical or an edited volume or a similar kind of publication. :)
    (:NB: This takes time!:)
    (:NB: allowing empty genre to triger this: remove when WSC has genre.:)
    if ($entry/mods:genre = ('series', 'periodical', 'editedVolume', 'newspaper', 'journal', 'festschrift', 'encyclopedia', 'conference publication', 'canonical scripture') or empty($entry/mods:genre)) 
    then
        (:The $ID is passed to the query; when the query is constructed, the hash is appended (application.xql, $biblio:FIELDS). 
        This is necessary since a hash in the URL is interpreted as a fragment identifier and not passed as a param.:)
        let $linked-ID := concat('#',$ID)
        let $linked-records := collection($config:mods-root-minus-temp)//mods:mods[mods:relatedItem[@type = ('host', 'series', 'otherFormat')]/@xlink:href eq $linked-ID]
        let $linked-records-count := count($linked-records)
        return
        if ($linked-records-count eq 0)
        then ()
        else 
            if ($linked-records-count gt 10)
            then
                <tr xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-row">
                    <td class="url label relatedItem-label"> 
                        <a href="?action=&amp;filter=XLink&amp;value={$ID}&amp;query-tabs=simple">&lt;&lt; Catalogued Contents:</a>
                    </td>
                    <td class="relatedItem-record">
                        <span class="relatedItem-span">{$linked-records-count} records</span>
                    </td>
                </tr>
            else
                for $linked-record in $linked-records
                let $link-ID := $linked-record/@ID
                let $link-contents := 
                    if (string-join($linked-record/mods:titleInfo/mods:title, ''))
                    then mods:format-list-view((), $linked-record, '') 
                    else ()
                return
                <tr xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-row">
                    <td class="url label relatedItem-label">
                        <a href="?filter=ID&amp;value={$link-ID}">&lt;&lt; Catalogued Contents:</a>
                    </td>
                    <td class="relatedItem-record">
                        <span class="relatedItem-span">{$link-contents}</span>
                    </td>
                </tr>
        else ()
    ,
    modsCommon:simple-row(concat(replace(request:get-url(), '/retrieve', '/index.html'), '?filter=ID&amp;value=', $ID), 'Stable Link to This Record')
    ,

    (: languageOfCataloging :)
    let $distinct-language-labels := distinct-values(
        for $language in $entry/mods:recordInfo/mods:languageOfCataloging
        return modsCommon:get-language-label($language/mods:languageTerm/text())
        )
    let $distinct-language-labels-count := count($distinct-language-labels)
        return
            if ($distinct-language-labels-count gt 0)
            then
                modsCommon:simple-row(
                    modsCommon:serialize-list($distinct-language-labels, $distinct-language-labels-count)
                ,
                if ($distinct-language-labels-count gt 1) 
                then 'Languages of Cataloging' 
                else 'Language of Cataloging'
                    )
            else ()
    ,
    
    (:modification date:)
    let $last-modified := $entry/mods:extension/e:modified/e:when
    (:let $log := util:log("DEBUG", ("##$last-modified): ", $last-modified)):)
    return 
        if ($last-modified) then
            modsCommon:simple-row(functx:substring-before-last-match($last-modified[last()], 'T'), 'Record Last Modified')
        else ()
    }
    </table>
};

(: Creates view for hitlist. :)
(: NB: "mods:format-list-view()" is referenced in session.xql. :)
declare function mods:format-list-view($id as xs:string, $entry as element(), $collection-short as xs:string) {
	let $entry := modsCommon:remove-parent-with-missing-required-node($entry)
	let $global-transliteration := $entry/mods:extension/e:transliterationOfResource/text()
	let $global-language := $entry/mods:language[1]/mods:languageTerm[1]/text()
	return
    let $format :=
        (
        (: The author, etc. of the primary publication. These occur in front, with no role labels.:)
        (: NB: conference? :)
        let $names := $entry/mods:name
        let $names-primary := <entry>{
            $names
                [@type = ('personal', 'corporate', 'family') or not(@type)]
                [mods:role/mods:roleTerm = $mods:author-roles or empty(mods:role/mods:roleTerm)]
            }</entry>
            return
    	        if (string($names-primary))
    	        then (modsCommon:format-multiple-names($names-primary, 'list-first', $global-transliteration, $global-language)
    	        , '. ')
    	        else ()
        ,
        (: The title of the primary publication. :)
        modsCommon:get-short-title($entry)
        ,
        let $names := $entry/mods:name
        let $role-terms-secondary := $names/mods:role/mods:roleTerm[. = $mods:secondary-roles]
            return
                for $role-term-secondary in distinct-values($role-terms-secondary)
                    return
                        let $names-secondary := <entry>{$entry/mods:name[mods:role/mods:roleTerm = $role-term-secondary]}</entry>
                            return                            (
                                (: Introduce secondary role label with comma. :)
                                (: NB: What if there are multiple secondary roles? :)
                                ', '
                                ,
                                modsCommon:get-role-label-for-list-view($role-term-secondary)
                                ,
                                (: Terminate secondary role with period if there is no related item. :)
                                modsCommon:format-multiple-names($names-secondary, 'secondary', $global-transliteration, $global-language)
                                )
        ,
        (:If there are no secondary names, insert a period after the title, if there is no related item.:)
        if (not($entry/mods:name/mods:role/mods:roleTerm[. = $mods:secondary-roles]))
        then
            if (not($entry/mods:relatedItem[@type eq 'host'])) 
            then ''
            else '.'
        else ()
      , ' '
        ,
        (: The conference of the primary publication, containing originInfo and part information. :)
        if ($entry/mods:name[@type eq 'conference']) 
        then mods:get-conference-hitlist($entry)
        (: If not a conference publication, get originInfo and part information for the primary publication. :)
        else 
            (:The series that the primary publication occurs in is spliced in between the secondary names and the originInfo.:)
            (:NB: Should not be  italicised.:)
            if ($entry/mods:relatedItem[@type eq'series'])
            then ('. ', <span xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-span">{mods:get-related-items($entry, 'list', $global-language, $collection-short)}</span>)
            else ()
            ,
            modsCommon:get-part-and-origin($entry)
        ,
        (: The periodical, edited volume or series that the primary publication occurs in. :)
        (: if ($entry/mods:relatedItem[@type=('host','series')]/mods:part/mods:extent or $entry/mods:relatedItem[@type=('host','series')]/mods:part/mods:detail/mods:number/text()) :)
        if ($entry/mods:relatedItem[@type eq 'host'])
        then <span xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-span">{mods:get-related-items($entry, 'list', $global-language, $collection-short)}</span>
        else 
        (: The url of the primary publication. :)
        	if (contains($collection-short, 'Priya')) then () else
        	if ($entry/mods:location/mods:url/text())
        	then
            	for $url in $entry/mods:location/mods:url
	                return
                    (: NB: Too long URLs do not line-wrap, forcing the display of results down below the folder view, so do not display too long URLs. The link is anyway not clickable. :)
	                if (string-length($url) le 80)
	                then concat(' <', $url, '>', '.')
    	            else ""
        	else '.'
        )
    return
        modsCommon:clean-up-punctuation(<span xmlns="http://www.w3.org/1999/xhtml" class="record">{$format}</span>)
};