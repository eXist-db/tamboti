module namespace modsCommon="http://exist-db.org/mods/common";

declare namespace mods="http://www.loc.gov/mods/v3";
declare namespace functx = "http://www.functx.com";
 
(:~
: Used to remove whitespace at the beginning and end of a string.   
: @param
: @return
: @see http://http://www.xqueryfunctions.com/xq/functx_trim.html
:)
declare function functx:trim($arg as xs:string?) as xs:string {       
   replace(replace($arg,'\s+$',''),'^\s+','')
};

(: Constructs a compact title for list view, for subject, and for related items. :)
declare function modsCommon:get-short-title($entry as element()) {
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