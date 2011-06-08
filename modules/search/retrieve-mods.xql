module namespace mods="http://www.loc.gov/mods/v3";

declare namespace mads="http://www.loc.gov/mads/";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace fo="http://www.w3.org/1999/XSL/Format";
declare namespace functx = "http://www.functx.com"; 

import module namespace config="http://exist-db.org/mods/config" at "../config.xqm";

declare option exist:serialize "media-type=text/xml";

(: TODO: A lot of restrictions to the first item in a sequence ([1]) have been made; these must all be changed to for-structures or string-joins. :)
(: TODO: With the new cleanup script, the results received have no empty attributes and no empty elements; there are no titleInfo with empty title and no name with empty namePart. A lot of checking for these should be rolled back. :)

(: ### general functions begin ###:)

(:~
: Used to transform the camel-case names of MODS elements into space-separated words.  
: @param
: @return
: @see http://www.xqueryfunctions.com/xq/functx_camel-case-to-words.html
:)
declare function functx:camel-case-to-words($arg as xs:string?, $delim as xs:string ) as xs:string? {
   concat(substring($arg,1,1), replace(substring($arg,2),'(\p{Lu})', concat($delim, '$1')))
};

(:~primary-
: Used to capitalize the first character of $arg.   
: @param
: @return
: @see http://http://www.xqueryfunctions.com/xq/functx_capitalize-first.html
:)
declare function functx:capitalize-first( $arg as xs:string? ) as xs:string? {       
   concat(upper-case(substring($arg,1,1)),
             substring($arg,2))
};
 
(:~
: Used to remove whitespace at the beginning and end of a string.   
: @param
: @return
: @see http://http://www.xqueryfunctions.com/xq/functx_trim.html
:)
declare function functx:trim( $arg as xs:string? )  as xs:string {       
   replace(replace($arg,'\s+$',''),'^\s+','')
 } ;
 
(: not used :)
declare function mods:space-before($node as node()?) as xs:string? {
    if (exists($node)) then
        concat(' ', $node)
    else
        ()
};

(:~
: Used to clean up unintended sequences of punctuation. These should ideally be removed at the source.   
: @param
: @return
:)
(: Function to clean up unintended punctuation. These should ideally be removed at the source. :)
declare function mods:clean-up-punctuation($input as xs:string?) as xs:string? {
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
        $input
    , '\s*\)', ')')
    , ' \.', '.')
    , '\s*,', ',')
    , ' :', ':')
    , ' ”', '”')
    , '\s*;', ';')
    , '\.\.', '.')
    , ',,', ',')
    , '“ ', '“')
    , '”\.', '.”')
    , '\. ,', ',') (: Fixes mistake in originInfo for periodicals. :)
    , ',\s*\.', '') (: Fixes mistake in originInfo for periodicals. :)
    , '\?\.', '?')
    , '!\.', '!')
    ,'\.” \.', '.”')
    ,' \)', ')')
    ,'\( ', '(')
    ,'\.\.', '.')
    ,'\.”,', ',”')
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
declare function mods:language-of-resource($language as element(mods:language)*) as xs:anyAtomicType* {
        let $languageTerm := $language/mods:languageTerm[1]
        return
            if ($languageTerm) 
            then
                mods:get-language-label($languageTerm)
            else ()
};

declare function mods:script-of-resource($language as element(mods:language)*) as xs:anyAtomicType* {
        let $scriptTerm := $language/mods:scriptTerm
        return
            if ($scriptTerm) 
            then
                mods:get-script-term($language)
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
            then
                mods:get-language-label($languageTerm)
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
            let $roleLabel := doc(concat($config:edit-app-root, '/code-tables/role-codes.xml'))/code-table/items/item[upper-case(label) = upper-case($roleTerm)]/label
            (: Prefer the label proper, since it contains the form presented in the detail view, e.g. "Editor" instead of "edited by". :)
            return
                if ($roleLabel)
                then $roleLabel
                else
                    (: Is the roleTerm a role term @code? :)
                    let $roleLabel := doc(concat($config:edit-app-root, '/code-tables/role-codes.xml'))/code-table/items/item[value = $roleTerm]/label
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
        if ($name/@type = 'corporate')
        then 'Corporation'
        else 'Author'
};

declare function mods:get-role-terms-for-detail-view($role as element()*) as item()* {
    let $roleTerms := $role/mods:roleTerm
    for $roleTerm at $pos in distinct-values($roleTerms)
    
    return
    if ($roleTerm)
    then
        mods:get-role-label-for-detail-view($roleTerm)
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
            let $roleLabel := doc(concat($config:edit-app-root, '/code-tables/role-codes.xml'))/code-table/items/item[upper-case(label) = upper-case($roleTerm)]/labelSecondary
            (: Prefer labelSecondary, since it contains the form presented in the list view output, e.g. "edited by" instead of "editor". :)
            return
                if ($roleLabel)
                then $roleLabel
                else
                    let $roleLabel := doc(concat($config:edit-app-root, '/code-tables/role-codes.xml'))/code-table/items/item[value = $roleTerm]/labelSecondary
                    return
                        if ($roleLabel)
                        then $roleLabel
                        else
                            let $roleLabel := doc(concat($config:edit-app-root, '/code-tables/role-codes.xml'))/code-table/items/item[upper-case(label) = upper-case($roleTerm)]/label
                            (: If there is no labelSecondary, take the label. :)
                            return
                                if ($roleLabel)
                                then $roleLabel
                                else
                                    let $roleLabel := doc(concat($config:edit-app-root, '/code-tables/role-codes.xml'))/code-table/items/item[value = $roleTerm]/label
                                    return
                                        if ($roleLabel)
                                        then $roleLabel
                                            else $roleTerm
                                            (: Do not present default values in case of absence of $roleTerm, since primary roles are not displayed in list view. :)
        return $roleLabel
};

declare function mods:add-part($part, $sep as xs:string) {
    if (empty($part) or string-length($part[1]) eq 0) 
    then ()
    else concat(string-join($part, ' '), $sep)
};

declare function mods:get-publisher($publishers as element(mods:publisher)*) as xs:string? {
    string-join(
        for $publisher in $publishers
        let $order := 
            if ($publisher[@transliteration]) 
            then 0 
            else 1
        order by $order
        return
            if ($publisher/mods:name)
            then
                for $name at $pos in $publisher/mods:name
                return
                    mods:retrieve-name($name, $pos, 'secondary')
            else
                $publisher
    , ', ')
};


(: ### <subject> begins ### :)

(: format subject :)
declare function mods:format-subjects($entry as element()) {
    for $subject in ($entry/mods:subject)
    let $authority := 
        if ($subject/@authority/string()) 
        then concat('(', ($subject/@authority/string()), ')') 
        else ()
    return
    <tr>
    <td class="label subject">Subject {$authority}</td>
    <td class="record"><table class="subject">
    {
    for $item in ($subject/mods:*)
    let $authority := 
        if ($item/@authority/string()) 
        then concat('(', ($item/@authority/string()), ')') 
        else ()
    let $encoding := 
        if ($item/@encoding/string()) 
        then concat('(', ($item/@encoding/string()), ')') 
        else ()
    let $type := 
        if ($item/@type/string()) 
        then concat('(', ($item/@type/string()), ')') 
        else ()        
    return
        <tr><td class="sublabel">
            {
            replace(functx:capitalize-first(functx:capitalize-first(functx:camel-case-to-words(replace($item/name(), 'mods:',''), ' '))),'Info',''),
            $authority, $encoding, $type
            }
        </td><td class="subrecord">
            {
            if ($item/mods:*) 
            then
                if ($item/name() = 'name')
                then 
                    mods:format-name($item, 1, 'primary')
                else
                    if ($item/name() = 'titleInfo')
                    then 
                        string-join(mods:get-short-title('', $item/.., ''), '')
                    else
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
            <table><tr><td class="subrecord" colspan="2">
            {$item/string()}
            </td></tr></table>
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
let $unit := functx:trim($extent/@unit/string())
let $start := functx:trim($extent/mods:start/string())
let $end := functx:trim($extent/mods:end/string())
let $total := functx:trim($extent/mods:total/string())
let $list := functx:trim($extent/mods:list/string())
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
        if ($start != $end)
        then
        concat($start, '-', $end)
        else
        $start        
    else 
        if ($start or $end) 
        then 
            if ($start)
            then $start
            else $end
        (: if not $start or $end. :)
        else
            if ($total) 
            then concat('(', $total, ')')
            else
                if ($list) 
                then $list
                else string-join($extent/string(), ' ')    
};

declare function mods:get-date($date as element(mods:date)*) as xs:string* {
    (: contains no subelements. :)
    (: has: encoding; point; qualifier. :)
    (: some dates have keyDate. :)
let $start := $date[@point = 'start']/text()
let $end := $date[@point = 'end']/text()
let $qualifier := $date/@qualifier
let $encoding := $date/@encoding
return
    (
    if ($start and $end) 
    then 
        if ($start != $end)
        then concat($start, '-', $end)
        else $start        
    else 
        if ($start or $end) 
        then 
            if ($start)
            then ($start, '-')
            else ('-', $end)
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
    (: NB: Should iterate over both place and placeTerm. :)
    string-join(
        for $place in $places
        let $placeTerm := $place/mods:placeTerm
        let $order := 
            if ($placeTerm/@transliteration) 
            then 0 
            else 1
        order by $order
        return
            if ($placeTerm[@type = 'text']/text()) 
            then concat(
                $placeTerm[@transliteration]/text()
                ,
                ' '
                ,
                $placeTerm[not(@transliteration)]/text()
                )
            else
                if ($placeTerm[@authority = 'marccountry']/text()) 
                then
                    doc(concat($config:edit-app-root, '/code-tables/marc-country-codes.xml'))/code-table/items/item[value = $placeTerm]/label
                else 
                    if ($placeTerm[@authority = 'iso3166']/text()) 
                    then
                        doc(concat($config:edit-app-root, '/code-tables/iso3166-country-codes.xml'))/code-table/items/item[value = $placeTerm]/label
                    else
                        $place/mods:placeTerm[not(@type)]/text(),
        ' ')
};

(: <part> is found both as a top level element and under <relatedItem>. :)

declare function mods:get-part-and-origin($entry as element()) {
    let $originInfo := $entry/mods:originInfo
    (: contains: place, publisher, dateIssued, dateCreated, dateCaptured, dateValid, 
       dateModified, copyrightDate, dateOther, edition, issuance, frequency. :)
    (: has: lang; xml:lang; script; transliteration. :)
    let $place := $originInfo/mods:place
    (: contains: placeTerm. :)
    (: has no attributes. :)
    let $publisher := $originInfo/mods:publisher
    (: contains no subelements. :)
    (: has no attributes. :)
    let $dateIssued := $originInfo/mods:dateIssued
    (: contains no subelements. :)
    (: has: encoding; point; keyDate; qualifier. :)    
    
    let $part := $entry/mods:part
    (: contains: detail, extent, date, text. :)
    (: has: type, order, ID. :)
    let $detail := $part/mods:detail
    (: contains: number, caption, title. :)
    (: has: type, level. :)
        let $issue := $detail[@type=('issue', 'number')]/mods:number
        let $volume := $detail[@type='volume']/mods:number
        let $page := $detail[@type='page']/mods:number
        (: $page resembles list. :)
    let $extent := $part/mods:extent
    (: contains: start, end, title, list. :)
    (: has: unit. :)
    let $date := $part/mods:date
    (: contains no subelements. :)
    (: has: encoding; point; qualifier. :)
    return
        (: If there is a part with issue information and a date, i.e. if the publication is an article in a periodical. :)
        if ($detail/mods:number/text() and $date/text()) 
        then 
            concat(
            string-join(
            if ($issue and $volume)
            then
                concat($volume, ', no. ', $issue)
                (: concat((if ($part/mods:detail/mods:caption) then $part/mods:detail/mods:caption/string() else '/'), $part/mods:detail[@type='issue']/mods:number) :)
            else 
                if (not($volume) and ($issue))
                then (', ', $issue)
                else
                    if ($volume and not($issue))
                    then $volume
                    else ()
            , ' ')
            ,
            if ($page) 
            then
                concat(', ', $page)
            else ()
            ,
            if ($date/text())
            then
                concat(' (', mods:get-date($date), ')')
            else ()
            ,
            if ($extent) 
            then
                concat(', ', mods:get-extent($extent[1]), '.')
            else '.'
            )
        else
            (: If there is a dateIssued and a place or a publisher, i.e. if the publication is an an edited volume. :)
            if ($dateIssued and ($place | $publisher)) 
            then
                (
                if ($volume) 
                then
                    concat(', Vol. ', $volume)
                else ()
                ,
                if ($extent)
                then
                    concat(', ', mods:get-extent($extent),'.')
                else ()
                ,
                if ($place)
                then
                    concat('. ', mods:get-place($place))
                else ()
                ,
                if ($place and $publisher)
                then ': '
                else ()
                ,
                if ($publisher)
                then
                    mods:get-publisher($publisher)
                else ()
                ,
                if ($dateIssued)
                then
                concat(', ', $dateIssued[1], '.')
                else ()
                )
            (: If not a periodical and not an edited volume, we don't know what it is and just try to extract the information. :)
            else
                (
                if ($place)
                then
                    mods:get-place($place)
                else ()
                ,
                normalize-space(mods:add-part(mods:get-publisher($publisher), ', ')
                )
                , 
                normalize-space(mods:add-part($dateIssued/string(), '.'))
                ,
                if ($extent)
                then
                    mods:get-extent($extent[1])            
                else ()
                )
};

(: ### <originInfo> ends ### :)

(: ### <relatedItem><part> begins ### :)

(: Application: 'part' is used to provide detailed coding for physical parts of a resource. It may be used as a top level element to designate physical parts or under relatedItem. It may be used under relatedItem for generating citations about the location of a part within a host/parent item. When used with relatedItem type="host", <part> is roughly equivalent to MARC 21 field 773, subfields $g (Relationship information) and $q (Enumeration and first page), but allows for additional parsing of data. There is no MARC 21 equivalent to <part> at the <mods> level. :)
(: Attributes: type, order, ID. :)
    (: Unaccounted for: type, order, ID. :)
(: Suggested values for @type: volume, issue, chapter, section, paragraph, track. :)
    (: Unaccounted for: none. :)
(: Subelements: <detail>, <extent>, <date>, <text>. :)
    (: Unaccounted for: <text>. :)
        (: Problem: <date> does not generally occur in relatedItem. :)
        (: Subelement <extent>. :)
            (: Attribute: type. :)
                (: Suggested values for @type: page, minute. :)
            (: Subelements: <start>, <end>, <total>, <list>. :)
                (: Unaccounted for: <total>, <list>. :)

(: not used. :)
declare function mods:get-related-item-part($entry as element()) {

    let $part := $entry/mods:relatedItem[@type='host'][1]/mods:part
    let $volume := $part/mods:detail[@type='volume']/mods:number
    let $issue := $part/mods:detail[@type='issue']/mods:number
    let $date := $part/mods:date
    let $extent := mods:get-extent($part/mods:extent)

    return
    if ($part or $volume or $issue or $date or $extent) 
    then
        (
            (:if ($volume and $issue) 
            then
                <tr>
                    <td class="label">Volume/Issue</td>
                    <td class="record">{string-join(($volume/string(), $issue/string()), '/')}</td>
                </tr>
            else:) 
            if ($volume) 
            then
                <tr>
                    <td class="label">Volume</td>
                    <td class="record">{$volume/string()}</td>
                </tr>
            else () 
            ,
            if ($issue) 
            then
                <tr>
                    <td class="label">Issue</td>
                    <td class="record">{$issue/string()}</td>
                </tr>
            else ()
            ,
            if ($date) 
            then
                <tr>
                    <td class="label">Date</td>
                    <td class="record">{$date/string()}</td>
                </tr>
            else ()
            ,
            if ($extent) 
            then
                <tr>
                    <td class="label">Extent</td>
                    <td class="record">{$extent}</td>
                </tr>
            else ()
        )
    else ()
};

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
    let $date := ($entry/mods:originInfo/mods:dateIssued/string()[1], $entry/mods:part/mods:date/string()[1],
            $entry/mods:originInfo/mods:dateCreated/string())[1]
    let $conference := $entry/mods:name[@type = 'conference']/mods:namePart
    return
    if ($conference) then
        concat('Paper presented at ', 
            mods:add-part($conference/string(), ', '),
            mods:add-part($entry/mods:originInfo/mods:place/mods:placeTerm, ', '),
            $date
        )
        else
        ()
};

declare function mods:get-conference-detail-view($entry as element()) {
    (:let $date := ($entry/mods:originInfo/mods:dateIssued/string()[1], $entry/mods:part/mods:date/string()[1],
            $entry/mods:originInfo/mods:dateCreated/string())[1]
    return:)
    let $conference := $entry/mods:name[@type = 'conference']/mods:namePart
    return
    if ($conference) then
        concat('Paper presented at ', $conference/string()
            (: , mods:add-part($entry/mods:originInfo/mods:place/mods:placeTerm, ', '), $date:)
            (: no need to duplicate placeinfo in detail view. :)
        )
    else
    ()
};

declare function mods:format-name($name as element()?, $pos as xs:integer, $caller as xs:string) {
    (: Get the label for the lang attribute; if it does not exist, get the language of the resource as such. :)
    let $language :=
        if ($name/@lang)
        then mods:get-language-label($name/@lang)
        else mods:language-of-resource($name/../*:language[1])
    let $nameOrder := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[label = $language]/nameOrder/string()
    let $type := $name/@type
    return   
    (: If the name is (erroneously) not typed (as personal corporate, conference, or family), then string-join the transliterated name parts and string-join the untransliterated nameParts. :)
    (: NB: One could also decide to treat it as a personal name. :)
        if (not($type))
        then
            concat(
                string-join($name/*:namePart[exists(@transliteration)], ' ')
                , ' ', 
                string-join($name/*:namePart[not(@transliteration)], ' ')
            )
        (: If the name is typed :)
        else    
            (: If the name is type conference. :)
        	if ($type = 'conference') 
        	then ()
        	(: Do nothing, since get-conference-detail-view and get-conference-hitlist take care of conference. :)
            else    
                (: If the name is type corporate. :)
                if ($type = 'corporate') 
                then
                    concat(
                        string-join(for $item in $name/*:namePart where exists($item/@transliteration) return $item, ' ')
                        
                        , ' ', 
                        string-join(for $item in $name/*:namePart where not($item/@transliteration) return $item, ' ')
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
                    In the case of e.g. Chinese or Russian names, only 2 and 3 will be used. Only 3 will be used, if no transliteration is given and only 2 will be used, if only transliteration is given. :)
                    (: When formatting a name, $pos is relevant to the formatting of Base, i.e. to Western names, and to Russian names in Script and Transliteration. 
                    Hungarian is special, in that it uses Latin script, but has the name order family-given. :)
                    (: When formatting a name, the first question to ask is whether the name parts are typed, i.e. are divded into given and family name parts (plus date and terms of address). 
                    If they are not, there is really not much one can do, besides concatenating the name parts and trusting that their sequence is meaningful. :)
                    (: NB: If the name is translated from one language to another (e.g. William the Conqueror, Guillaume le Conquérant), there will be two $nameBase, one for each language. This is not handled. :)
                    (: NB: If the name is transliterated in two ways, there will be two $nameTransliteration, one for each transliteration scheme. This is not handled. :)
                    (: NB: If the name is rendered in two scripts, there will be two $nameScript, one for each script. This is not handled. :)
    
                    let $nameBase := <name>{$name/*:namePart[not(@transliteration) and (not(@script) or @script = ('Latn', 'Latin'))]}</name>
                    let $nameTransliteration := <name>{$name/*:namePart[exists(@transliteration) and (not(@script) or @script = ('Latn', 'Latin'))]}</name>
                    let $nameScript := <name>{$name/*:namePart[not(@transliteration) and (exists(@script) or @script = ('Latn', 'Latin'))]}</name>
                    (: We assume that there is only one date name part. The date name parts with transliteration and script are rather theoretical. This date is attached atthe end of the name. :)
                    let $dateBase := $name/*:namePart[@type = 'date'][1]
                    return
                        concat(
                        (: ## 1 ##:)
                        if ($nameBase/string())
                        (: If there are one or more name parts that are not marked as being transliteration and that are not marked as having a certain script (aside from Latin). :)
                        then
                        (: Filter the name parts according to type. :)
                            let $untyped := <name>{$nameBase/*:namePart[not(@type)]}</name>
                            let $family := <name>{$nameBase/*:namePart[@type = 'family']}</name>
                            let $given := <name>{$nameBase/*:namePart[@type = 'given']}</name>
                            let $termsOfAddress := <name>{$nameBase/*:namePart[@type = 'termsOfAddress']}</name>
                            (: let $date := <name>{$nameBase/*:namePart[@type = 'date']}</name> :)
                            let $languageBase :=
                                (: We try only the most obvious place for a lang attribute. :)
                                if ($family/@lang)
                                then mods:get-language-label($family/@lang)
                                else ()
                            let $language :=
                                (: If there is language on namePart, use that; otherwise use language on name. :)
                                if ($languageBase)
                                then $languageBase
                                else $language
                            (: If there is lang on namePart, use that for retrieving the name order; otherwise use language on name (or, if this did not exist when it was set, the language of the resource as a whole. :)
                            let $nameOrder := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[label = $language]/nameOrder/string()
                            return
                                if ($untyped/string())
                                (: If there are name parts that are not typed, there is nothing we can do to order their sequence. When name parts are not typed, it is generally because the whole name occurs in one name part, formatted for display (usually with a comma between family and given name), but a name part may also be untyped when (non-Western) names that cannot (easily) be divided into family and given names are in evidence. We trust that any sequence of nameparts are meaningfully ordered and simply string-join them. :)
                                then string-join($untyped/*:namePart, ' ') 
                                else
                                (: If the name parts are typed, we have here a name divided into given and family name (and so on), a name that is not a transliteration and that is not in a non-Latin script: an ordinary (Western) name. :)
                                    if ($pos = 1 and $caller = 'primary')
                                    (: If the name occurs first in primary position (i.e. first in author position in list view) and the name is not a name that occurs in family-given sequence (is not an Oriental or Hungarian name), then format it with a comma between family name and given name, with family name placed first. :)
                                    (: Example: "Freud, Sigmund, Dr. (1856-1939)". :)
                                    then
                                        concat(
                                            (: There may be several instances of the same type of name part; these are joined with a space in between. :)
                                            string-join($family/*:namePart, ' ') 
                                            ,
                                            if ($family/string() and $given/string())
                                            (: If only one of family and given are evidenced, no comma is needed. :)
                                            then 
                                                if ($nameOrder = 'family-given')
                                                (: If the name is Hungarian, use a space; otherwise (i.e. in most cases) use a comma. :)
                                                then ' '
                                                else ', '
                                            else ()
                                            ,
                                            string-join($given/*:namePart, ' ') 
                                            ,
                                            if ($termsOfAddress/string())
                                            (: If there are several terms of address, join them with a comma in between ("Dr., Prof."). :)
                                            then
                                                concat(', ', string-join($termsOfAddress/*:namePart, ', ')) 
                                            else ()
                                            (:
                                            ,
                                            if ($date/string() and $family/string() and $given/string()) 
                                            then concat(' (', string-join($date/*:namePart, ', '),')')
                                            else ()
                                            :)
                                        )
                                    else
                                        if ($nameOrder = 'family-given')
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
                                                then
                                                    concat(', ', string-join($termsOfAddress/*:namePart, ', ')) 
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
                        , ' ', 
                        (: ## 2 ##:)
                        if ($nameTransliteration/string())
                        (: We have a name in transliteration. This can e.g. be a Chinese name or a Russian name. :)
                        then
                            let $untypedTransliteration := <name>{$nameTransliteration/*:namePart[not(@type)]}</name>
                            let $familyTransliteration := <name>{$nameTransliteration/*:namePart[@type = 'family']}</name>
                            let $givenTransliteration := <name>{$nameTransliteration/*:namePart[@type = 'given']}</name>
                            let $termsOfAddressTransliteration := <name>{$nameTransliteration/*:namePart[@type = 'termsOfAddress']}</name>
                            (: let $dateTransliteration := <name>{$nameTransliteration/*:namePart[@type = 'date']}</name> :)                    
                            let $languageTransliteration :=
                                if ($familyTransliteration/@lang)
                                then mods:get-language-label($familyTransliteration/@lang)
                                else ()
                            let $language :=
                                if ($languageTransliteration)
                                then $languageTransliteration
                                else $language
                            let $nameOrder := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[label = $language]/nameOrder/string()
                            return        
                                if ($untypedTransliteration/string())
                                then string-join($untypedTransliteration/*:namePart, ' ') 
                                else
                                (: The name parts are typed, so we have a name that is a transliteration and that is divided into given and family name. If the name order is family-given, we have an ordinary Oriental name in transliteration, if the name order is givenfamily, we have e.g. a Russian name in transliteration. :)
                                    if ($pos = 1 and $caller = 'primary' and $nameOrder != 'family-given')
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
                                        if ($nameOrder != 'family-given')
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
                                    let $familyScript := <name>{$nameScript/*:namePart[@type = 'family']}</name>
                                    let $givenScript := <name>{$nameScript/*:namePart[@type = 'given']}</name>
                                    let $termsOfAddressScript := <name>{$nameScript/*:namePart[@type = 'termsOfAddress']}</name>
                                    (: let $dateScript := <name>{$nameScript/*:namePart[@type = 'date']}</name> :)
                                    let $languageScript :=
                                        if ($familyScript/@lang)
                                        then mods:get-language-label($familyScript/@lang)
                                        else ()
                                    let $language :=
                                        if ($languageScript)
                                        then $languageScript
                                        else $language
                                    let $nameOrder := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[label = $language]/nameOrder/string()
                                    return        
                                        if ($untypedScript/string())
                                        (: If the name parts are not typed, there is nothing we can do to order their sequence. When name parts are not typed, it is generally because the whole name occurs in one name part, formatted for display (usually with a comma between family and given name), but it may also be used when names that cannot be divided into family and given names are in evidence. We trust that any sequence of nameparts are meaningfully ordered and string-join them. :)
                                        then string-join($untypedScript, ' ') 
                                        else
                                        (: The name parts are typed, so we have a name that is not a transliteration, that is not in a non-Latin script and that is divided into given and family name. An ordinary Western name. :)
                                            if ($pos = 1 and $caller = 'primary' and $nameOrder != 'family-given')
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
                                                if ($nameOrder != 'family-given')
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
                                                (: $nameOrder = 'family-given'. Here we have e.g. Chinese names which are the same wherever they occur, with no space or comma between given and family name. :)
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
                            if ($dateBase)
                            then concat(' (', $dateBase, ')')
                            else ())
};

declare function mods:get-authority-name-from-mads($mads as element(), $caller as xs:string) {
    let $auth := $mads/mads:authority/mads:name
    return
        mods:format-name($auth, 1, $caller)
   
};

(: NB: used in search.xql :)
(: Each name in the list view should have an authority name added to it in parentheses, if it exists and is different from the name as given in the mods record. :)
declare function mods:retrieve-name($name as element(), $pos as xs:int, $caller as xs:string) {    
    let $mods-name := mods:format-name($name, $pos, $caller)
    let $mads-reference := replace($name/@xlink:href, '^#?(.*)$', '$1')
    (: NB: The following could be optimised. :)
    let $mads-record :=
        if (empty($mads-reference)) 
        then ()        
        else collection($config:mads-collection)/mads:mads[@ID = $mads-reference]/mads:authority
    let $mads-preferred-name :=
        if (empty($mads-record)) 
        then ()
        else mods:format-name($mads-record/mads:name, 1, $caller)
    let $mads-preferred-name-display :=
        if (empty($mads-preferred-name))
        then ()
        else concat(' (', $mads-preferred-name,')')
    return
        if ($mads-preferred-name eq $mods-name)
        then $mods-name
        else concat($mods-name, $mads-preferred-name-display)
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
        else collection($config:mads-collection)/mads:mads[@ID = $mads-reference]
    let $mads-preferred-name :=
        if (empty($mads-record)) 
        then ()
        else $mads-record/mads:authority/mads:name
    let $mads-preferred-name-formatted := mods:format-name($mads-preferred-name, 1, 'primary')
    let $mads-variant-names := $mads-record/mads:variant/mads:name
    let $mads-variant-name-nos := count($mads-record/mads:variant/mads:name)
    let $mads-variant-names-formatted := string-join(for $name in $mads-variant-names return mods:format-name($name, 1, 'primary'), ', ')
    return
        if ($mads-preferred-name)
        then mods:clean-up-punctuation(concat(' (Preferred Name: ', $mads-preferred-name-formatted, if($mads-variant-name-nos = 1) then '; Variant Name: ' else '; Variant Names: ', $mads-variant-names-formatted, ')'))
        else ()
};

(: Retrieves names. :)
(: Called from mods:format-multiple-names() :)
declare function mods:retrieve-names($entry as element()*, $caller as xs:string) {
    for $name at $pos in $entry/mods:name
    return
        mods:retrieve-name($name, $pos, $caller)
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
declare function mods:format-multiple-names($entry as element()*, $caller as xs:string) {
    let $names := mods:retrieve-names($entry, $caller)
    let $nameCount := count($names)
    let $formatted :=
        if ($nameCount eq 0) then
            ()
        else 
            if ($nameCount eq 1) 
            then
                if (ends-with($names, '.')) 
                then
                (: Places period after single author name, if it does not end with a term of address ending in period, such as "Jr." or "Dr.". :)
                concat($names, ' ')
                else
                concat($names, '. ')
            else
                if ($nameCount eq 2)
                then
                concat(
                    subsequence($names, 1, $nameCount - 1),
                    ' and ',
                    (: Places "and" before last name. :)
                    $names[$nameCount],
                    '. '
                    (: Places period after last name. :)
                )
                else 
                    concat(
                        string-join(subsequence($names, 1, $nameCount - 1), ', '),
                        (: Places ", " after all names that do not come last. :)
                        ', and ',
                        (: Places ", and" before name that comes last. :)
                        $names[$nameCount],
                        if ($caller = 'primary')
                        then '. '
                        else ()
                        (: Places period after last name. :)
                        )
    return
    normalize-space(
        $formatted
        )
};

(: NB! Create function to render real names from abbreviations! :)
(:
declare function mods:get-language-name() {
};
:)

(: ### <typeOfResource> begins ### :)

declare function mods:return-type($id as xs:string, $entry as element(mods:mods)) {
let $type := $entry/mods:typeOfResource[1]/string()
    return
     <span>{ 
        replace(
        if($type) then
        $type
        else
        'text'
        ,' ','_')
        }
      </span>  
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
        if ($titleInfo/@lang = 'ja' or $titleInfo/@lang = 'zh') then
            string-join(($entry/mods:titleInfo[@lang = 'en']/mods:title, $entry/mods:titleInfo[@lang = 'en']/mods:subTitle), ' ')
        else
            ()
    return
        if ($titleInfo) then
            <span class="title-translated">{string-join(($titleInfo/mods:title/string(), $titleInfo/mods:subTitle/string()), ' ') }</span>
        else ()
};

(: Constructs the title for the hitlist view. :)
declare function mods:get-short-title($id as xs:string?, $entry as element(), $type as xs:string?) {
    
    let $relatedItemType := $type
    
    let $titleInfo := $entry/mods:titleInfo
    let $titleInfoTransliteration := $titleInfo[@type='translated' and @transliteration]
    let $titleInfoTranslation := $titleInfo[@type='translated' and not(@transliteration)]
    
    (: NB: Should short title contain the following? :)
    (:
    let $titleInfoUniform := $titleInfo[@type='uniform']
    let $titleInfoAbbreviated := $titleInfo[@type='abbreviated']
    let $titleInfoAlternative := $titleInfo[@type='alternative']
    :)
    
    (: Repeated assignment of $titleInfo. :)
    let $titleInfo := $titleInfo[not(@type='abbreviated')][not(@type='uniform')][not(@type='alternative')][not(@type='translated')]
    
    (: NB: The string-joins below are not necessary. :)
    let $nonSort := string-join($titleInfo/mods:nonSort, ' ')
    let $title := string-join($titleInfo/mods:title, ' ')
    let $subTitle := string-join($titleInfo/mods:subTitle, ' ')
    let $partNumber := string-join($titleInfo/mods:partNumber, ' ')
    let $partName := string-join($titleInfo/mods:partName, ' ')
    
    let $nonSortTransliteration := string-join($titleInfoTransliteration/mods:nonSort, ' ')
    let $titleTransliteration := string-join($titleInfoTransliteration/mods:title, ' ')
    let $subTitleTransliteration := string-join($titleInfoTransliteration/mods:subTitle, ' ')
    let $partNumberTransliteration := string-join($titleInfoTransliteration/mods:partNumber, ' ')
    let $partNameTransliteration := string-join($titleInfoTransliteration/mods:partName, ' ')
    
    let $nonSortTranslation := string-join($titleInfoTranslation/mods:nonSort, ' ')
    let $titleTranslation := string-join($titleInfoTranslation/mods:title, ' ')
    let $subTitleTranslation := string-join($titleInfoTranslation/mods:subTitle, ' ')
    let $partNumberTranslation := string-join($titleInfoTranslation/mods:partNumber, ' ')
    let $partNameTranslation := string-join($titleInfoTranslation/mods:partName, ' ')
        
    let $titleFormat := 
        (
        if ($nonSort) 
        then concat($nonSort, ' ' , $title)
        else $title
        , 
        if ($subTitle) 
        then concat(': ', $subTitle)
        else ()
        ,
        if ($partNumber or $partName)
        then
            if ($partNumber and $partName) 
            then concat('. ', $partNumber, ': ', $partName)
            else
                if ($partNumber)
                then concat('. ', $partNumber)
                else
                    if ($partName)
                    then concat('. ', $partName)
            else ()
        else ()
        )
    let $titleTransliterationFormat := 
        (
        if ($nonSortTransliteration) 
        then 
            concat($nonSortTransliteration, ' ' , $titleTransliteration)
        else 
            $titleTransliteration
        , 
        if ($subTitleTransliteration) 
        then 
            concat(': ', $subTitleTransliteration)
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
        if ($relatedItemType)
        (: If it is a related item it has a type, and related items are not enclosed by quotation marks. :)
        then ()
        else '“'
        ,
        (
        if ($titleTransliteration) 
        then
        (
        $titleTransliterationFormat         
        ,
        ' '
        )
        else ()
        , 
        $titleFormat
        ,
        if ($relatedItemType) 
        then ()
        else '.”'
        ,
        if ($titleTranslation)
        then ('(', $titleTranslationFormat,')')
        else ()
        (:
        ,
        (: If the publication is a periodical (continuing) or if it is an edited volume, it should have no period attached. :)
        if (local-name($titleInfo/..) = 'relatedItem') 
        then ()
        else '.'
        :)        
        )
        )
};

(: Constructs title for the detail view. :)
declare function mods:title-full($titleInfo as element(mods:titleInfo)) {
if ($titleInfo)
    then
    <tr>
        <td class="label">
        {
            if (($titleInfo/@type = 'translated') and not($titleInfo/@transliteration)) 
            then 'Translated Title'
            else 
                if ($titleInfo/@type = 'abbreviated') 
                then 'Abbreviated Title'
                else 
                    if ($titleInfo/@type = 'alternative') 
                    then 'Alternative Title'
                    else 
                        if ($titleInfo/@type = 'uniform') 
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
            let $lang3 := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[value = $lang]/label
            return
                if ($lang3)
                then $lang3
                else
                    let $lang2 := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[valueTwo = $lang]/label
                    return
                        if ($lang2) 
                        then $lang2
                        else
                            let $lang3 := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[valueTwo = $titleInfo/@xml:lang]/label
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
        return
        if ($transliteration)
        then
            (<br/>, 'Transliteration: ',
            let $transliteration-label := doc(concat($config:edit-app-root, '/code-tables/transliteration-codes.xml'))/code-table/items/item[value = $transliteration]/label
            return
                if ($transliteration-label)
                then $transliteration-label
                else $transliteration
            )
        else
        ()
        }
        {
        if ($titleInfo/@script/string())
        then
            ('; Script: ', 
            doc(concat($config:edit-app-root, '/code-tables/script-codes.xml'))/code-table/items/item[value = $titleInfo/@script]/label
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
        concat(concat(concat($titleInfo/mods:nonSort, ' ', $titleInfo/mods:title), (if ($titleInfo/mods:subTitle) then ': ' else ()), string-join($titleInfo/mods:subTitle, '; ')), '. ', string-join(($titleInfo/mods:partNumber, $titleInfo/mods:partName), ': '))
        else
        concat(concat($titleInfo/mods:nonSort, ' ', $titleInfo/mods:title), (if ($titleInfo/mods:subTitle) then ': ' else ()), string-join($titleInfo/mods:subTitle, '; '))
                
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
    (: Unaccounted for: preceding, succeeding, original, constituent, series, otherVersion, otherFormat, isReferencedBy. :)
(: Subelements: any MODS element. :)
(: NB! This function is constructed differently from mods:entry-full; the two should be harmonised. :)

declare function mods:get-related-items($entry as element(mods:mods), $caller as xs:string) {
    for $item at $pos in $entry/mods:relatedItem
    let $relatedItemPos := $item[$pos]
    let $collection := util:collection-name($entry)
    let $type := functx:capitalize-first(functx:camel-case-to-words($relatedItemPos/@type, ' '))
    let $relatedItem :=
        if (($relatedItemPos/@xlink:href) and (collection($collection)//mods:mods[@ID = $relatedItemPos/@xlink:href])) 
        then collection($collection)//mods:mods[@ID = $relatedItemPos/@xlink:href][1]
        else $relatedItemPos
    return
        if ($relatedItem/@type = ('host', 'series') and $relatedItem/mods:titleInfo/mods:title/text())
        then
            if ($caller = 'hitlist')
            then
                concat
                (
                    if ($relatedItem/mods:originInfo/mods:issuance != 'continuing')
                    then 'In '
                    else ''
                , 
                mods:clean-up-punctuation(mods:format-related-item($relatedItem))
                )
            else
                if ($caller = 'detail')
                then
                    mods:simple-row(
                        mods:clean-up-punctuation(mods:format-related-item($relatedItem))
                    , 'In:')
                else ()
        else ()
};

declare function mods:format-related-item($relatedItem as element()) {
                <span class="related">
                {
                if ($relatedItem/mods:name/mods:role/mods:roleTerm = ('aut', 'author', 'Author', 'cre', 'creator', 'Creator') or not($relatedItem/mods:name/mods:role/mods:roleTerm))
                then
                    if ($relatedItem/mods:name/mods:role/mods:namePart/text())
                    then
                        mods:format-multiple-names($relatedItem, 'primary')
                    else ()
                else ()
                }
                <span class="title">
                {
                mods:get-short-title('', $relatedItem, $relatedItem/@type)
                }
                </span>,
                {
        let $roleTerms := $relatedItem/mods:name/mods:role/mods:roleTerm
        return
            for $roleTerm in distinct-values($roleTerms)
                where $roleTerm = ('com', 'compiler', 'editor', 'edt', 'trl', 'translator', 'annotator', 'ann')        
                    return
                        let $names := <entry>{$relatedItem/mods:name[mods:role/mods:roleTerm = $roleTerm]}</entry>
                            return
                                if ($names/string())
                                then
                                    (
                                    ', '
                                    ,
                                    mods:get-role-label-for-list-view($roleTerm)
                                    ,
                                    mods:format-multiple-names($names, 'secondary')
                                    )
                                else ()
                                }
                                {
                                if ($relatedItem/mods:originInfo/mods:issuance = 'monographic' or not($relatedItem/mods:part/mods:date/text()))
                                then ()
                                else '.'
                                }
                                {
                                if ($relatedItem/mods:originInfo or $relatedItem/mods:part) 
                                then
                                    (
                                    ' ',                
                                    mods:get-part-and-origin($relatedItem)
                                    ,                
                                    if ($relatedItem/mods:location/mods:url/text()) 
                                    then concat(' <', $relatedItem/mods:location/mods:url, '>')
                                    else ()
                                    )
                                else ()                
                                }
            </span>
};

(: ### <relatedItem> ends ### :)

declare function mods:names-full($entry as element()) {
        let $names := $entry/*:name[@type = 'personal' or @type = 'corporate' or @type = 'family' or not(@type)]
        for $name in $names
        return
                <tr><td class="label">
                    {
                    mods:get-roles-for-detail-view($name)
                    }
                </td><td class="record">
                    {
                    mods:clean-up-punctuation(mods:format-name($name, 1, 'primary'))
                    }
                    {
                    if ($name/@xlink:href)
                    then
                        mods:retrieve-mads-names($name, 1,'primary')
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
        <tr>
            <td class="label">{$label}</td>
            <td class="record">{string($d)}</td>
        </tr>
};

(:~
: Prepares the clickable url for mods:entry-full. A variation of mods:simple-row. 
: @param $entry
: @param $label
: @return element(tr)
: @see mods:simple-row
:)
declare function mods:url($entry as element()) as element(tr)* {
    for $url in $entry/mods:location/mods:url
    return
        <tr>
            <td class="label"> 
            {
                if ($url/@displayLabel)
                then
                    $url/@displayLabel/text()
                else 'URL'
            }
            </td>
            <td class="record"><a href="{$url}" target="_blank">{$url}</a></td>
        </tr>
};
        
(: Prepares for mods:format-full. :)
declare function mods:entry-full($entry as element()) 
    {
    (: names :)
    if ($entry/mods:name)
    then mods:names-full($entry)
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
    for $place in $entry/mods:originInfo/mods:place
        return mods:simple-row(mods:get-place($place), 'Place')
    ,
    
    (: publisher :)
    for $publisher in $entry/mods:originInfo/mods:publisher
        return mods:simple-row(mods:get-publisher($publisher), 'Publisher')
    ,
    
    (: dates :)
    if ($entry/mods:relatedItem/mods:originInfo/mods:dateCreated) 
    then () 
    else 
        for $dateCreated in $entry/mods:originInfo/mods:dateCreated
            return mods:simple-row($dateCreated, 'Date Created')
    ,
    if ($entry/mods:relatedItem/mods:originInfo/mods:dateIssued) 
    then () 
    else 
        for $dateIssued in $entry/mods:originInfo/mods:dateIssued
            return mods:simple-row($dateIssued, 'Date Issued')
    ,
    if ($entry/mods:relatedItem/mods:originInfo/mods:dateModified) 
    then () 
    else 
        for $dateModified in $entry/mods:originInfo/mods:dateModified
            return mods:simple-row($dateModified, 'Date Modified')
    ,
    if ($entry/mods:relatedItem/mods:originInfo/mods:dateOther) 
    then () 
    else 
        for $dateOther in $entry/mods:originInfo/mods:dateOther
            return mods:simple-row($dateOther, 'Other Date')
    ,
    
    (: extent :)
    if ($entry/mods:extent) 
    then mods:simple-row(mods:get-extent($entry/mods:extent), 'Extent') 
    else ()
    ,
    
    (: URL :)
    mods:url($entry)
    ,
    
    (: relatedItem :)
    mods:get-related-items($entry, 'detail')
    ,
    
    (: typeOfResource :)
    mods:simple-row($entry/mods:typeOfResource[1]/string(), 'Type of Resource')
    ,
    
    (: internetMediaType :)
    mods:simple-row(
    (
    let $label := doc(concat($config:edit-app-root, '/code-tables/internet-media-type-codes.xml'))/code-table/items/item[value = $entry/mods:physicalDescription[1]/mods:internetMediaType]/label
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
    then
    mods:simple-row(mods:language-of-cataloging($language), 'Language of Cataloging')
    else ()
    ,

    (: genre :)
    for $genre in ($entry/mods:genre)
    let $authority := $genre/@authority/string()
    return    
        mods:simple-row
            (
                if ($authority = 'local')
                then
                    doc(concat($config:edit-app-root, '/code-tables/genre-local-codes.xml'))/code-table/items/item[value = $genre]/label
                else $genre/string()
            , 
                concat(
                    'Genre'
                    , 
                    if ($authority)
                    then
                        if ($authority = 'marcgt')
                        then
                            concat(' (', replace(doc(concat($config:edit-app-root, '/code-tables/genre-authority-codes.xml'))/code-table/items/item[value = $authority]/label, '\*', ''), ')')
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
    return    
    mods:simple-row($note
    , 
    concat('Note', 
        if ($displayLabel)
            then
                concat(' (', $displayLabel, ')')            
        else ()            
        )
    )
    ,
    
    (: subject :)
    (: We assume that there are not many subjects with the first element, topic, empty. :)
    if (normalize-space($entry/mods:subject[1]/string()))
    then
    mods:format-subjects($entry)    
    else ()
    , 
    
    (: ISBN :)
    mods:simple-row($entry/mods:identifier[@type='isbn'][1], 'ISBN'),
    
    (: classification :)
    for $item in $entry/mods:classification
    let $authority := 
        if ($item/@authority/string()) 
        then concat(' (', ($item/@authority/string()), ')') 
        else ()
    return
    mods:simple-row($item, concat('Classification', $authority))
};

(: Creates view for detail view. :)
(: NB: "mods:format-detail-view()" is referenced in session.xql. :)
declare function mods:format-detail-view($id as xs:string, $clean as element(mods:mods), $collection-short as xs:string) {
    <table class="biblio-full">
    {
        <tr><td class="label">In Folder:</td><td>
        {$collection-short}
        </td></tr>
        ,
        mods:entry-full($clean)
    }
    </table>
};

(: Creates view for hitlist. :)
(: NB: "mods:format-list-view()" is referenced in session.xql. :)
declare function mods:format-list-view($id as xs:string, $entry as element(mods:mods)) {
    let $format :=
        (
        (: The author, etc. of the primary publication. :)
        let $names := <entry>{$entry/mods:name[@type = 'personal' or @type = 'corporate' or @type = 'family' or not(@type)][(mods:role/mods:roleTerm = ('aut', 'author', 'Author', 'cre', 'creator', 'Creator')) or not ($entry/mods:name/mods:role/mods:roleTerm)]}</entry>
        return mods:format-multiple-names($names, 'primary')
        ,
        
        (: The title of the primary publication. :)
        mods:get-short-title($id, $entry, '')
        ,
        
        (: The editor, etc. of the primary publication. :)
        let $roleTerms := $entry/mods:name/mods:role/mods:roleTerm[. = ('com', 'compiler', 'Compiler', 'editor', 'Editor', 'edt', 'trl', 'translator', 'Translator', 'annotator', 'Annotator', 'ann')]
        return
        for $roleTerm in distinct-values($roleTerms)        
            return
                (: NB: Can the wrapper be avoided? :)
                let $names := <entry>{$entry/mods:name[mods:role/mods:roleTerm = $roleTerm]}</entry>
                return
                    (
                    (: Introduce secondary role with comma. :)
                    (: NB: What if there are multiple secondary roles? :)
                    ', '
                    ,
                    mods:get-role-label-for-list-view($roleTerm)
                    ,
                    mods:format-multiple-names($names, 'secondary')
                    (: Terminate secondary role with period. :)
                    (: NB: What if there are multiple secondary roles? :)
                    ,'.')
        , ' '
        ,
        (: The conference of the primary publication, containing originInfo and part information. :)
        if ($entry/mods:name[@type = 'conference']) 
        then
            mods:get-conference-hitlist($entry)
        else 
        (: If not a publication, get originInfo and part information for primary publication. :)
            mods:get-part-and-origin($entry)
        ,
        
        (: The periodical or edited volume that the primary publication occurs in. :)    
        mods:get-related-items($entry, 'hitlist')
        ,
        
        (: The url of the primary publication. :)
        if ($entry/mods:location/mods:url/text())
        then
            for $url in $entry/mods:location/mods:url
                return
                    concat(' <', $url, '>')
        else ()
        )
    return
        (: The result. :)
        <div class="select">
        {
        mods:clean-up-punctuation(normalize-space(string-join($format,' ')))
        }
        </div>
};