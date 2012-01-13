module namespace modsCommon="http://exist-db.org/mods/common";

declare namespace mods="http://www.loc.gov/mods/v3";

import module namespace config="http://exist-db.org/mods/config" at "../../../modules/config.xqm";

(:~
: The <b>modsCommon:get-short-title</b> function returns 
: a compact title for list view, for subject in detail view, and for related items in list and detail view.
: The function at present seeks to approach the Chicago style.
:
: @author Wolfgang M. Meier
: @author Jens Østergaard Petersen
: @see http://www.loc.gov/standards/mods/userguide/titleinfo.html
: @see http://www.loc.gov/standards/mods/userguide/relateditem.html
: @see http://www.loc.gov/standards/mods/userguide/subject.html#titleinfo
: @param $entry The MODS entry as a whole or a relatedItem element.
: @return The titleInfo formatted as XHTML.
:)

declare function modsCommon:get-short-title($entry as element()) {
    (: If the entry has a related item of @type host with an extent in part, it is a periodical article or a contribution to an edited volume and the title should be enclosed in quotation marks. :)
    (: In order to avoid having to iterate through the (extremely rare) instances of multiple elements and in order to guard against cardinality errors in faulty records duplicating elements that are supposed to be unique, a lot of filtering for first child is performed. :)
    
    (: The short title only consists of the main title, which is untyped, and its renditions in transliteration and translation. 
    Filter away the remaining titleInfo @type values. 
    This means that a record without an untyped titleInfo will not display any title. :)
    let $titleInfo := $entry/mods:titleInfo[not(@type=('abbreviated', 'uniform', 'alternative'))]
    
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
        if ($nonSort/string())
        (: This assumes that nonSort is not used in Asian scripts. :)
        then concat($nonSort, ' ' , $title)
        else $title
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
        if ($partNumber-transliterated or $partName-transliterated)
        then
            if ($partNumber-transliterated and $partName-transliterated) 
            then concat('. ', $partNumber-transliterated, ': ', $partName-transliterated)
            else
                if ($partNumber-transliterated)
                then concat('. ', $partNumber-transliterated)
                else
                    if ($partName-transliterated)
                    then concat('. ', $partName-transliterated)
            		else ()
        else ()
        )
        
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
        if ($partNumber-translated or $partName-translated)
        then
            if ($partNumber-translated and $partName-translated) 
            then concat('. ', $partNumber-translated, ': ', $partName-translated)
            else
                if ($partNumber-translated)
                then concat('. ', $partNumber-translated)
                else
                    if ($partName-translated)
                    then concat('. ', $partName-translated)
            		else ()
        else ()
        )
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
        	if (exists($entry/mods:relatedItem[@type='host'][1]/mods:part/mods:extent[1]) 
        	   or exists($entry/mods:relatedItem[@type='host'][1]/mods:part[1]/mods:detail[1]/mods:number[1]) 
        	   (: Faulty Zotero export has text here. :)
        	   or exists($entry/mods:relatedItem[@type='host'][1]/mods:part[1]/mods:detail[1]/mods:text[1]))
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
: The <b>modsCommon:get-language-label</b> function returns 
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
declare function modsCommon:get-language-label($language-string as xs:string) as xs:string? {
        let $language-label :=
            let $language-label := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[value = $language-string]/label
            return
                if ($language-label)
                then $language-label
                else
                    let $language-label := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[valueTwo = $language-string]/label
                    return
                        if ($language-label)
                        then $language-label
                        else
                            let $language-label := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[valueTerm = $language-string]/label
                            return
                                if ($language-label)
                                then $language-label
                                else
                                    let $language-label := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[upper-case(label) = upper-case($language-string)[1]]/label
                                    return
                                        if ($language-label)
                                        then $language-label
                                        else
                                            let $language-label := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[upper-case(label) = upper-case($language-string)]/label
                                            return
                                                if ($language-label)
                                                then $language-label
                                                else concat($language-string, ' (unidentified)')
        return $language-label
};

(:~
: The <b>modsCommon:get-script-label</b> function returns 
: the <b>human-readable label</b> of the script value passed to it.
: This value can set in many MODS elements and attributes. 
: The language-string can have two types, text and code.
:
: @author Jens Østergaard Petersen 
: @see http://www.loc.gov/standards/mods/userguide/generalapp.html#top_level
: @see http://www.loc.gov/standards/mods/userguide/language.html
: @param $scriptTerm The string value of an element or attribute recording a script, in textual or coded form
: @return $scrupt-label A human-readable script label
:)
declare function modsCommon:get-script-label($scriptTerm as xs:string?) as xs:string? {
        let $scriptTerm-upper-case := upper-case($scriptTerm)
        let $script-label :=
            let $script-label := doc(concat($config:edit-app-root, '/code-tables/script-codes.xml'))/code-table/items/item[upper-case(value) = $scriptTerm-upper-case]/label
            return
                if ($script-label)
                then $script-label
                else 
                    let $script-label := doc(concat($config:edit-app-root, '/code-tables/script-codes.xml'))/code-table/items/item[upper-case(label) = $scriptTerm-upper-case]/label
                    return
                        if ($script-label)
                        then $script-label
                        else concat($scriptTerm, ' (unidentified)')
        return $script-label
};

