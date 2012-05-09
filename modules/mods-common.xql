module namespace modsCommon="http://exist-db.org/mods/common";

declare namespace mods="http://www.loc.gov/mods/v3";
declare namespace functx = "http://www.functx.com";

import module namespace config="http://exist-db.org/mods/config" at "../../../modules/config.xqm";

declare variable $modsCommon:western-languages := ('eng', 'fre', 'ger', 'ita', 'por', 'spa');

(:~
: Prepares one or more rows for the detail view.
:
: @author Wolfgang M. Meier
: @param $data
: @param $label
: @return element(tr)
:)
declare function modsCommon:simple-row($data as item()?, $label as xs:string) as element(tr)? {
    for $d in $data
    return
        <tr xmlns="http://www.w3.org/1999/xhtml">
            <td class="label">{$label}</td>
            <td class="record">{$d}</td>
        </tr>
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
declare function modsCommon:serialize-list($sequence as item()+, $sequence-count as xs:integer) as xs:string {       
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
: Capitalizes the first character of a string.   
:
: @author Jenny Tennison
: @param $arg A string
: @return A string
: @see http://http://www.xqueryfunctions.com/xq/functx_capitalize-first.html
:)
declare function functx:capitalize-first($arg as xs:string?) as xs:string? {       
   concat(upper-case(substring($arg,1,1)), substring($arg,2))
};

(:~
: Transforms to the camel-case a string.
: Used to camel-case the names of MODS elements into space-separated words.  
:
: @author Jenny Tennison
: @param $arg A string
: @param $delim A string
: @return A string
: @see http://www.xqueryfunctions.com/xq/functx_camel-case-to-words.html
:)
declare function functx:camel-case-to-words($arg as xs:string?, $delim as xs:string ) as xs:string? {
   concat(substring($arg,1,1), replace(substring($arg,2),'(\p{Lu})', concat($delim, '$1')))
};

(:~
: Removes whitespace at the beginning and end of a string.   
:
: @author Jenny Tennison
: @param $arg A string
: @return A string
: @see http://http://www.xqueryfunctions.com/xq/functx_trim.html
:)
declare function functx:trim($arg as xs:string?) as xs:string {       
   replace(replace($arg,'\s+$',''),'^\s+','')
};
 

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
: @param $entry The MODS entry as a whole or a relatedItem element
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
        (: This assumes that nonSort is not used in Asian scripts; otherwise we would have to avoid the space. :)
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
        	if (exists($entry/mods:relatedItem[@type='host'][1]/mods:part/mods:extent[1]) 
        	   or exists($entry/mods:relatedItem[@type='host'][1]/mods:part[1]/mods:detail[1]/mods:number[1]) 
        	   (: NB: Faulty Zotero export has text here; delete when corrected. :)
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
declare function modsCommon:get-language-label($languageTerm as xs:string) as xs:string? {
        let $language-label :=
            let $language-label := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[value = $languageTerm]/label
            return
                if ($language-label)
                then $language-label
                else
                    let $language-label := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[valueTwo = $languageTerm]/label
                    return
                        if ($language-label)
                        then $language-label
                        else
                            let $language-label := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[valueTerm = $languageTerm]/label
                            return
                                if ($language-label)
                                then $language-label
                                else
                                    let $language-label := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[upper-case(label) = upper-case($languageTerm)[1]]/label
                                    return
                                        if ($language-label)
                                        then $language-label
                                        else
                                            let $language-label := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[upper-case(label) = upper-case($languageTerm)]/label
                                            return
                                                if ($language-label)
                                                then $language-label
                                                else concat($languageTerm, ' (unidentified)')
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
: @return $script-label A human-readable script label
:)
declare function modsCommon:get-script-label($scriptTerm as xs:string) as xs:string? {
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

(:~
: The <b>modsCommon:format-name(</b> function returns 
: a formatted name. The function returns the name as it appears in first place in a list of names, with family name first, 
: and as it appears elsewhere, with given name first. The case of names in a script that is also transliterated is covered.
: If the name has an authoritative form according to a MADS record, this form is rendered.
: The function at present seeks to approach the Chicago style.
: The namespace is masked because it refers to both the mods and the mads prefix.
:
: @author Wolfgang M. Meier
: @author Jens Østergaard Petersen
: @see http://www.loc.gov/standards/mods/userguide/name.html
: @see http://www.loc.gov/standards/mads/
: @param $name The MODS name element as it appears as a top level element or as an element elsewhere
: @param $position The position of the name in a list of names
: @param $destination The function that calls the format-name function passes here the values 'detail', 'list', or 'list-first' according to its destination
: @param $global-transliteration The value set for the transliteration scheme to be used in the record as a whole, set in e:extension
: @param $global-language The value set for the language of the resource catalogued, set in language/languageTerm
: @return The name formatted as XHTML.
:)
declare function modsCommon:format-name($name as element()?, $position as xs:integer, $destination as xs:string, $global-transliteration as xs:string, $global-language as xs:string) {	
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
                    (: If a family as such being responsible for a publication, we must assume that all nameParts will describe the family name.
                    so just string-join any nameParts, dividing them with a comma. :)
                    (: NB: This is the same as type corporate. :)
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
                        (: NB: The assumption is that transliteration is always in Latin script, but - obviously - it may e.g. be in Cyrillic script. :)
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
        						then 0
        						else 0
                        (: If the name does not contain a namePart with transliteration, it is a basic name, 
                        i.e. a name where the distinction between the name in native script and in transliteration does not arise. 
                        Typical examples are Western names, but this also includes Eastern names where no effort has been taken to distinguish between native script and transliteration. 
                        Filtering like this would leave out names where Westerners have Chinese names, and in order to catch these, 
                        we require that they have language set to one of the common European languages. :)
                        (: NB: The whole notion of names being in different languages is problematic. :)
                        (: NB: Only coded language terms are treated here. :)
                        let $name-basic :=
    	                    if (not($name-contains-transliteration))
    	                    (:If we know for sure that no transliteration is used somehwere in the name, then grab the parts in which Western script is used.:) 
    	                    then <name>{$name/*:namePart[not(@transliteration)][(not(@script) or @script = ('Latn', 'latn', 'Latin'))]}</name>
                        	(:If we know for sure that transliteration is used somehwere in the name, then grab the untransliterated parts.:)
                        	else <name>{$name/*:namePart[@lang = $modsCommon:western-languages or not(@lang)]}</name>
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
                        (: If there is transliteration, the presumption must be that all nameParts which are not transliterations (and which do not have the language set to a European language) are names in non-Latin script. 
                        We filter for nameParts which do no have the transliteration attribute or have one with no contents, 
                        and which do not have script set to Latin, and which do not have English as their language. :)
                        let $name-in-non-latin-script := 
    	                    if ($name-contains-transliteration)
    	                    then <name>{$name/*:namePart[(not(@transliteration) or string-length(@transliteration) eq 0)][(@script)][not(@script = ('Latn', 'latn', 'Latin'))][not(@lang = $modsCommon:western-languages)]}</name>
    	                    else ()
                        (: We assume that there is only one date name part in $name-basic. 
                        Date name parts with transliteration and script are rather theoretical. 
                        This date is attached at the end of the name, to distinguish between identical names. That is why it is set here, not below. :)
                        let $date-basic := $name-basic/*:namePart[@type eq 'date']
                        return
                            concat(
                            (: ## 1 ##:)
                            if ($name-basic/string())
                            (: If there are one or more name parts that are not marked as being transliteration and that are not marked as being in a certain script (aside from Latin). :)
                            then
                            (: Filter the name parts according to type. :)
                                let $family-name-basic := <name>{$name-basic/*:namePart[@type eq 'family']}</name>
                                let $given-name-basic := <name>{$name-basic/*:namePart[@type eq 'given']}</name>
                                let $termsOfAddress-basic := <name>{$name-basic/*:namePart[@type eq 'termsOfAddress']}</name>
                                let $untyped-name-basic := <name>{$name-basic/*:namePart[not(@type)]}</name>
                                (: $date-basic already has the date. :)
                                (: To get the name order, get the language of the namePart and send it to modsCommon:get-name-order(), along with higher-level language values. :)
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
                                let $nameOrder-basic := modsCommon:get-name-order($language-basic, $name-language, $global-language)
                                return
                                    if ($untyped-name-basic/string())
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
                                                if ($family-name-basic/string() and $given-name-basic/string())
                                                (: If only one of family and given are evidenced, no comma is needed. :)
                                                then
                                                    if ($nameOrder-basic eq 'family-given')
                                                    (: If the name is Hungarian, use a space; otherwise (i.e. in most cases) use a comma. :)
                                                    then ' '
                                                    else ', '
                                                else ()
                                                ,
                                                string-join($given-name-basic/*:namePart, ' ') 
                                                ,
                                                if ($termsOfAddress-basic/string())
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
                                                    if ($family-name-basic/string() and $given-name-basic/string())
                                                    then ' '
                                                    else ()
                                                    ,
                                                    string-join($given-name-basic/*:namePart, ' ') 
                                                    ,
                                                    if ($termsOfAddress-basic/string())
                                                    (: NB: Where do terms of address go in Hungarian? :)
                                                    then concat(', ', string-join($termsOfAddress-basic/*:namePart, ', ')) 
                                                    else ()
                                                )
                                            else
                                            (: In all other situations, the name order is given-family, with a space in between. :)
                                            (: Example: "Dr. Sigmund Freud (1856-1939)". :)
                                                        concat
                                                        (
                                                            if ($termsOfAddress-basic/text())
                                                            then concat(string-join($termsOfAddress-basic/*:namePart, ', '), ' ')
                                                            else ()
                                                            ,
                                                            string-join($given-name-basic/*:namePart, ' ')
                                                            ,
                                                            if ($family-name-basic/string() and $given-name-basic/string())
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
                            (: If there is a "European" name, enclose the transliterated and Eastern script name in parenthesis. :)
                            if ($name/*:namePart[@lang  = $modsCommon:western-languages])
                            then ' ('
                            else ()
                            ,
                            if ($name-in-transliteration/string())
                            (: If we have a name in transliteration, e.g. be a Chinese name or a Russian name, filter the name parts according to type. :)
                            then
                                let $untyped-name-in-transliteration := <name>{$name-in-transliteration/*:namePart[not(@type)]}</name>
                                let $family-name-in-transliteration := <name>{$name-in-transliteration/*:namePart[@type eq 'family']}</name>
                                let $given-name-in-transliteration := <name>{$name-in-transliteration/*:namePart[@type eq 'given']}</name>
                                let $termsOfAddress-in-transliteration := <name>{$name-in-transliteration/*:namePart[@type eq 'termsOfAddress']}</name>
                                (: To get the name order, get the language of the namePart and send it to modsCommon:get-name-order(), along with higher-level language values. :)
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
                                let $nameOrder-in-transliteration := modsCommon:get-name-order($language-in-transliteration, $name-language, $global-language)                                
                                return       
                                    (: If there are name parts that are not typed, there is nothing we can do to order their sequence. :)
                                    if ($untyped-name-in-transliteration/string())
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
                                            if ($family-name-in-transliteration/string() and $given-name-in-transliteration/string())
                                            then ', '
                                            else ()
                                            ,
                                            string-join($given-name-in-transliteration/*:namePart, ' ') 
                                            ,
                                            if ($termsOfAddress-in-transliteration/string()) 
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
                                                    if ($termsOfAddress-in-transliteration/string()) 
                                                    then concat(', ', string-join($termsOfAddress-in-transliteration/*:namePart, ', ')) 
                                                    else ()
                                                    ,
                                                    string-join($given-name-in-transliteration/*:namePart, ' ')
                                                    ,
                                                    if ($family-name-in-transliteration/string() and $given-name-in-transliteration/string())
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
                                                    if ($family-name-in-transliteration/string() and $given-name-in-transliteration/string())
                                                    then ' '
                                                    else ()
                                                    ,
                                                    string-join($given-name-in-transliteration, '')
                                                    ,
                                                    if ($termsOfAddress-in-transliteration/string()) 
                                                    then concat(' ', string-join($termsOfAddress-in-transliteration/*:namePart, ' ')) 
                                                    else ()
                                                )
                                else ()
                                , ' ',
                                (: ## 3 ##:)
                                    if ($name-in-non-latin-script/string())
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
                                        let $nameOrder-in-non-latin-script := modsCommon:get-name-order($language-in-non-latin-script, $name-language, $global-language)
                                        return       
                                            if ($untyped-name-in-non-latin-script/string())
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
                                                    if ($family-name-in-non-latin-script/string() and $given-name-in-non-latin-script/string())
                                                    then ', '
                                                    else ()
                                                    ,
                                                    string-join($given-name-in-non-latin-script/*:namePart, ' ')
                                                    ,
                                                    if ($termsOfAddress-in-non-latin-script/string()) 
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
                                                            if ($termsOfAddress-in-non-latin-script/string())
                                                            then concat(string-join($termsOfAddress-in-non-latin-script, ', '), ' ')
                                                            else ()
                                                            ,
                                                            string-join($given-name-in-non-latin-script/*:namePart, ' ')
                                                            ,
                                                            if ($family-name-in-non-latin-script/string() and $given-name-in-non-latin-script/string())
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
                                if ($date-basic)
                                then concat(' (', $date-basic, ')')
                                else ()
                                )
    };

(:~
: The <b>modsCommon:get-name-order</b> function returns 
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
declare function modsCommon:get-name-order($namePart-language as xs:string?, $name-language as xs:string, $global-language) {
    let $language :=
        if ($namePart-language)
            then $namePart-language
            else
                if ($name-language)
                then $name-language
                else
                    if ($global-language)
                    then $global-language
                    else ()
    let $nameOrder := doc(concat($config:edit-app-root, '/code-tables/language-3-type-codes.xml'))/code-table/items/item[value eq $language]/nameOrder/string()
    return $nameOrder
};

(:~
: The <b>modsCommon:format-subjects</b> function returns 
: a table-formatted representation of each mods subject.
: The values for topic, geographic, temporal, titleInfo, name, 
: genre, hierarchicalGeographic, cartographics, geographicCode, occupation are represented in subtables.
:
: @author Jens Østergaard Petersen
: @param $entry A subject element in a mods record
: @param $global-transliteration  The value set for the transliteration scheme to be used in the record as a whole, set in e:extension
: @param $global-language The string value of mods/language/languageTerm
: @see http://www.loc.gov/standards/mods/userguide/subject.html
: @return $nameOrder The string 'family-given' or the empty string
:)
declare function modsCommon:format-subjects($entry as element(), $global-transliteration as xs:string, $global-language as xs:string) as element()+ {
    for $subject in $entry/mods:subject
    let $authority := 
        if ($subject/@authority/string()) 
        then concat('(', ($subject/@authority/string()), ')') 
        else ()
    return
        <tr>
            <td class="label subject">Subject {$authority}</td>
            <td class="record">    
            {
            for $item in $subject/mods:*[string-length(functx:trim(.)) gt 0]
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
                <table class="subject">
                    <tr><td class="sublabel">
                        {
                        replace(functx:capitalize-first(replace($item/name(), 'mods:','')),'Info',''),
                        $authority, $encoding, $type
                        }
                        </td>
                        {
                        (: If there is a child. :)
                        if ($item/mods:*)
                        then
                        <td class="subrecord">
                        {
                        (: If it is a name. :)
                            if ($item/name() eq 'name')
                            then modsCommon:format-name($item, 1, 'list-first', $global-transliteration, $global-language)
                            else
                                (: If it is a titleInfo. :)
                                if ($item/name() eq 'titleInfo')
                                then string-join(modsCommon:get-short-title(<titleInfo>{$item}</titleInfo>), '')
                                else
                                    (: If it is something else, no special formatting takes place. :)
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
                                        <table>
                                            <tr>
                                                <td class="sublabel">
                                                {functx:capitalize-first(functx:camel-case-to-words(replace($subitem/name(), 'mods:',''), ' ')),
                                                $authority, $encoding}
                                                </td>
                                                <td>
                                                <td class="subrecord">                
                                                {$subitem/string()}
                                                </td>
                                                </td>
                                            </tr>
                                        </table>
                                    }
                        </td>
                        else
                            if ($item) then
                            <td class="subrecord" colspan="2">{$item/string()}</td>
                            else ()
                        }
                    </tr>
                </table>
            }
            </td>
        </tr>
};
