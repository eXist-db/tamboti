module namespace mods="http://www.loc.gov/mods/v3";

declare namespace mads="http://www.loc.gov/mads/v2";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace fo="http://www.w3.org/1999/XSL/Format";
declare namespace functx = "http://www.functx.com";
declare namespace e = "http://www.asia-europe.uni-heidelberg.de/";

import module namespace config="http://exist-db.org/mods/config" at "../config.xqm";
import module namespace uu="http://exist-db.org/mods/uri-util" at "uri-util.xqm";

(: Removes titleIfo, name and relatedItem nodes that do not contain nodes required by the respective elements. :)
declare function mods:remove-parent-with-missing-required-node($node as node()) as node() {
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
            	if (not(((string-length($element) > 0) or ($element/@xlink:href))))
            	then ()
            	else $element
	        else $element
}
};

declare option exist:serialize "media-type=text/xml";

(: TODO: A lot of restrictions to the first item in a sequence ([1]) have been made; these must all be changed to for-structures or string-joins. :)

(: ### general functions begin ###:)

declare function functx:substring-before-last-match($arg as xs:string?, $regex as xs:string) as xs:string? {       
   replace($arg,concat('^(.*)',$regex,'.*'),'$1')
} ;
 
 (:~
: Used to transform the camel-case names of MODS elements into space-separated words.  
: @param
: @return
: @see http://www.xqueryfunctions.com/xq/functx_camel-case-to-words.html
:)
declare function functx:camel-case-to-words($arg as xs:string?, $delim as xs:string ) as xs:string? {
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
 
(:~
: Used to clean up unintended sequences of punctuation. These should ideally be removed at the source.   
: @param
: @return
:)
(: Function to clean up unintended punctuation. These should ideally be removed at the source. :)
declare function mods:clean-up-punctuation($element as node()) as node() {
	element {node-name($element)}
		{$element/@*,
			for $child in $element/node()
			return
				if ($child instance of text())
				then 
					replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(
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
				else mods:clean-up-punctuation($child)
      }
};


(: ### general functions end ###:)


(:~
: The <b>mods:get-language-term</b> function returns 
: the <b>human-readable label</b> of the language value passed to it.  
: This value can set in many mods elements and attributes. 
: languageTerm can have two types, text and code.
: Type code can use two different authorities, 
: recorded in the code tables language-2-type-codes.xml and language-3-type-codes.xml, 
: as well as the authority valueTerm noted in language-3-type-codes.xml.
: The most commonly used values are checked first, letting the function exit quickly.
: The function returns the human-readable label, based on searches in the code values and in the label.  
:
: @param $node A mods element or attribute recording a value, in textual or coded form
: @return The language label string
:)
declare function mods:get-language-label($language as item()*) as xs:string* {
        let $languageTerm :=
            let $languageTerm := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[value = $language]/label
            return
                if ($languageTerm)
                then $languageTerm
                else
                    let $languageTerm := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[valueTwo = $language]/label
                    return
                        if ($languageTerm)
                        then $languageTerm
                        else
                            let $languageTerm := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[valueTerm = $language]/label
                            return
                                if ($languageTerm)
                                then $languageTerm
                                else
                                    let $languageTerm := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[upper-case(label) = $language/upper-case(label)]/label
                                    return
                                        if ($languageTerm)
                                        then $languageTerm
                                        else
                                            let $languageTerm := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[upper-case(label) = upper-case($language)]/label
                                            return
                                                if ($languageTerm)
                                                then $languageTerm
                                                else $language
        return $languageTerm
};

(:~
: The <b>mods:get-script-term</b> function returns 
: the <b>human-readable label</b> of the script value passed to it.  
: @param
: @return
:)
declare function mods:get-script-term($language as node()*) as xs:string* {
        let $scriptTerm :=
            let $scriptTerm := doc(concat($config:edit-app-root, '/code-tables/script-codes.xml'))/code-table/items/item[value = $language/mods:scriptTerm[@authority]]/label
            return
                if ($scriptTerm)
                then $scriptTerm
                else
                    let $scriptTerm := doc(concat($config:edit-app-root, '/code-tables/script-codes.xml'))/code-table/items/item[value = $language/mods:scriptTerm]/label
                    return
                        if ($scriptTerm)
                        then $scriptTerm
                        else ()
        return $scriptTerm
};

(:~
: The <b>mods:language-of-resource</b> function returns 
: the <b>string</b> value of the language for the resource.  
: This value is set in mods/language/languageTerm.
: The function feeds this value to the function mods:get-language.
: It is assumed that if two languageTerm's exist under one language, these are equivalent.
: It is possible to have multiple mods/language for resources, just as it is possible to set the code value to 'mul', meaning Multiple languages.
: The value is set in the dialogue which leads to the creation of a new records.
:
: @see xqdoc/xqdoc-display;get-language
: @param $language The MODS languageTerm element, child of the top-level language element
: @return The language label string
:)
declare function mods:language-of-resource($language as element()*) as xs:anyAtomicType* {
        let $languageTerm := $language/mods:languageTerm[1]
        return
            if ($languageTerm) 
            then mods:get-language-label($languageTerm)
            else ()
};

declare function mods:script-of-resource($language as element()*) as xs:anyAtomicType* {
        let $scriptTerm := $language/mods:scriptTerm
        return
            if ($scriptTerm) 
            then mods:get-script-term($language)
            else ()
};


(:~
: The <b>mods:language-of-cataloging</b> function returns 
: the <b>$string</b> value of the language for cataloguing the resource.  
: This value is set in mods/recordInfo/languageOfCataloging.
: The function feeds this value to the function mods:get-language.
: It is assumed that if two languageTerm's exist under one language, these are equivalent.
: It is possible to have multiple mods/language, for resources, just as it is possible to set the code value to 'mul', meaning Multiple languages.
: The value is set in the dialogue which leads to the creation of a new records.
:
: @see xqdoc/xqdoc-display;get-language
: @param $entry The MODS languageOfCataloging element, child of the top-level recordInfo element
: @return The language label string
:)
declare function mods:language-of-cataloging($language as element(mods:languageOfCataloging)*) as xs:anyAtomicType? {
        let $languageTerm := $language/mods:languageTerm[1]
        return
            if ($languageTerm) 
            then mods:get-language-label($languageTerm)
            else ()
};

(:~
: The <em>mods:get-role-label-for-detail-view</em> function returns 
: the <em>human-readable value</em> of the roleTerm passed to it.
: Whereas mods:get-role-label-for-detail-view returns the author/creator roles that are placed in front of the title in detail view,
: mods:get-role-label-for-detail-view returns the secondary roles that are placed after the title in list view and in relatedItem in detail view.
: The value occurs in mods/name/role/roleTerm.
: It can have two types, text and code.
: Type code can use the marcrelator authority, recorded in the code table role-codes.xml.
: The most commonly used values are checked first, letting the function exit quickly.
: The function returns the human-readable label, based on searches in the code values and in the label values.  
:
: @param $node A mods element or attribute recording a role term value, in textual or coded form
: @return The role term label string
:)
declare function mods:get-role-label-for-detail-view($roleTerm as item()?) as item()? {        
        let $roleLabel :=
            (: Is the roleTerm a role label? :)
            let $roleLabel := doc(concat($config:edit-app-root, '/code-tables/role-codes.xml'))/code-table/items/item[upper-case(label) eq upper-case($roleTerm)]/label
            (: Prefer the label proper, since it contains the form presented in the detail view, e.g. "Editor" instead of "edited by". :)
            return
                if ($roleLabel)
                then $roleLabel
                else
                    (: Is the roleTerm a role term @code? :)
                    let $roleLabel := doc(concat($config:edit-app-root, '/code-tables/role-codes.xml'))/code-table/items/item[value eq $roleTerm]/label
                    return
                        if ($roleLabel)
                        then $roleLabel
                        else $roleTerm
        return  functx:capitalize-first($roleLabel)
};

declare function mods:get-roles-for-detail-view($name as element()*) as item()* {
    if ($name/mods:role/mods:roleTerm/text())
    then
        let $roles := $name/mods:role    
            for $role at $pos in $name/mods:role
            return
                distinct-values(
                    if ($pos eq 1)
                    then mods:get-role-terms-for-detail-view($role)
                    else (' and ', mods:get-role-terms-for-detail-view($role))
                )
    else
        (: Default values in the absence of $roleTerm. :)
        if ($name/@type eq 'corporate')
        then 'Corporation'
        else 'Author'
};

declare function mods:get-role-terms-for-detail-view($role as element()*) as item()* {
    let $roleTerms := $role/mods:roleTerm
    for $roleTerm at $pos in distinct-values($roleTerms)
    
    return
	    if ($roleTerm)
	    then mods:get-role-label-for-detail-view($roleTerm)
	    else ()

};

(:~
: The <em>mods:get-role-label-for-list-view</em> function returns 
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
declare function mods:get-role-label-for-list-view($roleTerm as xs:string*) as xs:string* {
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
        return ($roleLabel, ' ')
};

declare function mods:add-part($part, $sep as xs:string) {
    if (empty($part) or string-length($part[1]) eq 0) 
    then ()
    else concat(string-join($part, ' '), $sep)
};

declare function mods:get-publisher($publishers as element(mods:publisher)*) as item()* {
        string-join(
	        for $publisher in $publishers
	        return
	        	(: NB: Using name here is an expansion of the MODS schema.:)
	            if ($publisher/mods:name)
	            then mods:retrieve-name($publisher/mods:name, 1, 'secondary', '')
	            else $publisher
        , 
        (: If there is a transliterated publisher, probably only one publisher is referred to. :)
        if ($publishers[@transliteration] or $publishers[mods:name/@transliteration])
        then ' '
        else
        ' and ')
};



declare function mods:generate-swd-url($label as xs:string, $url as xs:string)
{
<a href="http://d-nb.info/gnd/
{
$url
}" target="_blank">
{let $x := $label
return $x
}
</a>
};


(: ### <subject> begins ### :)

(: format subject :)
declare function mods:format-subjects($entry as element(), $global-transliteration) {
    for $subject in ($entry/mods:subject)
    let $authority := 
        if ($subject/@authority/string()='local')
        then concat('(', ($subject/@authority/string()), ')') 
        else if ($subject/@authority/string()='swd')
        then concat('(', ($subject/@authority/string()), '*)')
        else ()
    order by fn:lower-case($subject) ascending
    return
    <tr xmlns="http://www.w3.org/1999/xhtml">
    <td class="label subject">Subject {$authority}</td>
    <td class="record"><table class="subject">
    {
    for $item in ($subject/mods:*)
    let $authority := $item/@authority/string()
    let $encoding := 
        if ($item/@encoding/string()) 
        then concat('(', ($item/@encoding/string()), ')') 
        else ()
    let $type := 
        if ($item/@type/string()) 
        then concat('(', ($item/@type/string()), ')') 
        else ()        
   
     order by fn:lower-case($item) ascending
    return
        <tr><td class="sublabel">
            {
            replace(functx:capitalize-first(functx:capitalize-first(functx:camel-case-to-words(replace($item/name(), 'mods:',''), ' '))),'Info',''),
            $authority, $encoding, $type
            }
        </td><td class="subrecord">
            {
            (: If there is a child. :)
            if ($item/mods:*) 
            then
            	(: If it is a name. :)
                if ($item/name() eq 'name')
                then mods:format-name($item, 1, 'primary', $global-transliteration)
                else
                	(: If it is a titleInfo. :)
                    if ($item/name() eq 'titleInfo')
                    (: NB: What if there is more than one titleInfo? Here one steps out of the iteration. :)
                    then string-join(mods:get-short-title($item/..), '')
                    else
                    	(: If it is something else, such as topic (caught by $subitem/name()). :)
                        for $subitem in ($item/mods:*)
                        let $authority := 
                            if ($subitem/@authority/string()) 
                            then concat('(', ($subitem/@authority/string()), ')') 
                            else ()
                        let $encoding := 
                            if ($subitem/@encoding/string()) 
                            then concat('(', ($subitem/@encoding/string()), ')') 
                            else ()
                        let $type := 
                            if ($subitem/@type/string()) 
                            then concat('(', ($subitem/@type/string()), ')') 
                            else ()    
                        return
                        <table><tr><td class="sublabel">
                            {functx:capitalize-first(functx:camel-case-to-words(replace($subitem/name(), 'mods:',''), ' ')),
                        $authority, $encoding}
                        </td><td><td class="subrecord">                
                            {$subitem/string()}
                        </td></td></tr></table>
            else
	            <table><tr><td class="subrecord" colspan="2">{
	            
	            (:if it is a swd subject, identified by ####:)
	            let $swd := 
	            if (fn:exists(fn:tokenize( $item/string(),'#+')[2]))
	            then (mods:generate-swd-url(fn:tokenize($item/string(),'#+')[2],fn:tokenize($item/string(),'#+')[1]) )
	            else ($item/string())
	            return $swd
	            }</td></tr></table>
            }
            </td></tr>
    }
    </table></td>
    </tr>
};

(: ### <subject> ends ### :)

(: ### <extent> begins ### :)

(: <extent> belongs to <physicalDescription>, to <part> as a top level element and to <part> under <relatedItem>. 
Under <physicalDescription>, <extent> has no subelements.:)



declare function mods:get-extent($extent as element(mods:extent)?) as xs:string? {
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
                else string-join($extent/string(), ' ')    
};

declare function mods:get-date($date as element()*) as xs:string* {
    (: contains no subelements. :)
    (: has: encoding; point; qualifier. :)
    (: NB: some dates have keyDate. :)

let $start := $date[@point eq 'start']/text()
let $end := $date[@point eq 'end']/text()
let $qualifier := $date/@qualifier/text()

let $encoding := $date/@encoding
return
    (
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
        else $date
    ,
    if ($qualifier) 
    then ('(', $qualifier, ')')
    else ()
    )
};

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
    
declare function mods:get-place($places as element(mods:place)*) as xs:string? {
    string-join(
        for $place in $places
        let $placeTerms := $place/mods:placeTerm
        return
        	string-join(
	        	for $placeTerm in $placeTerms
	        	let $order := 
	            if ($placeTerm/@transliteration) 
	            then 0 
	            else 1
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
    ,
    (: If there is a transliterated place term, probably only one place is referred to. :)
    if ($places[@transliteration] or $places[mods:placeTerm/@transliteration])
        then ' '
        else
        ' and ')
};

(: NB: This function should be split up in a part and an originInfo function.:)
(: <part> is found both as a top level element and under <relatedItem>. $entry can be both mods and relatedItem. :)
(: NB: where is the relatedItem type? :)
(: Used in list view and display of related items in list and detail view. :)
declare function mods:get-part-and-origin($entry as element()) {
    let $originInfo := $entry/mods:originInfo[1]
    (: contains: place, publisher, dateIssued, dateCreated, dateCaptured, dateValid, 
       dateModified, copyrightDate, dateOther, edition, issuance, frequency. :)
    (: has: lang; xml:lang; script; transliteration. :)
    let $place := $originInfo/mods:place
    (: contains: placeTerm. :)
    (: has no attributes. :)
    (: handled by get-place(). :)
    
    let $publisher := $originInfo/mods:publisher
    (: contains no subelements. :)
    (: has no attributes. :)
    (: handled by get-publisher(). :)
    
    let $dateIssued := $originInfo/mods:dateIssued[1]
    (: contains no subelements. :)
    (: has: encoding; point; keyDate; qualifier. :)
    let $dateCreated := $originInfo/mods:dateCreated
    (: contains no subelements. :)
    (: has: encoding; point; keyDate; qualifier. :)
    let $dateCaptured := $originInfo/mods:dateCaptured
    (: contains no subelements. :)
    (: has: encoding; point; keyDate; qualifier. :)
    let $dateValid := $originInfo/mods:dateValid
    (: contains no subelements. :)
    (: has: encoding; point; keyDate; qualifier. :)
    let $dateModified := $originInfo/mods:dateModified
    (: contains no subelements. :)
    (: has: encoding; point; keyDate; qualifier. :)
    let $copyrightDate := $originInfo/mods:copyrightDate
    (: contains no subelements. :)
    (: has: encoding; point; keyDate; qualifier. :)
    let $dateOther := $originInfo/mods:dateOther
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
	let $dateOriginInfo := mods:get-date($dateOriginInfo)
	
    (: NB: this should iterate over part, since there are e.g. multi-part installments of articles. :)
    let $part := $entry/mods:part[1]
    (: contains: detail, extent, date, text. :)
    (: has: type, order, ID. :)
    let $detail := $part/mods:detail
    (: contains: number, caption, title. :)
    (: has: type, level. :)
        let $issue := $detail[@type=('issue', 'number')]/mods:number[1]/text()
        let $volume := 
        	if ($detail[@type='volume']/mods:number/text())
        	then $detail[@type='volume']/mods:number/text()
			(: NB: to accommodate erroneous Zotero export. Only number is valid. :)
        	else $detail[@type='volume']/mods:text/text()
        (: NB: Does $page exist? :)
        let $page := $detail[@type='page']/mods:number/text()
        (: $page resembles list. :)
    
    let $extent := $part/mods:extent
    (: contains: start, end, total, list. :)
    (: has: unit. :)
    (: handled by mods:get-extent(). :)
    
    (: NB: If the date of a periodical issue is wrongly put in originInfo/dateIssued. Delete when MODS export is corrected.:)
    let $datePart := 
	    if ($part/mods:date) 
	    then mods:get-date($part/mods:date)
	    else $dateOriginInfo
    (: contains no subelements. :)
    (: has: encoding; point; qualifier. :)
    
    let $text := $part/mods:text
    (: contains no subelements. :)
    (: has no attributes. :)
    
    return
        (: If there is a part with issue information and a date, i.e. if the publication is an article in a periodical. :)
        (: NB: "not($place or $publisher" is a little risky since full entries of periodicals have these elements. :)
        if ($datePart and ($volume or $issue or $extent or $page) and not($place or $publisher)) 
        then 
            concat(
            ' '
            ,
            if ($volume and $issue)
            then concat($volume, ', no. ', $issue
            	,
            	concat(' (', $datePart, ')')    
			    )
            (: concat((if ($part/mods:detail/mods:caption) then $part/mods:detail/mods:caption/string() else '/'), $part/mods:detail[@type='issue']/mods:number) :)
            else
            	if ($issue or $volume)
            	then
                (: If the year is used as volume. :)
	                if ($issue)
	                then concat(
	                	concat(' ', $datePart)
			            , ', no. ', $issue)
	                else concat($volume, concat(' (', string-join($datePart, ', '), ')'))
				else
					if ($extent and $datePart)
				(: We have date and extent alone. :)
					then concat(' ', $datePart)
					else ()
				,	
				(: NB: We assume that there will not both be $page and $extent.:)
				if ($extent) 
				then concat(': ', mods:get-extent($extent[1]), '.')
				else
					if ($page) 
					then concat(': ', $page[1], '.')
					else '.'
            )
        else
            (: If there is a dateIssued (loaded in $datePart) and a place or a publisher, i.e. if the publication is an an edited volume. :)
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
                	then concat(': ', mods:get-extent($extent))
                	else
	                	if ($volume and $page)
	                	then concat(': ', $page)
	                	else
	                		if ($extent)
                			then concat(', ', mods:get-extent($extent))
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
                then concat('. ', mods:get-place($place))
                else ()
                ,
                if ($place and $publisher)
                then (': ', mods:get-publisher($publisher))
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
                then mods:get-place($place)
                else ()
                ,
                if ($publisher)
                then (
	                	if ($place)
	                	then ': '
	                	else ()
                	, normalize-space(mods:add-part(mods:get-publisher($publisher), ', '))
                	)
                else ()
                , 
                mods:add-part($dateOriginInfo
                , 
                if (exists($entry/mods:relatedItem[@type='host']/mods:part/mods:extent) or exists($entry/mods:relatedItem[@type='host']/mods:part/mods:detail))
                then '.'
                else ()
                )
                ,
                if (exists($extent/mods:start) or exists($extent/mods:end) or exists($extent/mods:list))
                then (': ', mods:get-extent($extent))            
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
    let $date := ($entry/mods:originInfo[1]/mods:dateIssued/string()[1], $entry/mods:part/mods:date/string()[1],
            $entry/mods:originInfo[1]/mods:dateCreated/string())[1]
    let $conference := $entry/mods:name[@type eq 'conference']/mods:namePart
    return
    if ($conference) 
    then
        concat('Paper presented at ', 
            mods:add-part($conference/string(), ', '),
            mods:add-part($entry/mods:originInfo[1]/mods:place/mods:placeTerm, ', '),
            $date
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
        concat('Paper presented at ', $conference/string()
            (: , mods:add-part($entry/mods:originInfo/mods:place/mods:placeTerm, ', '), $date:)
            (: no need to duplicate placeinfo in detail view. :)
        )
    else ()
};

declare function mods:format-name($name as element()?, $pos as xs:integer, $caller as xs:string, $global-transliteration as xs:string) {	
	(: $nameLanguageLabel is retrieved only in order to get the name order. :)
	let $nameLanguageLabel :=
        if ($name/@lang)
        then mods:get-language-label($name/@lang)
        else mods:language-of-resource($name/../mods:language)
    let $nameOrder := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[label eq $nameLanguageLabel]/nameOrder/string()
    let $nameStyle :=
        if ($nameLanguageLabel = ('Chinese','Japanese','Korean','Vietnamese'))
        then 'EastAsian'
        else 'not'
    let $nameType := $name/@type
    
    return   
    (: If the name is (erroneously) not typed (as personal corporate, conference, or family), then string-join the transliterated name parts and string-join the untransliterated nameParts. :)
    (: NB: One could also decide to treat it as a personal name. :)
        if (not($nameType))
        then
            concat(
                (: The namespace is masked because it refers to both the mods and the mads prefix.:)
                string-join($name/*:namePart[exists(@transliteration)], ' ')
                , ' ', 
                string-join($name/*:namePart[not(@transliteration)], ' ')
            )
        (: If the name is typed :)
        else    
            (: If the name is type conference. :)
        	if ($nameType eq 'conference') 
        	then ()
        	(: Do nothing, since get-conference-detail-view and get-conference-hitlist take care of conference. :)
            else    
                (: If the name is type corporate. :)
                if ($nameType eq 'corporate') 
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
                (: The assumption is that any sequence of corporate name parts is meaningfully constructed, e.g. with more general term first. :)
                (: NB: this is the same as no type. :)
                (: NB: Make conditional for remaining MODS 3.4. type value: "family". :)
                (: If the name is type personal. This is the last option. :)        
                else
                    (: Split up the name parts into three groups: 
                    1. Base: those that do not have a transliteration attribute and that do not have a script attribute (or have Latin script).
                    2. Transliteration: those that have transliteration and do not have script (or have Latin script, which all transliterations have implicitly).
                    3. Script: those that do not have transliteration, but have script (but not Latin script, which characterises transliterations). :)
                    (: NB: The assumption is that transliteration is always in Latin script, but - obviously - it may e.g. be in Cyrillic script. :)
                    (: If the above three name groups occur, they should be formatted in the sequence of 1, 2, and 3. 
                    Only in rare cases will 1, 2, and 3 occur together (e.g. a Westerner with name form in Chinese characters or a Chinese with an established Western-style name form different from the transliterated name form. 
                    In the case of persons using Latin script to render their name, only 1 will be used. Here we have the typical Western names.
                    In the case of e.g. Chinese or Russian names, only 2 and 3 will be used. 
                    Only 3 will be used if no transliteration is given.
                    Only 2 will be used if only transliteration is given. :)
                    (: When formatting a name, $pos is relevant to the formatting of Base, i.e. to Western names, and to Russian names in Script and Transliteration. 
                    Hungarian is special, in that it uses Latin script, but has the name order family-given. :)
                    (: When formatting a name, the first question to ask is whether the name parts are typed, i.e. are divded into given and family name parts (plus date and terms of address). 
                    If they are not, there is really not much one can do, besides concatenating the name parts and trusting that their sequence is meaningful. :)
                    (: NB: If the name is translated from one language to another (e.g. William the Conqueror, Guillaume le Conquérant), there will be two $nameBasic, one for each language. This is not handled. :)
                    (: NB: If the name is transliterated in two ways, there will be two $nameTransliteration, one for each transliteration scheme. This is not handled. :)
                    (: NB: If the name is rendered in two scripts, there will be two $nameScript, one for each script. This is not handled. :)
    				let $nameContainsTransliteration := 
    					if ($name[*:namePart[@transliteration]])
    					then 1
    					else
    						if ($global-transliteration)
    						then 1
    						else 0
                    (: If the name does not contain a namePart with transliteration, it is a basic name, i.e. a name where the distinction between the name in native script and in transliteration does not arise. 
                    Typical examples are Western names, but also include Eastern names where no effort has been taken to distinguish between native script and transliteration. 
                    Filtering like this would leave out names where Westerners have Chinese names, and in order to catch these, we require that they have language set to English. :)
                    let $nameBasic :=
	                    if (not($nameContainsTransliteration))
	                    then <name>{$name/*:namePart[not(@transliteration) and (not(@script) or @script = ('Latn', 'latn', 'Latin'))]}</name>
                    	else <name>{$name/*:namePart[@lang eq 'eng']}</name>
                    	
                    (: If there is transliteration, there are nameParts with transliteration. 
                    To filter these, we seek nameParts
                    which contain the transliteration attribute, even though this may be empty (this is special to the templates, since they allow the user to set a global transliteration value, to be applied whereever an empty transliteration attribute occurs; and
                    which do not contain the script attribute or which have the script attribute set to Latin (defining of transliterations here). :)
                    (: NB: Should English names be filtered away?:)
                    let $nameTransliteration := 
                    	if ($nameContainsTransliteration)
                    	then <name>{$name/*:namePart[@transliteration and (not(@script) or (@script = ('Latn', 'latn', 'Latin')))]}</name>
                    	else ()
                    
                    (: If there is transliteration, the presumption must be that all nameParts which are not transliterations (and which do not have the language set to English) are names in non-Latin script. We filter for nameParts
                    which do no have the transliteration attribute or have one with no contents, and
                    which do not have script set to Latin, and
                    which do not have English as their language. :)
                    let $nameScript := 
	                    if ($nameContainsTransliteration)
	                    then <name>{$name/*:namePart[(not(@transliteration) or string-length(@transliteration) eq 0) and not(@script = ('Latn', 'latn', 'Latin')) and not(@lang='eng')]}</name>
	                    else ()
                    (: We assume that there is only one date name part. The date name parts with transliteration and script are rather theoretical. This date is attached at the end of the name. :)
                    let $dateBase := $name/*:namePart[@type eq 'date'][1]
                    
                    (: We try only the most obvious place for a lang and script attribute on namePart. :)
                    (: NB: Only the first value is chosen, so names cannot have several language. :)
                    let $namePartFamilyLanguage := $name/*:namePart[type eq 'family'][1]/@lang
                    let $namePartLanguage :=
                        if ($namePartFamilyLanguage)
                        then mods:get-language-label($namePartFamilyLanguage)
                        else ()
                    let $namePartLanguageLabel :=
                        (: If there is language on namePart, use that; otherwise use language on name. :)
                        if ($namePartLanguage)
                        then $namePartLanguage
                        else $nameLanguageLabel
                    (: If there is lang on namePart, use that for retrieving the name order; otherwise use language on name (or, if this did not exist when it was set, the language of the resource as a whole. :)
                    let $nameOrder := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[label eq $namePartLanguageLabel]/nameOrder/string()
                    
                    return
                        concat(
                        (: ## 1 ##:)
                        if ($nameBasic/string())
                        (: If there are one or more name parts that are not marked as being transliteration and that are not marked as having a certain script (aside from Latin). :)
                        then
                        (: Filter the name parts according to type. :)
                            let $untyped := <name>{$nameBasic/*:namePart[not(@type)]}</name>
                            let $family := <name>{$nameBasic/*:namePart[@type eq 'family']}</name>
                            let $given := <name>{$nameBasic/*:namePart[@type eq 'given']}</name>
                            let $termsOfAddress := <name>{$nameBasic/*:namePart[@type eq 'termsOfAddress']}</name>
                            (: let $date := <name>{$nameBasic/*:namePart[@type eq 'date']}</name> :)
                            
                            return
                                if ($untyped/string())
                                (: If there are name parts that are not typed, there is nothing we can do to order their sequence. When name parts are not typed, it is generally because the whole name occurs in one name part, formatted for display (usually with a comma between family and given name), but a name part may also be untyped when (non-Western) names that cannot (easily) be divided into family and given names are in evidence. We trust that any sequence of nameparts are meaningfully ordered and simply string-join them. :)
                                then string-join($untyped/*:namePart, ' ') 
                                else
                                (: If the name parts are typed, we have here a name divided into given and family name (and so on), a name that is not a transliteration and that is not in a non-Latin script: an ordinary (Western) name. :)
                                    if ($pos eq 1 and $caller eq 'primary')
                                    (: If the name occurs first in primary position (i.e. first in author position in list view) and the name is not a name that occurs in family-given sequence (is not an Oriental or Hungarian name), then format it with a comma between the family name and the given name, with the family name placed first, and append the term of address. :)
                                    (: Dates are appended last, once for the whole name. :)
                                    (: Example: "Freud, Sigmund, Dr. (1856-1939)". :)
                                    then
                                        concat(
                                            (: There may be several instances of the same type of name part; these are joined with a space in between. :)
                                            string-join($family/*:namePart, ' ') 
                                            ,
                                            if ($family/string() and $given/string())
                                            (: If only one of family and given are evidenced, no comma is needed. :)
                                            then
                                                if ($nameOrder eq 'family-given')
                                                (: If the name is Hungarian, use a space; otherwise (i.e. in most cases) use a comma. :)
                                                then ' '
                                                else ', '
                                            else ()
                                            ,
                                            string-join($given/*:namePart, ' ') 
                                            ,
                                            if ($termsOfAddress/string())
                                            (: If there are several terms of address, join them with a comma in between ("Dr., Prof."). :)
                                            then concat(', ', string-join($termsOfAddress/*:namePart, ', ')) 
                                            else ()
                                            (:
                                            ,
                                            if ($date/string() and $family/string() and $given/string()) 
                                            then concat(' (', string-join($date/*:namePart, ', '),')')
                                            else ()
                                            :)
                                        )
                                    else
                                        if ($nameOrder eq 'family-given')
                                        (: If the name is Hungarian and does not occur in primary position. :)
                                        then 
                                            concat(
                                                string-join($family/*:namePart, ' ') 
                                                ,
                                                if ($family/string() and $given/string())
                                                then ' '
                                                else ()
                                                ,
                                                string-join($given/*:namePart, ' ') 
                                                ,
                                                if ($termsOfAddress/string())
                                                (: NB: Where do terms of address go in Hungarian? :)
                                                then concat(', ', string-join($termsOfAddress/*:namePart, ', ')) 
                                                else ()
                                                (:
                                                ,
                                                if ($date/string()) 
                                                then concat(' (', string-join($date/*:namePart, ', '),')')
                                                else ()
                                                :)
                                            )
                                        else
                                        (: In all other situations, the name order is given-family, with a space in between. :)
                                        (: Example: "Dr. Sigmund Freud (1856-1939)". :)
                                                    concat(
                                                        if ($termsOfAddress/text())
                                                        then concat(string-join($termsOfAddress/*:namePart, ', '), ' ')
                                                        else ()
                                                        ,
                                                        string-join($given/*:namePart, ' ')
                                                        ,
                                                        if ($family/string() and $given/string())
                                                        then ' '
                                                        else ()
                                                        ,
                                                        string-join($family/*:namePart, ' ')
                                                        (:
                                                        ,
                                                        if ($date/text())
                                                        then concat(' (', string-join($date/*:namePart, ', '), ')')
                                                        else ()
                                                        :)
                                                    )
                        else ()
                        , 
                        ' '
                        , 
                        (: If there is an "English" name, enclose the transliterated and Eastern script name in parenthesis. :)
                        if ($name/*:namePart[@lang eq 'eng'])
                        then ' ('
                        else ()
                        ,
                        (: ## 2 ##:)
                        if ($nameTransliteration/string())
                        (: We have a name in transliteration. This can e.g. be a Chinese name or a Russian name. :)
                        then
                            let $untypedTransliteration := <name>{$nameTransliteration/*:namePart[not(@type)]}</name>
                            let $familyTransliteration := <name>{$nameTransliteration/*:namePart[@type eq 'family']}</name>
                            let $givenTransliteration := <name>{$nameTransliteration/*:namePart[@type eq 'given']}</name>
                            let $termsOfAddressTransliteration := <name>{$nameTransliteration/*:namePart[@type eq 'termsOfAddress']}</name>
                            (: let $dateTransliteration := <name>{$nameTransliteration/*:namePart[@type eq 'date']}</name> :)
                            
                            return       
                                if ($untypedTransliteration/string())
                                then string-join($untypedTransliteration/*:namePart, ' ') 
                                else
                                (: The name parts are typed, so we have a name that is a transliteration and that is divided into given and family name. If the name order is family-given, we have an ordinary Oriental name in transliteration, if the name order is givenfamily, we have e.g. a Russian name in transliteration. :)
                                    if ($pos eq 1 and $caller eq 'primary' and $nameOrder ne 'family-given')
                                    (: If the name occurs first in primary position (i.e. first in list view) and the name is not a name that occurs in family-given sequence, e.g. a Russian name, format it with a comma between family name and given name, with family name placed first. :)
                                    then
                                    concat(
                                        string-join($familyTransliteration/*:namePart, ' ') 
                                        , 
                                        if ($familyTransliteration/string() and $givenTransliteration/string())
                                        then ', '
                                        else ()
                                        ,
                                        string-join($givenTransliteration/*:namePart, ' ') 
                                        ,
                                        if ($termsOfAddressTransliteration/string()) 
                                        then concat(', ', string-join($termsOfAddressTransliteration/*:namePart, ', ')) 
                                        else ()
                                        (:
                                        ,
                                        if ($dateTransliteration/string()) 
                                        then concat(' (', string-join($dateTransliteration/*:namePart, ', '),')')
                                        else ()
                                        :)
                                    )
                                    else
                                    (: In all other situations, the name order is given-family; the difference is whether there is a space between the name parts and the order of name proper and the address. :)
                                    (: Example: "Dr. Sigmund Freud (1856-1939)". :)
                                        if ($nameOrder ne 'family-given')
                                        (: If it is e.g. a Russian name. :)
                                        then
                                            concat(
                                                if ($termsOfAddressTransliteration/string()) 
                                                then concat(', ', string-join($termsOfAddressTransliteration/*:namePart, ', ')) 
                                                else ()
                                                ,
                                                string-join($givenTransliteration/*:namePart, ' ')
                                                ,
                                                if ($familyTransliteration/string() and $givenTransliteration/string())
                                                then ' '
                                                else ()
                                                ,
                                                string-join($familyTransliteration/*:namePart, ' ')
                                                (:
                                                ,
                                                if ($dateTransliteration/text())
                                                then concat(' (', string-join($dateTransliteration, ', ') ,')')
                                                else ()
                                                :)
                                            )
                                        else
                                        (: If it is e.g. a Chinese name. :)
                                            concat(
                                                string-join($familyTransliteration, '')
                                                ,
                                                if ($familyTransliteration/string() and $givenTransliteration/string())
                                                then ' '
                                                else ()
                                                ,
                                                string-join($givenTransliteration, '')
                                                ,
                                                if ($termsOfAddressTransliteration/string()) 
                                                then concat(' ', string-join($termsOfAddressTransliteration/*:namePart, ' ')) 
                                                else ()
                                                (:
                                                ,
                                                if ($dateTransliteration/text())
                                                then concat(' (', string-join($dateTransliteration, ', ') ,')')
                                                else ()
                                                :)
                                            )
                            else ()
                            , ' ',
                            (: ## 3 ##:)
                                if ($nameScript/string())
                                then
                                    let $untypedScript := <name>{$nameScript/*:namePart[not(@type)]}</name>
                                    let $familyScript := <name>{$nameScript/*:namePart[@type eq 'family']}</name>
                                    let $givenScript := <name>{$nameScript/*:namePart[@type eq 'given']}</name>
                                    let $termsOfAddressScript := <name>{$nameScript/*:namePart[@type eq 'termsOfAddress']}</name>
                                    (: let $dateScript := <name>{$nameScript/*:namePart[@type eq 'date']}</name> :)
                                    let $languageScript :=
                                        if ($familyScript/@lang)
                                        then mods:get-language-label($familyScript/@lang)
                                        else ()
                                    let $language :=
                                        if ($languageScript)
                                        then $languageScript
                                        else $nameLanguageLabel
                                    let $nameOrder := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/*:code-table/*:items/*:item[*:label eq $language]/*:nameOrder/string()
                                    return       
                                        if ($untypedScript/string())
                                        (: If the name parts are not typed, there is nothing we can do to order their sequence. When name parts are not typed, it is generally because the whole name occurs in one name part, formatted for display (usually with a comma between family and given name), but it may also be used when names that cannot be divided into family and given names are in evidence. We trust that any sequence of nameparts are meaningfully ordered and string-join them. :)
                                        then string-join($untypedScript, ' ') 
                                        else
                                        (: The name parts are typed, so we have a name that is not a transliteration, that is not in a non-Latin script and that is divided into given and family name. An ordinary Western name. :)
                                            if ($pos eq 1 and $caller eq 'primary' and $nameOrder ne 'family-given')
                                            (: If the name occurs first in primary position (i.e. first in list view) and the name is not a name that occurs in family-given sequence, format it with a comma between family name and given name, with family name placed first. :)
                                            then
                                            concat(
                                                string-join($familyScript/*:namePart, ' ')
                                                , 
                                                if ($familyScript/string() and $givenScript/string())
                                                then ', '
                                                else ()
                                                ,
                                                string-join($givenScript/*:namePart, ' ')
                                                ,
                                                if ($termsOfAddressScript/string()) 
                                                then concat(', ', string-join($termsOfAddressScript, ', ')) 
                                                else ()
                                                (:
                                                ,
                                                if ($dateScript/string()) 
                                                then concat(' (', string-join($dateScript, ', '),')')
                                                else ()
                                                :)
                                            )
                                            else
                                                if ($nameOrder ne 'family-given')
                                                (: If the name does not occur first in primary position (i.e. first in list view) and if the name does not occur in family-given sequence, format it with a space between given name and family name, with given name placed first. This would be the case with Russian names that are not first in author position in the list view. :)
                                                then
                                                    concat(
                                                        if ($termsOfAddressScript/string())
                                                        then concat(string-join($termsOfAddressScript, ', '), ' ')
                                                        else ()
                                                        ,
                                                        string-join($givenScript/*:namePart, ' ')
                                                        ,
                                                        if ($familyScript/string() and $givenScript/string())
                                                        then ' '
                                                        else ()
                                                        ,
                                                        string-join($familyScript/*:namePart, ' ')
                                                        (:
                                                        ,
                                                        if ($dateScript/string())
                                                        then concat(' (', string-join($dateScript, ', ') ,')')
                                                        else ()
                                                        :)
                                                    )
                                                else
                                                (: $nameOrder eq 'family-given'. Here we have e.g. Chinese names which are the same wherever they occur, with no space or comma between given and family name. :)
                                                    concat(
                                                        string-join($familyScript, '')
                                                        ,
                                                        string-join($givenScript, '')
                                                        ,
                                                        string-join($termsOfAddressScript, '')
                                                        (:
                                                        ,
                                                        if ($dateScript/string())
                                                        then concat(' (', string-join($dateScript, ', ') ,')')
                                                        else ()
                                                        :)
                                                    )
                                else ()
                            ,     
	                        (: Close Chinese alias.:)
	                        if ($name/*:namePart[@lang eq 'eng'])
	                        then ') '
	                        else ()
	                        ,
	                        (: Finish off by giving the dates of the person, in parenthesis.:)
                            if ($dateBase)
                            then concat(' (', $dateBase, ')')
                            else ()
                            )
};

declare function mods:get-authority-name-from-mads($mads as element(), $caller as xs:string) {
    let $auth := $mads/mads:authority/mads:name
    return
        mods:format-name($auth, 1, $caller, '')   
};

(: NB: also used in search.xql :)
(: Each name in the list view should have an authority name added to it in parentheses, if it exists and is different from the name as given in the mods record. :)
declare function mods:retrieve-name($name as element(), $pos as xs:int, $caller as xs:string, $global-transliteration as xs:string) {    
    let $mods-name := mods:format-name($name, $pos, $caller, $global-transliteration)
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
                else mods:format-name($mads-record/mads:name, 1, $caller, $global-transliteration)
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
: Used to retrieve the preferred name from the MADS authority file.    
: @param
: @return
: @see
:)
declare function mods:retrieve-mads-names($name as element(), $pos as xs:int, $caller as xs:string) {    
    let $mads-reference := replace($name/@xlink:href, '^#?(.*)$', '$1')
    let $mads-record :=
        if (empty($mads-reference)) 
        then ()        
        else collection($config:mads-collection)/mads:mads[@ID eq $mads-reference]
    let $mads-preferred-name :=
        if (empty($mads-record)) 
        then ()
        else $mads-record/mads:authority/mads:name
    let $mads-preferred-name-formatted := mods:format-name($mads-preferred-name, 1, 'primary', '')
    let $mads-variant-names := $mads-record/mads:variant/mads:name
    let $mads-variant-name-nos := count($mads-record/mads:variant/mads:name)
    let $mads-variant-names-formatted := 
    	string-join(
	    	for $name in $mads-variant-names 
    		return mods:format-name($name, 1, 'primary', '')
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

(: Retrieves names. :)
(: Called from mods:format-multiple-names() :)
declare function mods:retrieve-names($entry as element()*, $caller as xs:string, $global-transliteration as xs:string) {
    for $name at $pos in $entry/mods:name
    return
    <span xmlns="http://www.w3.org/1999/xhtml" class="name">{mods:retrieve-name($name, $pos, $caller, $global-transliteration)}</span>
};

(:~
: Formats names for list view and for related items. 
: The function is called from two positions. 
: One is for names of authors etc. that are positioned before the title.
: One is for names of editors etc. that are positioned after the title.
: The $caller param marks where the function is called.
: Names that are positioned before the title have the first name with a comma between family name and given name.
: Names that are positioned after the title have a space between given name and family name throughout. 
: The names positioned before the title are not marked explicitly by use of any role terms.
: The role terms that lead to a name being positioned before the title are author and creator.
: The absence of a role term is also interpreted as the attribution of authorship, so a name without a role term will also be positioned before the title.
: @param
: @return
: @see
:)
declare function mods:format-multiple-names($entry as element()*, $caller as xs:string, $global-transliteration as xs:string) {
    let $names := mods:retrieve-names($entry, $caller, $global-transliteration)
    let $nameCount := count($names)
    let $formatted :=
        if ($nameCount eq 0) 
        then ()
        else 
            if ($nameCount eq 1) 
            then
                if (ends-with(normalize-space($names), '.')) 
                (: Removes period after author name if it ends with a term of address ending in period, such as "Jr." or "Dr.", since a period will be inserted after the primary names(s). :)
                then functx:substring-before-last-match($names, '\.')
                else $names
            else
                if ($nameCount eq 2)
                then
	                concat(
	                    subsequence($names, 1, $nameCount - 1),
	                    (: Places "and" before last name. :)
	                    ' and ',
	                    if (ends-with(normalize-space($names[$nameCount]), '.'))
	                    then functx:substring-before-last-match($names[$nameCount], '\.')
	                    else $names[$nameCount]
	                )
                else 
                    concat(
                        string-join(subsequence($names, 1, $nameCount - 1), 
                        (: Places ", " after all names that do not come last. :)', ')
                        ,
                        (: Places ", and" before name that comes last. :)
                        ', and ',
                        if (ends-with(normalize-space($names[$nameCount]), '.'))
	                    then functx:substring-before-last-match($names[$nameCount], '\.')
	                    else $names[$nameCount]
                        )
    return <span xmlns="http://www.w3.org/1999/xhtml" class="name">{normalize-space($formatted)}</span>
};

(: ### <typeOfResource> begins ### :)

declare function mods:return-type($id as xs:string, $entry ) {
    let $type := $entry/mods:typeOfResource[1]/string()
    return
        if (exists($type)) (:check if the file type is retrieved in mods file:)
    then  
        replace(replace(
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

declare function mods:get-title-translated($entry as element(mods:mods), $titleInfo as element(mods:titleInfo)?) {
    let $titleInfo :=
        if ($titleInfo/@lang = ('ja', 'jpn', 'zh', 'chi', 'kor')) 
        (: NB: check language terms! :)
        then string-join(($entry/mods:titleInfo[@lang = ('en', 'eng')]/mods:title, $entry/mods:titleInfo[@lang = ('en', 'eng')]/mods:subTitle), ' ')
        else ()
    return
        if ($titleInfo) 
        then <span xmlns="http://www.w3.org/1999/xhtml" class="title-translated">{string-join(($titleInfo/mods:title/string(), $titleInfo/mods:subTitle/string()), ' ') }</span>
        else ()
};

(: Constructs a compact title for list view, for subject, and for related items. :)
declare function mods:get-short-title($entry as element()) {
    (: If the entry has a host related item with an extent in part, it is a periodical article of a contribution to an edited volume and should be enclosed in quotation marks. :)
    let $quotes := 
    	if (exists($entry/mods:relatedItem[@type='host']/mods:part/mods:extent) or exists($entry/mods:relatedItem[@type='host']/mods:part/mods:detail))
    	then 1
    	else ()
    
    let $titleInfo := $entry/mods:titleInfo[not(@type=('abbreviated', 'uniform', 'alternative'))]
    let $titleInfoTransliteration := $titleInfo[@transliteration][1]
    let $titleInfoTranslation := $titleInfo[@type='translated' and not(@transliteration)][1]
    let $titleInfo := $titleInfo[not(@type)][not(@transliteration)][1]
    
    let $nonSort := $titleInfo/mods:nonSort
    let $title := $titleInfo/mods:title
    let $subTitle := $titleInfo/mods:subTitle
    let $partNumber := $titleInfo/mods:partNumber
    let $partName := $titleInfo/mods:partName
    
    let $nonSortTransliteration := $titleInfoTransliteration/mods:nonSort
    let $titleTransliteration := $titleInfoTransliteration/mods:title
    let $subTitleTransliteration := $titleInfoTransliteration/mods:subTitle
    let $partNumberTransliteration := $titleInfoTransliteration/mods:partNumber
    let $partNameTransliteration := $titleInfoTransliteration/mods:partName
    
    let $nonSortTranslation := $titleInfoTranslation/mods:nonSort
    let $titleTranslation := $titleInfoTranslation/mods:title
    let $subTitleTranslation := $titleInfoTranslation/mods:subTitle
    let $partNumberTranslation := $titleInfoTranslation/mods:partNumber
    let $partNameTranslation := $titleInfoTranslation/mods:partName
        
    let $titleFormat := 
        (
        if ($nonSort/string()) 
        then concat($nonSort, ' ' , $title)
        (: NB: Why need to trim? :)
        else functx:trim($title)
        , 
        if ($subTitle/string()) 
        then concat(': ', $subTitle)
        else ()
        ,
        if ($partNumber/string() or $partName/string())
        then
            if ($partNumber/string() and $partName/string()) 
            then concat('. ', $partNumber, ': ', $partName)
            else
                if ($partNumber/string())
                then concat('. ', $partNumber)
                else
                    if ($partName/string())
                    then concat('. ', $partName)
            		else ()
        else ()
        )
        
    let $titleTransliterationFormat := 
        (
        if ($nonSortTransliteration) 
        then concat($nonSortTransliteration, ' ' , $titleTransliteration)
        else $titleTransliteration
        , 
        if ($subTitleTransliteration) 
        then concat(': ', $subTitleTransliteration)
        else ()
        ,
        if ($partNumberTransliteration or $partNameTransliteration)
        then
            if ($partNumberTransliteration and $partNameTransliteration) 
            then concat('. ', $partNumberTransliteration, ': ', $partNameTransliteration)
            else
                if ($partNumberTransliteration)
                then concat('. ', $partNumberTransliteration)
                else
                    if ($partNameTransliteration)
                    then concat('. ', $partNameTransliteration)
            		else ()
        else ()
        )
        
    let $titleTranslationFormat := 
        (
        if ($nonSortTranslation) 
        then concat($nonSortTranslation, ' ' , $titleTranslation)
        else $titleTranslation
        , 
        if ($subTitleTranslation) 
        then concat(': ', $subTitleTranslation)
        else ()
        ,
        if ($partNumberTranslation or $partNameTranslation)
        then
            if ($partNumberTranslation and $partNameTranslation) 
            then concat('. ', $partNumberTranslation, ': ', $partNameTranslation)
            else
                if ($partNumberTranslation)
                then concat('. ', $partNumberTranslation)
                else
                    if ($partNameTranslation)
                    then concat('. ', $partNameTranslation)
            		else ()
        else ()
        )
        
    return
        ( 
        if ($quotes)
        (: Do not use ordinary quotation marks, in order not to conflict with the cleanup function. :)
        then ' “'
        else ''
        ,
        (
		if ($titleTransliteration) 
        then (<span xmlns="http://www.w3.org/1999/xhtml" class="title">{string-join($titleTransliterationFormat, ' ')}</span>, ' ')
        else ()
        , 
        if ($titleTransliteration)
        (: If there is a transliteration, the title in original script should not be italicised. :)
        then <span xmlns="http://www.w3.org/1999/xhtml" class="title-no-italics">{string-join($titleFormat, '')}</span>
        else
        	if ($quotes)
        	then <span xmlns="http://www.w3.org/1999/xhtml" class="title-no-italics">{string-join($titleFormat, '')}</span>
        	else <span xmlns="http://www.w3.org/1999/xhtml" class="title">{string-join($titleFormat, '')}</span>
        ,
        if ($quotes and $titleTranslation) 
        then '”'
        else 
	        if ($quotes)
	        then '.”'
	        else ''
        ,
        if ($titleTranslation)
        then <span xmlns="http://www.w3.org/1999/xhtml" class="title"> ({$titleTranslationFormat})</span>
        else ()
        ,
        if ($quotes and $titleTranslation) 
        then '.'
        else '' 
        )
        )
};

(: Constructs title for the detail view. :)
declare function mods:title-full($titleInfo as element(mods:titleInfo)) {
if ($titleInfo)
    then
    <tr xmlns="http://www.w3.org/1999/xhtml">
        <td class="label">
        {
            if (($titleInfo/@type eq 'translated') and not($titleInfo/@transliteration)) 
            then 'Translated Title'
            else 
                if ($titleInfo/@type eq 'abbreviated') 
                then 'Abbreviated Title'
                else 
                    if ($titleInfo/@type eq 'alternative') 
                    then 'Alternative Title'
                    else 
                        if ($titleInfo/@type eq 'uniform') 
                        then 'Uniform Title'
                        else 
                            if ($titleInfo[@transliteration]) 
                            then 'Transliterated Title'
                            else 'Title'
        }
        <span class="deemph">
        {
        let $lang := $titleInfo/@lang/string()
        let $xml-lang := $titleInfo/@xml:lang/string()
        return
            if ($lang or $xml-lang)
            then        
            (
            <br/>, 'Language: '
            ,
            let $lang3 := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/*:code-table/*:items/*:item[*:value eq $lang]/*:label
            return
                if ($lang3)
                then $lang3
                else
                    let $lang2 := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/*:code-table/*:items/*:item[*:valueTwo eq $lang]/*:label
                    return
                        if ($lang2) 
                        then $lang2
                        else
                            let $lang3 := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/*:code-table/*:items/*:item[*:valueTwo eq $titleInfo/@xml:lang]/*:label
                            return
                                if ($lang3)
                                then $lang3
                                else
                                    if ($lang)
                                    then $lang
                                    else
                                        if ($xml-lang)
                                        then $xml-lang
                                        else ()
            ) 
            else ()
        }
        {
        
        let $transliteration := $titleInfo/@transliteration/string()
        let $recordTransliteration := $titleInfo/../mods:extension/e:transliterationOfResource
        let $transliteration := 
        	if ($transliteration)
        	then $transliteration
        	else $recordTransliteration
        return
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

declare function mods:get-related-items($entry as element(mods:mods), $caller as xs:string) {
    for $item in $entry/mods:relatedItem
    let $type := $item/@type
    let $ID := $item/@ID
    let $displayLabel := $item/@displayLabel
    let $titleInfo := $item/mods:titleInfo
    let $labelDisplayed :=
        string(
        if ($displayLabel)
        then $displayLabel
        else
            if ($type)
            then functx:capitalize-first(functx:camel-case-to-words($type, ' '))
            else 'Related Item'
        )
    let $part := $item/mods:part
    let $xlink := replace($item/@xlink:href, '^#?(.*)$', '$1')
    let $xlinkRecord :=
        (: Any MODS record in /db/resources is retrieved if there is a @xlink:href/@ID match and the relatedItem has no string value. If there should be duplicated, only the first record is retrieved.:)
        if (($xlink) and (collection($config:mods-root)//mods:mods[@ID eq $xlink]) and (not($titleInfo))) 
        then collection($config:mods-root)//mods:mods[@ID eq $xlink]
        else ()
    let $relatedItem :=
    	if ($xlinkRecord) 
    	(: NB: There must be a smarter way to merge the retrieved relatedItem with the native part! :)
    	(:update insert $part into $xlinkRecord:)
    	then <mods:relatedItem ID="{$ID}" displayLabel ="{$displayLabel}" type="{$type}" xlink:href="{$xlink}">{($xlinkRecord/mods:titleInfo, $part)}</mods:relatedItem> 
    	else
    		if ($item/mods:titleInfo/mods:title/text())
    		then $item
    		else ()
    return
        (: Check for the most common types first. :)
        if ($relatedItem)
        then
	        if ($type = ('host', 'series'))
	        then
	            if ($caller eq 'hitlist')
	            then
	                <span xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-span">
	                	<span class="relatedItem-record">{mods:format-related-item($relatedItem)}</span>
	                </span>
	            else
	                if ($caller eq 'detail' and string($xlink))
	                then
	                    <tr xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-row">
							<td class="url label relatedItem-label">
	                            <a href="?filter=ID&amp;value={$xlink}">&lt;&lt; In:</a>
	                        </td>
	                        <td class="relatedItem-record">
								<span class="relatedItem-span">{mods:format-related-item($relatedItem)}</span>
	                        </td>
	                    </tr>
	                else
	                    if ($caller eq 'detail')
	                    then
	                    <tr xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-row">
							<td class="url label relatedItem-label">In:</td>
	                        <td class="relatedItem-record">
								<span class="relatedItem-span">{mods:format-related-item($relatedItem)}</span>
	                        </td>
	                    </tr>
	                    else ()
	        (: if @type is not 'host' or 'series':)
	        else
	            if ($caller eq 'detail' and string($xlink))
	            then
	                <tr xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-row">
						<td class="url label relatedItem-label">
	                        <a href="?filter=ID&amp;value={$xlink}">&lt;&lt; {$labelDisplayed}</a>
	                    </td>
	                    <td class="relatedItem-record">
							<span class="relatedItem-span">{mods:format-related-item($relatedItem)}</span>
	                    </td>
	                </tr>
	            else
	                if ($caller eq 'detail')
	                then
	                <tr xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-row">
	                    <td class="url label relatedItem-label">
	                        {$type}
	                    </td>
	                    <td class="relatedItem-record">
	                        <span class="relatedItem-span">{mods:format-related-item($relatedItem)}</span>
	                    </td>
	                </tr>
	                else ()
        else ()
};

declare function mods:format-related-item($relatedItem as element()) {
	let $relatedItem := mods:remove-parent-with-missing-required-node($relatedItem)
	let $global-transliteration := $relatedItem/../mods:extension/e:transliterationOfResource/text()
	return
    mods:clean-up-punctuation(<result>{(
    if ($relatedItem/mods:name/mods:role/mods:roleTerm = ('aut', 'author', 'Author', 'cre', 'creator', 'Creator') or not($relatedItem/mods:name/mods:role/mods:roleTerm))
    then mods:format-multiple-names($relatedItem, 'primary', $global-transliteration)
    else ()
    ,
    mods:get-short-title($relatedItem)
    ,
    let $roleTerms := $relatedItem/mods:name/mods:role/mods:roleTerm
    return
        for $roleTerm in distinct-values($roleTerms)
            where $roleTerm = ('com', 'compiler', 'editor', 'edt', 'trl', 'translator', 'annotator', 'ann')        
                return
                    let $names := <entry>{$relatedItem/mods:name[mods:role/mods:roleTerm eq $roleTerm]}</entry>
                        return
                            if ($names/string())
                            then
                                (
                                ', '
                                ,
                                mods:get-role-label-for-list-view($roleTerm)
                                ,
                                mods:format-multiple-names($names, 'secondary', $global-transliteration)
                                )
                            else ()
    ,
    mods:get-part-and-origin($relatedItem)
    ,                
    if ($relatedItem/mods:location/mods:url/text()) 
    then concat(' <', $relatedItem/mods:location/mods:url, '>')
    else ()
        
                  
	)}</result>)
};

(: ### <relatedItem> ends ### :)

declare function mods:names-full($entry as element(), $global-transliteration) {
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
                    mods:format-name($name, 1, 'primary', $global-transliteration)
                    }
                    {
                    if ($name/@xlink:href)
                    then mods:retrieve-mads-names($name, 1,'primary')
                    else ()
                    }</td>
                
                </tr>
};


(:~
: Prepares one or more rows for the detail view.
: @param $data
: @param $label
: @return element(tr)
:)
declare function mods:simple-row($data as item()?, $label as xs:string) as element(tr)? {
    for $d in $data
    return
        <tr xmlns="http://www.w3.org/1999/xhtml">
            <td class="label">{$label}</td>
            <td class="record">{string($d)}</td>
        </tr>
};

(: Creates view for detail view. :)
(: NB: "mods:format-detail-view()" is referenced in session.xql. :)
declare function mods:format-detail-view($id as xs:string, $entry as element(mods:mods), $collection-short as xs:string) {
	let $ID := $entry/@ID
	let $entry := mods:remove-parent-with-missing-required-node($entry)
	let $global-transliteration := $entry/mods:extension/e:transliterationOfResource/text()
	return
    <table xmlns="http://www.w3.org/1999/xhtml" class="biblio-full">
    {
    
    (: names :)
    if ($entry/mods:name)
    then mods:names-full($entry, $global-transliteration)
    else ()
    ,
    
    (: titles :)
    for $titleInfo in $entry/mods:titleInfo
    return mods:title-full($titleInfo)
    ,
    
    (: conferences :)
    mods:simple-row(mods:get-conference-detail-view($entry), 'Conference')
    ,

    (: place :)
    (:simlified for the priya paul collection:)
    for $place in $entry/mods:originInfo/mods:place
        return mods:simple-row($place, 'Place')
    ,
    
     
    (: publisher :)
        (: If a transliterated publisher name exists, this probably means that several publisher names are simply different script forms of the same publisher name. Place the transliterated name first, then the original script name. :)
        if ($entry/mods:originInfo[1]/mods:publisher[@transliteration])
        then
	        mods:simple-row(
	            string-join(
		            for $publisher in $entry/mods:originInfo[1]/mods:publisher
		            let $order := 
			            if ($publisher[@transliteration]) 
			            then 0 
			            else 1
		        	order by $order
		        	return mods:get-publisher($publisher)
	        	, ' ')
	        ,
			'Publisher')
		else
		(: Otherwise we have a number of different publishers.:)
			for $publisher in $entry/mods:originInfo[1]/mods:publisher
	        return mods:simple-row(mods:get-publisher($publisher), 'Publisher')
	,
	
    (: dates :)
    (:If a related item has a date, use it instead of a date in originInfo:)   
    if ($entry/mods:relatedItem[@type eq 'host']/mods:originInfo[1]/mods:dateCreated) 
    then ()
    else 
        for $date in $entry/mods:originInfo[1]/mods:dateCreated
            return mods:simple-row($date, 
            concat('Date Created',
                if ($date/@point) then concat(' (', functx:capitalize-first($date/@point), ')') else (),
                if ($date/@qualifier) then concat(' (', functx:capitalize-first($date/@qualifier), ')') else ()
                )
            )
    ,
    if ($entry/mods:relatedItem[@type eq 'host']/mods:originInfo[1]/mods:copyrightDate) 
    then () 
    else 
        for $date in $entry/mods:originInfo[1]/mods:copyrightDate
            return mods:simple-row($date, 
            concat('Copyright Date',
                if ($date/@point) then concat(' (', functx:capitalize-first($date/@point), ')') else (),
                if ($date/@qualifier) then concat(' (', functx:capitalize-first($date/@qualifier), ')') else ()
                )
            )
    ,
    if ($entry/mods:relatedItem[@type eq 'host']/mods:originInfo[1]/mods:dateCaptured) 
    then () 
    else 
        for $date in $entry/mods:originInfo[1]/mods:dateCaptured
            return mods:simple-row($date, 
            concat('Date Captured',
                if ($date/@point) then concat(' (', functx:capitalize-first($date/@point), ')') else (),
                if ($date/@qualifier) then concat(' (', functx:capitalize-first($date/@qualifier), ')') else ()
                )
            )            
    ,
    if ($entry/mods:relatedItem[@type eq 'host']/mods:originInfo[1]/mods:dateValid) 
    then () 
    else 
        for $date in $entry/mods:originInfo[1]/mods:dateValid
            return mods:simple-row($date, 
            concat('Date Valid',
                if ($date/@point) then concat(' (', functx:capitalize-first($date/@point), ')') else (),
                if ($date/@qualifier) then concat(' (', functx:capitalize-first($date/@qualifier), ')') else ()
                )
            )
    ,
    if ($entry/mods:relatedItem[@type eq 'host']/mods:originInfo[1]/mods:dateIssued) 
    then () 
    else 
        for $date in $entry/mods:originInfo[1]/mods:dateIssued
            return mods:simple-row($date, 
            concat(
                'Date Issued', 
                if ($date/@point) then concat(' (', functx:capitalize-first($date/@point), ')') else (),
                if ($date/@qualifier) then concat(' (', functx:capitalize-first($date/@qualifier), ')') else ()
                )
            )
    ,
    if ($entry/mods:relatedItem[@type eq 'host']/mods:originInfo[1]/mods:dateModified) 
    then () 
    else 
        for $date in $entry/mods:originInfo[1]/mods:dateModified
            return mods:simple-row($date, 
            concat('Date Modified',
                if ($date/@point) then concat(' (', functx:capitalize-first($date/@point), ')') else (),
                if ($date/@qualifier) then concat(' (', functx:capitalize-first($date/@qualifier), ')') else ()
                )
            )
    ,
    if ($entry/mods:relatedItem[@type eq 'host']/mods:originInfo[1]/mods:dateOther) 
    then () 
    else 
        for $date in $entry/mods:originInfo[1]/mods:dateOther
            return mods:simple-row($date, 
            concat('Other Date',
                if ($date/@point) then concat(' (', functx:capitalize-first($date/@point), ')') else (),
                if ($date/@qualifier) then concat(' (', functx:capitalize-first($date/@qualifier), ')') else ()
                )
            )            
    ,
    (: edition :)
    if ($entry/mods:originInfo[1]/mods:edition) 
    then mods:simple-row($entry/mods:originInfo[1]/mods:edition, 'Edition') 
    else ()
    ,
    
    
    (: extent :)
    let $extent := $entry/mods:physicalDescription/mods:extent
    return
        if ($extent) 
        then mods:simple-row(
            mods:get-extent($extent), 
            concat('Extent', 
                if($extent/@unit) 
                then concat(' (', functx:capitalize-first($extent/@unit), ')') 
                else ()
                )
            )    
        else ()
    ,
    
     (: recordidentifier :)
    for $items in $entry/mods:recordInfo/mods:recordIdentifier
    
    let $item := 
        if ($items/@source eq  'HeidICON') 
        then    <a href="http://heidicon.ub.uni-heidelberg.de/id/{  $items/string() }" target="_blank">{$items/string()}</a>
 
        else ()
    let $type :=''    
    return 
    <tr xmlns="http://www.w3.org/1999/xhtml">
            <td class="label">Heidicon Link</td>
            <td class="record">{$item}</td>
        </tr>
    
    ,
    
    (: URL :)
    for $url-out in $entry/mods:location
            let $url := $url-out/mods:url
            let $prev := $url-out/mods:url/@access='preview'
            return
            if ($prev)
            then ()
            else(
            (:not a preview picture:)
              <tr xmlns="http://www.w3.org/1999/xhtml">
                <td class="label"> 
                { concat(
                if ($url/@displayLabel)
                    then $url/@displayLabel/text()
                else( 
                    
                    if (string-length($url)>0)
                    then ('URL')
                    else()
                   )
                
                ,
                if ($url/@dateLastAccessed)
                then concat(' (Last Accessed: ', $url/@dateLastAccessed, ')')
                else ''
                )
                }
                </td>
                <td  class="record"><a href="{$url}" target="_blank">{if ((string-length($url) < 80)) then $url  else (substring($url,1,70), '...')}</a></td>
                </tr> 
                )
         
               
                
                
    ,
    (: relatedItem :)
    mods:get-related-items($entry, 'detail')
    ,
    (: typeOfResource :)
    mods:simple-row($entry/mods:typeOfResource[1]/string(), 'Type of Resource')
    ,
    
    (: format:) 
    for $format in $entry/mods:physicalDescription/mods:form
        return mods:simple-row($format, 'Material')
    ,
    
    (: internetMediaType :)
    mods:simple-row(
    (
	    let $label := doc(concat($config:edit-app-root, '/code-tables/internet-media-type-codes.xml'))/*:code-table/*:items/*:item[*:value eq $entry/mods:physicalDescription[1]/mods:internetMediaType]/*:label
	    return
	        if ($label) 
	        then $label
	        else $entry/mods:physicalDescription[1]/mods:internetMediaType)
    , 'Internet Media Type')
    ,
    
    (: language :)
    if ($entry/mods:language)
    then
        mods:simple-row(string-join(
            for $language in $entry/mods:language
            return
            mods:language-of-resource($language)
            , ', ')
        , 
        if (count($entry/mods:language) > 1) 
        then 'Languages of Resource' 
        else 'Language of Resource'
        )
    else
        if ($entry/mods:relatedItem/mods:language)
        then
            mods:simple-row(string-join(
                for $language in $entry/mods:relatedItem/mods:language
                return
                mods:language-of-resource($language), ', ')
                ,
                if (count($entry/mods:relatedItem/mods:language) > 1) 
                then 'Languages of Resource' 
                else 'Language of Resource'
            )
        else ()
    ,

    (: script :)
    if ($entry/mods:language)
    then
        for $language in $entry/mods:language
        return
        mods:simple-row(mods:script-of-resource($language), 'Script of Resource')
    else
        if ($entry/mods:relatedItem/mods:language)
        then
            for $language in $entry/mods:relatedItem/mods:language
            return
            mods:simple-row(mods:script-of-resource($language), 'Script of Resource')
        else ()
    ,

    (: languageOfCataloging :)
    for $language in ($entry/mods:recordInfo/mods:languageOfCataloging)
    let $languageTerm := $language/mods:languageTerm 
    return    
	    if ($languageTerm)
	    then mods:simple-row(mods:language-of-cataloging($language), 'Language of Cataloging')
	    else ()
    ,

    (: genre :)
    for $genre in ($entry/mods:genre)
    let $authority := $genre/@authority/string()
    return   
        mods:simple-row(
            if ($authority eq 'local')
                then doc(concat($config:edit-app-root, '/code-tables/genre-local-codes.xml'))/*:code-table/*:items/*:item[*:value eq $genre]/*:label
                else
                	if ($authority eq 'marcgt')
                	then doc(concat($config:edit-app-root, '/code-tables/genre-marcgt-codes.xml'))/*:code-table/*:items/*:item[*:value eq $genre]/*:label
					else $genre/string()
                , 
                concat(
                    'Genre'
                    , 
                    if ($authority)
                    then
                        if ($authority eq 'marcgt')
                        then ' (MARC genre terms)'
                        else concat(' (', $authority, ')')
                    else ()            
            )
    )
    ,
    
    (: abstract :)
    for $abstract in ($entry/mods:abstract)
    return
    mods:simple-row($abstract, 'Abstract')
    ,
    
      (: note :)
    for $note in ($entry/mods:note)
    let $displayLabel := $note/@displayLabel    
    let $type := $note/@type
    return
        (: NB: some notes contain escaped html markup! :)    
	    mods:simple-row(replace($note, '&lt;.*?&gt;', '')
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
    (: We assume that there are not many subjects with the first element, topic, empty. :)
    if (normalize-space($entry/mods:subject[1]/string()))
    then mods:format-subjects($entry, $global-transliteration)    
    else ()
    , 
    (: identifier :)
    for $item in $entry/mods:identifier
    let $type := 
        if ($item/@type/string()) 
        then concat(' (', ($item/@type/string()), ')') 
        else ()
    return mods:simple-row($item, concat('Identifier', upper-case($type)))
    ,
    (: classification :)
    for $item in $entry/mods:classification
    let $authority := 
        if ($item/@authority/string()) 
        then concat(' (', ($item/@authority/string()), ')') 
        else ()
    return mods:simple-row($item, concat('Classification', $authority))
    ,
    for $access in $entry/mods:accessCondition
    let $access_value := $access
    return mods:simple-row($access, 'Acess condition')
    ,
    (:Copyright:)
    
    (: records referring to current record if current record is a periodical or an edited volume :)
    if (1)(:($entry/mods:genre = ('periodical', 'editedVolume', 'newspaper', 'journal', 'festschrift', 'encyclopedia', 'conference publication')):) 
    then
        let $linked-ID := concat('#',$ID)
        let $linked-records := collection($config:mods-root)//mods:mods[mods:relatedItem[@type eq 'host']/@xlink:href eq $linked-ID]
        (:let $log := util:log("DEBUG", ("##$linked-records): ", $linked-records)):)
        let $linked-records-count := count($linked-records) 
        return
        if ($linked-records-count gt 5)
        then
            <tr xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-row">
                <td class="url label relatedItem-label">
                    <a href="?action=&amp;filter=XLink&amp;value={$linked-ID}">&lt;&lt; Catalogued Contents:</a>
                </td>
                <td class="relatedItem-record">
                    <span class="relatedItem-span">{$linked-records-count}</span>
                </td>
            </tr>
        else
            for $linked-record in $linked-records
            (:let $log := util:log("DEBUG", ("##$linked-record): ", $linked-record)):)
            let $link-ID := $linked-record/@ID
            let $link-contents := 
                if ($linked-record/mods:titleInfo/mods:title/text()) 
                then mods:format-list-view((), $linked-record) 
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
    <tr>
        <td class="collection-label">In Folder:</td>
        <td><div class="collection">{uu:unescape-collection-path($collection-short)}</div></td>
    </tr>
    
    
    }
    </table>
};

(: Creates view for hitlist. :)
(: NB: "mods:format-list-view()" is referenced in session.xql. :)
declare function mods:format-list-view($id as xs:string, $entry as element(mods:mods)) {
	let $entry := mods:remove-parent-with-missing-required-node($entry)
	let $global-transliteration := $entry/mods:extension/e:transliterationOfResource/text()
	return
    let $format :=
        (
        (: The author, etc. of the primary publication. :)
        (: NB: conference? :)
        let $names := <entry>{$entry/mods:name[@type = ('personal', 'corporate', 'family') or not(@type)][(mods:role/mods:roleTerm = ('aut', 'author', 'Author', 'cre', 'creator', 'Creator')) or not(mods:role/mods:roleTerm)]}</entry>
        return
	        if ($names/string())
	        then (mods:format-multiple-names($names, 'primary', $global-transliteration)
	        , '. ')
	        else ()
        ,
        (: The title of the primary publication. :)
        mods:get-short-title($entry)
        ,
        let $roleTerms := $entry/mods:name/mods:role/mods:roleTerm[. = ('com', 'compiler', 'Compiler', 'editor', 'Editor', 'edt', 'trl', 'translator', 'Translator', 'annotator', 'Annotator', 'ann')]
        return
	        (if (not($entry/mods:relatedItem[@type eq 'host']) and not($roleTerms)) 
	        then '.'
	        else ''
	    ,
        (: The editor, etc. of the primary publication. :)
        for $roleTerm in distinct-values($roleTerms)        
            return
                (: NB: Can the wrapper be avoided? :)
                let $names := <entry>{$entry/mods:name[mods:role/mods:roleTerm eq $roleTerm]}</entry>
                return
                    (
                    (: Introduce secondary role with comma. :)
                    (: NB: What if there are multiple secondary roles? :)
                    ', '
                    ,
                    mods:get-role-label-for-list-view($roleTerm)
                    ,
                    mods:format-multiple-names($names, 'secondary', $global-transliteration)
                    (: Terminate secondary role with period. :)
                    ,
			        if (not($entry/mods:relatedItem[@type eq 'host']) and ($roleTerms)) 
			        then ''
			        else '.'
                    )
                    )
        , ' '
        ,
        (: The conference of the primary publication, containing originInfo and part information. :)
        if ($entry/mods:name[@type eq 'conference']) 
        then mods:get-conference-hitlist($entry)
        (: If not a conference publication, get originInfo and part information for the primary publication. :)
        else mods:get-part-and-origin($entry)    
        ,
        (: The periodical, edited volume or series that the primary publication occurs in. :)
        (: if ($entry/mods:relatedItem[@type=('host','series')]/mods:part/mods:extent or $entry/mods:relatedItem[@type=('host','series')]/mods:part/mods:detail/mods:number/text()) :)
        if ($entry/mods:relatedItem[@type = ('host','series')])
        then <span xmlns="http://www.w3.org/1999/xhtml" class="relatedItem-span">{mods:get-related-items($entry, 'hitlist')}</span>
        else () 
        (: The url of the primary publication. :)
(:        	if ($entry/mods:location/mods:url/text())
        	then
            	for $url in $entry/mods:location/mods:url
	                return
                    (\: NB: Too long URLs do not line-wrap, forcing the display of results down below the folder view, so do not display too long URLs. The link is anyway not clickable. :\)
	                if (string-length($url) < 90)
	                then concat(' <', $url, '>', '.')
    	            else ""
        	else '.'
:)        )
    return
        mods:clean-up-punctuation(<span xmlns="http://www.w3.org/1999/xhtml" class="record">{$format}</span>)
};