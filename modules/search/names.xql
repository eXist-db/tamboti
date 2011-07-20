module namespace nameutil="http://exist-db.org/xquery/biblio/names";

declare namespace mods="http://www.loc.gov/mods/v3";

(: Called from filter.xql. :)
(: An adaption of biblio:orderByAuthor() from search.xql. :)
declare function nameutil:format-name($name as element(mods:name)) as xs:string* {
    let $sortFirst :=
    	(: If there is a namePart marked as being Western, there will probably in addition be a transliterated and a Eastern-script "nick-name", but the Western namePart should have precedence over the nick-name, therefore pick out the Western-language nameParts first. :)
    	(: NB: it is a problem to have a positive list of languages to filter; it would be easier to rule out 'chi','jpn' and 'kor' and so on. :)
    	if ($name/mods:namePart[@lang = ('eng', 'fre', 'ger')]/text())
    	then
    		(: If it has a family type, take it; otherwise take whatever namePart there is (in case of a name which has not been analysed into given and family names. :)
    		if ($name/mods:namePart[@type = 'family'])
    		then $name/mods:namePart[@lang = ('eng', 'fre', 'ger')][@type='family'][1]/text()
    		else $name/mods:namePart[@lang = ('eng', 'fre', 'ger')][1]/text()
    	else
    		(: If there is not an Western namePart, check if there is a namePart with transliteration; if this is the case, take it. :)
	    	if ($name/mods:namePart[@transliteration]/text())
	    	then
	    		(: If it has a family type, take it; otherwise take whatever transliterated namePart there is. :)
	    		if ($name/mods:namePart[@type = 'family']/text())
	    		then $name/mods:namePart[@type='family'][@transliteration][1]/text()
		    	else $name/mods:namePart[@transliteration][1]/text()
		    else
		    	(: If the name does not have a transliterated namePart, it is probably a "standard" (unmarked) Western name, if it does not have a script attribute or uses Latin script. :)
	    		if ($name/mods:namePart[not(@script) or @script = 'Latn']/text())
	    		then
	    		(: If it has a family type, take it; otherwise takes whatever untransliterated namePart there is.:) 
		    		if ($name/mods:namePart[not(@script) or @script = 'Latn'][@type = 'family']/text())
		    		then $name/mods:namePart[not(@script) or @script = 'Latn'][@type='family'][1]/text()
	    			else $name/mods:namePart[not(@script) or @script = 'Latn'][1]/text()
	    		(: The last step should take care of Eastern names without transliteration. These will usually have a script attribute :)
	    		else
	    			if ($name/mods:namePart[@type = 'family']/text())
		    		then $name/mods:namePart[@type='family'][1]/text()
	    			else $name/mods:namePart[1]/text()
	let $sortLast :=
	    	if ($name/mods:namePart[@lang = ('eng', 'fre', 'ger')]/text())
	    	then
	    	(: Insert commas before Western given names. :)
	    		concat(', ', $name/mods:namePart[@lang = ('eng', 'fre', 'ger')][@type='given'][1]/text())
	    	else
		    	if ($name/mods:namePart[@transliteration]/text())
		    	then
		    		(: Do not insert commas before Eastern given names. :)
		    		concat(' ', $name/mods:namePart[@type='given'][@transliteration][1]/text())
			    else
			    	if ($name/mods:namePart[not(@script) or @script = 'Latn']/text())
		    		(: Insert commas before Western given names. :)
		    		then concat(', ', $name/mods:namePart[@type='given'][not(@script) or @script = 'Latn'][1]/text())
		    		else concat(', ', $name/mods:namePart[@type='given'][1]/text())
	let $nameOriginalScript :=
			(: If the name has a transliterated namePart, it is probably an "Eastern" name; extract the name in original script to be appended the transliterated name. :)
	    	if ($name/mods:namePart[@transliteration]/text())
	    	then
	    		(: If it has a family type, take it; otherwise take whatever transliterated namePart there is. :)
	    		if ($name/mods:namePart[not(@transliteration)][@type = 'family']/text())
	    		then concat(' ', $name/mods:namePart[not(@transliteration)][@script][@type='family'][1]/text(), $name/mods:namePart[not(@transliteration)][@script][@type='given'][1]/text())
		    	else concat(' ', $name/mods:namePart[not(@transliteration)][@script][1]/text())
		    else ()
    return
        concat(
        	$sortFirst,
        	$sortLast, 
	        	if ($nameOriginalScript) 
	        	then $nameOriginalScript
	        	else ()
	        )
};