xquery version "3.0";

module namespace biblio="http:/exist-db.org/xquery/biblio";

(:~
    The core XQuery script for the bibliographic demo. It receives a template XML document
    from the controller and expands it. If a search was triggered by the user, the script
    proceeds as follows:
    
    <ul>
        <li>the input form parameters are transformed into a simple XML structure
            to describe the query</li>
        <li>an XPath string is generated from the XML query structure</li>
        <li>the XPath is executed and the sort criteria applied</li>
        <li>query results, XML query and sort criteria are stored into the HTTP session</li>
        <li>the template is expanded, forms are regenerated to match the query</li>
    </ul>
    
    To apply a filter to an existing query, we just extend the XML representation
    of the query.
:)

declare namespace group="http://commons/sharing/group";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace session="http://exist-db.org/xquery/session";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";
declare namespace functx = "http://www.functx.com";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace mods="http://www.loc.gov/mods/v3";

import module namespace config="http://exist-db.org/mods/config" at "../config.xqm";
import module namespace theme="http:/exist-db.org/xquery/biblio/theme" at "../theme.xqm";
import module namespace templates="http://exist-db.org/xquery/templates" at "../templates.xql";

import module namespace jquery="http://exist-db.org/xquery/jquery" at "resource:org/exist/xquery/lib/jquery.xql";

import module namespace sort="http://exist-db.org/xquery/sort" at "java:org.exist.xquery.modules.sort.SortModule";
import module namespace security="http://exist-db.org/mods/security" at "security.xqm";
import module namespace sharing="http://exist-db.org/mods/sharing" at "sharing.xqm";
import module namespace uu="http://exist-db.org/mods/uri-util" at "uri-util.xqm";

declare option exist:serialize "method=xhtml media-type=application/xhtml+xml omit-xml-declaration=no enforce-xhtml=yes";

declare function functx:replace-first($arg as xs:string?, $pattern as xs:string, $replacement as xs:string ) as xs:string {       
   replace($arg, concat('(^.*?)', $pattern),
             concat('$1',$replacement))
 } ;

(:~
    Simple mapping from field names to an XPath expression
:)
declare variable $biblio:FIELDS :=
	<fields>
		<field name="Title">(
			mods:mods[ft:query(mods:titleInfo, '$q', $options)]
			      union
			mods:mods[ft:query(mods:relatedItem/mods:titleInfo, '$q', $options)]
		)</field>
		<field name="Name">(
			mods:mods[ft:query(mods:name, '$q', $options)]
			      union
			mods:mods[ft:query(mods:relatedItem/mods:name, '$q', $options)]		
		)</field>
		<field name="Date">
			(
			mods:mods[ft:query(mods:originInfo/mods:dateCreated, '$q*', $options)]
			      union
			mods:mods[ft:query(mods:originInfo/mods:dateIssued, '$q*', $options)]
			      union
			mods:mods[ft:query(mods:originInfo/mods:dateCaptured, '$q*', $options)]
			      union
			mods:mods[ft:query(mods:originInfo/mods:copyrightDate, '$q*', $options)]
			      union
			mods:mods[ft:query(mods:relatedItem/mods:originInfo/mods:dateCreated, '$q*', $options)]
			      union
			mods:mods[ft:query(mods:relatedItem/mods:originInfo/mods:dateIssued, '$q*', $options)]
			      union
			mods:mods[ft:query(mods:relatedItem/mods:originInfo/mods:dateCaptured, '$q*', $options)]
			      union
			mods:mods[ft:query(mods:relatedItem/mods:originInfo/mods:copyrightDate, '$q*', $options)]
			      union
			mods:mods[ft:query(mods:part/mods:date, '$q*', $options)]
			      union
			mods:mods[ft:query(mods:relatedItem/mods:part/mods:date, '$q*', $options)]
			)
		</field>
		<field name="Identifier">mods:mods[ft:query(mods:identifier, '$q', $options)]</field>
		<field name="Abstract">mods:mods[ft:query(mods:note, '$q', $options)]</field>
        <field name="Note">mods:mods[ft:query(mods:note, '$q', $options)]</field>
        <field name="Subject">mods:mods[ft:query(mods:subject, '$q', $options)]</field>
       	<field name="All">
       		(
       		mods:mods[ft:query(.//*, '$q', $options)] 
       			union
       		ft:search('page:$q')
       		)
       	</field>
        <field name="ID">mods:mods[@ID = '$q']</field>        
        <field name="XLink">mods:mods[mods:relatedItem/@xlink:href = '$q']</field>
	</fields>;

(:
    Default template to be used for form generation if no
    query was specified. This sets the search for all records in the theme default collection.
:)
declare variable $biblio:TEMPLATE_QUERY :=
    <query>
        <collection>{theme:get-root()}</collection>
        <and>
            <field m="1" name="All"></field>
        </and>
    </query>;

(:~
    Regenerate the HTML form to match the query, e.g. after adding more filter
    clauses.
:)
(: NB: why can only two filters be added? Clicking on a filter adds it to the search, but adding a third filter does not work. :)
declare function biblio:form-from-query($node as node(), $params as element(parameters)?, $model as item()*) as element()+ {
    let $incoming-query := $model[1]
    let $query := if ($incoming-query//field) then $incoming-query else $biblio:TEMPLATE_QUERY
    for $field at $pos in $query//field
    return
        <tr class="repeat">
            <td class="operator">
            {
                let $operator := 
                    if ($field/preceding-sibling::*) then
                        $field/../local-name(.)
                    else
                        ()
                return
                    <select name="operator{$pos}">
                    { if (empty($operator)) then attribute style { "display: none;" } else () }
                    {
                        for $opt in ("and", "or", "not")
                        return
                            <option>
                            {
                                if ($opt eq $operator) then
                                    attribute selected { "selected" }
                                else
                                    ()
                            }
                            { $opt }
                            </option>
                    }
                    </select>
            } 
            </td>
            <td class="search-term"> 
                <jquery:input name="input{$pos}" value="{$field/string()}">
                    <jquery:autocomplete url="autocomplete.xql"
                        width="300" multiple="false"
                        matchContains="false"
                        paramsCallback="autocompleteCallback">
                    </jquery:autocomplete>
                </jquery:input>
            </td>
            <td class="search-field">
                in 
                <select name="field{$pos}">
                {
                    for $f in $biblio:FIELDS/field
                    return
                        <option>
                            { if ($f/@name eq $field/@name) then attribute selected { "selected" } else () }
                            {$f/@name/string()}
                        </option>
                }
                </select>
            </td>
        </tr>
};

(:~
    Generate an XPath query string from the given XML representation
    of the query.
:)
declare function biblio:generate-query($query-as-xml as element()) as xs:string* {
    typeswitch ($query-as-xml)
        case element(query) return
            for $child in $query-as-xml/*
            (: The query is decomposed into collection and field. Why does this not include sort? :)
                return
                    biblio:generate-query($child)
        case element(and) return
            (
                biblio:generate-query($query-as-xml/*[1]), 
                " intersect ", 
                biblio:generate-query($query-as-xml/*[2])
            )
        case element(or) return
            (
                biblio:generate-query($query-as-xml/*[1]), 
                " union ", 
                biblio:generate-query($query-as-xml/*[2])
            )
        case element(not) return
            (
                biblio:generate-query($query-as-xml/*[1]), 
                " except ", 
                biblio:generate-query($query-as-xml/*[2])
            )
        (: determine which field to search in: if a field has been specified, use it; otherwise use "All". :)
        case element(field) return
            let $expr := $biblio:FIELDS/field[@name = $query-as-xml/@name]
            let $expr := 
                if ($expr) 
                then $expr 
                else $biblio:FIELDS/field[name eq 'All']
            let $collection-path := 
                (: When searching for ID and xlink:href, do not use the chosen collection-path, but search throughout resources. :)
                if ($expr/@name = ('ID', 'XLink')) 
                then '/resources' 
                else $query-as-xml/ancestor::query/collection/string()
            let $collection :=
                if ($collection-path eq $config:groups-collection)
                (:if ($collection-path eq $config:groups-collection or $collection-path eq fn:replace($config:groups-collection, "/db/", "")):)
                then
                (
                    (: searching the virtual 'groups' collection means searching the users collection. ??? :)
                    fn:concat("collection('", $config:users-collection, "')//")
                )
                else
                (
                    (: search one of the user's own collections or a commons collection. :)
                    fn:concat("collection('", $collection-path, "')//")
                )
            return
                ($collection, replace($expr, '\$q', biblio:escape-search-string($query-as-xml/string())))
        case element(collection) 
            return
                if (not($query-as-xml/..//field)) 
                then ('collection("', $query-as-xml/string(), '")//mods:mods')
                else ()
            default 
                return ()
};

(: If an apostrophe occurs in the search string, it is escaped.:) 
declare function biblio:escape-search-string($search-string as xs:string?) as xs:string? {
	replace($search-string, "'", "''")
};

(:~
    Transform the XML representation of the query into a simple string
    for display to the user in the query history.
:)
declare function biblio:xml-query-to-string($query-as-xml as element()) as xs:string* {
    typeswitch ($query-as-xml)
        case element(query) return
            for $query-term in $query-as-xml/*
                return biblio:xml-query-to-string($query-term)
        case element(and) return
            (
                biblio:xml-query-to-string($query-as-xml/*[1]), 
                " AND ", 
                biblio:xml-query-to-string($query-as-xml/*[2])
            )
        case element(or) return
            (
                biblio:xml-query-to-string($query-as-xml/*[1]), 
                " OR ", 
                biblio:xml-query-to-string($query-as-xml/*[2])
            )
        case element(not) return
            (
                biblio:xml-query-to-string($query-as-xml/*[1]), 
                " NOT ", 
                biblio:xml-query-to-string($query-as-xml/*[2])
            )
        case element(collection) return
            fn:concat("collection(""", $query-as-xml, """):")
        case element(field) return
            concat($query-as-xml/@name, ':', $query-as-xml/string())
        default return
            ()
};

(:~
    Process single form parameter. Called from biblio:process-form().
:)
declare function biblio:process-form-parameters($params as xs:string*) as element() {
    let $param := $params[1]
    let $search-number := substring-after($param, 'input')
    let $value := request:get-parameter($param, "")
    let $search-field := request:get-parameter(concat("field", $search-number), 'All')
    let $operator := request:get-parameter(concat("operator", $search-number), "and")
    return
        if (count($params) eq 1) then
            <field m="{$search-number}" name="{$search-field}">{$value}</field>
        else
            element { xs:QName($operator) } {
                biblio:process-form-parameters(subsequence($params, 2)),
                <field m="{$search-number}" name="{$search-field}">{$value}</field>
            }
};

(:~
    Process the received form parameters and create an XML representation of
    the query. Filter out empty parameters and take care of boolean operators.
:)
declare function biblio:process-form() as element(query)? {
    let $collection := uu:escape-collection-path(request:get-parameter("collection", theme:get-root()))
    let $fields :=
        (:  Get a list of all input parameters which are not empty,
            ordered by input name. :)
        for $param in request:get-parameter-names()[starts-with(., 'input')]
        let $value := request:get-parameter($param, ())
        where string-length($value) gt 0
        order by $param descending
        return
            $param
    return
        if (exists($fields)) then
            (:  process-form recursively calls itself for every parameter and
                generates and XML representation of the query. :)
            <query>
                <collection>{$collection}</collection>
                { biblio:process-form-parameters($fields) }
            </query>
        else
            <query>
                <collection>{$collection}</collection>
            </query>
};

(:~
    Helper function used to sort by name within the "order by"
    clause of the query.
:)
declare function biblio:order-by-author($m as element()) as xs:string?
{
    (: Pick the first name of an author/creator. :)
    let $names := $m/mods:name[mods:role/mods:roleTerm = ('aut', 'author', 'Author', 'cre', 'creator', 'Creator') or not(mods:role/mods:roleTerm)][1] 
    (: Iterate through the single name in order to be able to order it in a return statement. :)
    for $name in $names
    (: Sort according to family and given names.:)
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
	    	then $name/mods:namePart[@lang = ('eng', 'fre', 'ger')][@type='given'][1]/text()
	    	else
		    	if ($name/mods:namePart[@transliteration]/text())
		    	then $name/mods:namePart[@type='given'][@transliteration][1]/text()
			    else
			    	if ($name/mods:namePart[not(@script) or @script = 'Latn']/text())
		    		then $name/mods:namePart[@type='given'][not(@script) or @script = 'Latn'][1]/text()
		    		else $name/mods:namePart[@type='given'][1]/text()
    let $sort := upper-case(concat($sortFirst, ' ', $sortLast))
    order by upper-case($sort) ascending empty greatest
    return
        $sort
};
    
(: Map order parameter to xpath for order by clause :)
(: NB: It does not make sense to use Score if there is no search term to score on. :)
declare function biblio:construct-order-by-expression($field as xs:string?) as xs:string
{
    if (sort:has-index('mods:name')) 
    (: If there is an index on name, there will be an index on the other options. ??? :)
    then
        if ($field eq "Score") 
        then "ft:score($hit) descending"
        else 
            if ($field = "Author") 
            then "sort:index('mods:name', $hit)"
            else 
                if ($field = "Title")
                then "sort:index('mods:title', $hit)"
                (: Defaulting to $field = "Date" :)
                else "sort:index('mods:date', $hit)"
    else
        if ($field eq "Score") 
        then "ft:score($hit) descending"
        else 
            if ($field = "Author") 
            then "biblio:order-by-author($hit)"
            else 
                if ($field = "Title") 
                then "$hit/mods:titleInfo[not(@type)][1]/mods:title[1] ascending empty greatest"
                else "$hit/mods:originInfo[1]/mods:dateIssued[1]/number() descending empty least"
};

(:~
    Evaluate the actual XPath query and order the results
:)
declare function biblio:evaluate-query($query-as-string as xs:string, $sort as xs:string?) {
    let $order-by-expression := biblio:construct-order-by-expression($sort)
    let $query-with-order-by-expression :=
            concat("for $hit in ", $query-as-string, " order by ", $order-by-expression, " return $hit")
    let $options :=
        <options>
            <default-operator>and</default-operator>
        </options>
    return
        util:eval($query-with-order-by-expression)
};

(:~
    Add a query to the user's query history. We store the XML representation
    of the query.
:)
declare function biblio:add-to-history($query-as-xml as element()) {
    let $oldHistory := session:get-attribute('history')
    let $newHistory :=
        let $n := if ($oldHistory) then max(for $n in $oldHistory/query/@n return xs:int($n)) + 1 else 1
        return
            <history>
                <query id="q{$n}" n="{$n}">
                    { $query-as-xml/* }
                </query>
                { $oldHistory/query }
            </history>
    return
        session:set-attribute('history', $newHistory)
};

(:~
    Retrieve a query from the query history
:)
declare function biblio:query-from-history($id as xs:string) {
    let $history := session:get-attribute('history')
    return
        $history/query[@id = $id]
};

(:~
    Returns the query history as a HTML list. The queries are
    transformed into a simple string representation.
:)
declare function biblio:query-history($node as node(), $params as element(parameters)?, $model as item()*) {
    <ul>
    {
        let $history := session:get-attribute('history')
        for $query-as-string at $pos in $history/query
        return
            <li><a href="?history={$query-as-string/@id}&amp;query-tabs=advanced-search-form">{biblio:xml-query-to-string($query-as-string)}</a></li>
    }
    </ul>
};

(:~
    Evaluate the query given as XML and store its results into the HTTP session
    for later reference.
:)
declare function biblio:eval-query($query-as-xml as element(query)?, $sort0 as item()?) as xs:int {
    if ($query-as-xml) then
        let $query := string-join(biblio:generate-query($query-as-xml), '')
        let $sort := if ($sort0) then $sort0 else session:get-attribute("sort")
        let $results := biblio:evaluate-query($query, $sort)
        let $processed :=
            for $item in $results
            return
                typeswitch ($item)
                    case element(results) return
                        $item/search
                    default return
                        $item
        (:~ Take the query results and store them into the HTTP session. :)
        let $null := session:set-attribute('mods:cached', $processed)
        let $null := session:set-attribute('query', $query-as-xml)
        let $null := session:set-attribute('sort', $query-as-xml)
        let $null := biblio:add-to-history($query-as-xml)
        return
            count($processed)
    else
        0
};

(:~ 
: Outputs a notice (if any) to the user
:)
declare function biblio:notice() as element(div)* {
    
    (: have we already seen the notices for this session? :)
    if(session:get-attribute("seen-notices") eq true()) then
    ()
    else
    (
        (: 1 - is there a login notice :)
        
        (: find all collections that are shared with the current user and whoose modification time is after our last login time :)
        
        let $shared-roots := sharing:get-shared-collection-roots(false()) return
        if(not(empty($shared-roots)))then
        (
            let $last-login-time := security:get-last-login-time(security:get-user-credential-from-session()),
            $collections-modified-since-last-login := local:find-collections-modified-after($shared-roots, $last-login-time) return
               
                if(not(empty($collections-modified-since-last-login)))then
                (
                    <div id="notices-dialog" title="System Notices">
                        <p>The following Groups have published new or updated documents since you last logged in:</p>
                        <ul>
                            {
                                for $modified-collection in $collections-modified-since-last-login return
                                    <li>{ fn:replace($modified-collection, ".*/", "") } ({ count(xmldb:get-child-resources($modified-collection)[$last-login-time lt xmldb:last-modified($modified-collection, .)]) })</li>
                            }
                        </ul>
                    </div>
                )else()
        )else()
    )
};

(:~
: Get the last-modified date of a collection
:)
declare function local:get-collection-last-modified($collection-path as xs:string) as xs:dateTime {
	
	let $resources-last-modified := 
		for $resource in xmldb:get-child-resources($collection-path) return
			xmldb:last-modified($collection-path, $resource)
	return
		if(not(empty($resources-last-modified)))then
			max(
				$resources-last-modified	
			)
		else
			xmldb:created($collection-path)
};

(:~
: Find all sub-collections that have a group and are modified after a dateTime
:)
declare function local:find-collections-modified-after($collection-paths as xs:string*, $modified-after as xs:dateTime) as xs:string* {
	
	for $collection-path in $collection-paths return
	(
	   if($modified-after lt local:get-collection-last-modified($collection-path)) then
	       $collection-path
	   else(),
       local:find-collections-modified-after(xmldb:get-child-collections($collection-path), $modified-after)
   )
};

(:~
    Clear the last query result.
:)
declare function biblio:clear() {
    let $null := session:remove-attribute('mods:cached')
    let $null := session:remove-attribute('query')
    let $null := session:remove-attribute('sort')
    return
        ()
};

declare function biblio:current-user($node as node(), $params as element(parameters)?, $model as item()*) {
    <span>{request:get-attribute("xquery.user")}</span>
};

declare function biblio:login($node as node(), $params as element(parameters)?, $model as item()*) {
    let $user := request:get-attribute("xquery.user")
    return 
        if ($user eq 'guest') then
        (
            <div class="help"><a href="../../docs/index.xml" target="_blank">Help</a></div>
            ,
            <div class="login"><a href="#" id="login-link">Login</a></div>
        )
        else
        (
            <div class="help"><a href="../../docs/index.xml">Help</a></div>
            ,
            <div class="login">Logged in as <span class="username">{let $human-name := security:get-human-name-for-user($user) return if(fn:not(fn:empty($human-name)))then $human-name else $user}</span>. <a href="?logout=1">Logout</a></div>
        )
};

declare function biblio:collection-path($node as node(), $params as element(parameters)?, $model as item()*) {
    let $collection := functx:replace-first(uu:escape-collection-path(request:get-parameter("collection", theme:get-root())), "/db/", "")
    return
        templates:copy-set-attribute($node, "value", uu:unescape-collection-path($collection), $model)
};

declare function biblio:result-count($node as node(), $params as element(parameters)?, $model as item()*) {
    let $hitCount := $model[2]
    return
        if ($hitCount != 1)
        then (<span class="hit-count">{$hitCount}</span>, ' records')
        else (<span class="hit-count">{$hitCount}</span>, ' record')
};

declare function biblio:resource-types($node as node(), $params as element(parameters)?, $model as item()*) {
    let $classifier := tokenize($node/@class, "\s")
    let $classifier := $classifier[2]
    let $code-tables := concat($config:edit-app-root, '/code-tables')
    let $document-path := concat($code-tables, '/document-type-codes.xml')
    let $language-path := concat($code-tables, '/language-3-type-codes.xml')
    let $transliteration-path := concat($code-tables, '/transliteration-short-codes.xml')
    let $script-path := concat($code-tables, '/script-codes.xml')
    let $code-table-type := doc($document-path)/code-table
    let $code-table-lang := doc($language-path)/code-table
    let $code-table-transliteration := doc($transliteration-path)/code-table
    let $code-table-script := doc($script-path)/code-table
    return 
        <div class="content">
            <form id="{if ($classifier eq 'stand-alone') then 'new-resource-form' else 'add-related-form'}" action="../edit/edit.xq" method="GET">
                <ul>
                {
                    for $item in $code-table-type//item[classifier = $classifier]
                    order by $item/sort/text(), $item/label/text()
                    return
                        <li>
                          <input type="radio" name="type" value="{$item/value/text()}"/><span> {$item/label/text()}</span>
                        </li>
                }
                </ul>
                
                <div class="language-label">
                    <label for="languageOfResource">Resource Language: </label>
                <span class="language-list">
                <select name="languageOfResource">
                    {
                        for $item in $code-table-lang//item
                        let $label := $item/label/text()
                        let $labelValue := $item/value/text()
                        let $sortOrder := 
                            if (empty($item/frequencyClassifier)) 
                            then 'B' 
                            else 
                                if ($item/frequencyClassifier[. = 'common']) 
                                then 'A' 
                                (: else frequencyClassifier = 'default':)
                                else ''
                        order by $sortOrder, $label
                        return
                            <option value="{$labelValue}">{$item/label/text()}</option>
                    }
                    </select>
                </span>
                </div>
                
                <div class="language-label">
                    <label for="scriptOfResource">Resource Script: </label>
                <span class="language-list">
                <select name="scriptOfResource">
                    {
                        for $item in $code-table-script//item
                        let $label := $item/label/text()
                        let $labelValue := $item/value/text()
                        let $sortOrder := 
                        if (empty($item/frequencyClassifier)) 
                        then 'B' 
                        else 
                            if ($item/frequencyClassifier[. = 'common']) 
                            then 'A' 
                            (: else frequencyClassifier = 'default':)
                            else ''
                        order by $sortOrder, $label
                        return
                            <option value="{$labelValue}">{$item/label/text()}</option>
                    }
                    </select>
                </span>
                </div>
                
                <div class="language-label">
                    <label for="transliterationOfResource">Transliteration Scheme: </label>
                <span class="language-list">
                <select name="transliterationOfResource">
                    {
                        for $item in $code-table-transliteration//item
                        let $label := $item/label/text()
                        let $labelValue := $item/value/text()
                        return
                            <option value="{$labelValue}">{$item/label/text()}</option>
                    }
                    </select>
                </span>
                </div>
                
                <div class="language-label">
                    <label for="languageOfCataloging">Cataloging Language: </label>
                <span class="language-list">
                <select name="languageOfCataloging">
                    {
                        for $item in $code-table-lang//item[(frequencyClassifier)]
                        let $label := $item/label/text()
                        let $labelValue := $item/value/text()
                        let $sortOrder :=                                  
                            if ($item/frequencyClassifier[. = 'common']) 
                            then 'A' 
                            (: else frequencyClassifier = 'default':)
                            else ''
                        order by $sortOrder, $label
                        return
                            <option value="{$labelValue}">{$item/label/text()}</option>
                    }
                    </select>
                </span>
                </div>
                
                <div class="language-label">
                    <label for="scriptOfCataloging">Cataloging Script: </label>
                <span class="language-list">
                <select name="scriptOfCataloging">
                    {
                        for $item in $code-table-script//item[(frequencyClassifier)]
                        let $label := $item/label/text()
                        let $labelValue := $item/value/text()
                        let $sortOrder :=  
                            if ($item/frequencyClassifier[. = 'common']) 
                            then 'A' 
                            (: else frequencyClassifier = 'default':)
                            else ''
                        order by $sortOrder, $label
                        return
                            <option value="{$labelValue}">{$item/label/text()}</option>
                    }
                    </select>
                </span>
                </div>
                
                <input type="hidden" name="collection"/>
                <input type="hidden" name="host"/>
            </form>
        </div>
};

declare function biblio:optimize-trigger($node as node(), $params as element(parameters)?, $model as item()*) {
    let $user := request:get-attribute("xquery.user")
    return
        if (xmldb:is-admin-user($user)) then
            <a id="optimize-trigger" href="#">Create custom indexes for sorting</a>
        else
            ()
};

declare function biblio:form-select-current-user-groups($select-name as xs:string) as element(select) {
    let $user := request:get-attribute("xquery.user") return
        <select name="{$select-name}">
        {
            for $group in xmldb:get-user-groups($user) return
                <option value="{$group}">{$group}</option>
        }
        </select>
};

declare function biblio:get-writeable-subcollection-paths($path as xs:string) {
    
	for $sub in xmldb:get-child-collections($path)
	let $col := concat($path, "/", $sub) return
		(
			if(security:can-write-collection($col))then
			(
			 $col
			)else(),
			biblio:get-writeable-subcollection-paths($col)
		)
};

(:~
    Filter an existing result set by applying an additional
    clause with "and".
:)
declare function biblio:apply-filter($filter as xs:string, $value as xs:string) {
    let $prevQuery := session:get-attribute("query")
    return
        if (empty($prevQuery//field)) then
            <query>
                { $prevQuery/collection }
                <field name="{$filter}">{$value}</field>
            </query>
        else
            <query>
                { $prevQuery/collection }
                <and>
                { $prevQuery/*[not(self::collection)] }
                <field name="{$filter}">{$value}</field>
                </and>
            </query>
};

(:~
: Prepare an XML fragment which describes the query to undertake
:
:)
declare function biblio:prepare-query($id as xs:string?, $collection as xs:string, $reload as xs:string?, $history as xs:string?, $clear as xs:string?, $filter as xs:string?, $mylist as xs:string?, $value as xs:string?) as element(query)? {
    if ($id) then
        <query>
            <collection>{$config:mods-root}</collection>
            <field m="1" name="Id">{$id}</field>
        </query>
    else if (empty($collection)) then
        () (: no parameters sent :)
    else if ($reload) then
        session:get-attribute('query')
    else if ($history) then
        biblio:query-from-history($history)
    else if ($clear) then
        biblio:clear()
    else if ($filter) then 
        biblio:apply-filter($filter, $value)
    else if ($mylist eq 'display') then
        ()
    else 
        biblio:process-form()
};

(:~
: Gets cached results from the session
: if not such results exist, then a query is performed
: and the resilts are then cached in the session
:
: @retun a count of the results available
:)
declare function biblio:get-or-create-cached-results($mylist as xs:string?, $query as element(query)?, $sort as item()?) as xs:int {
    if($mylist) then (
        if ($mylist eq 'clear') then
            session:set-attribute("personal-list", ())
        else
            (),
        let $list := session:get-attribute("personal-list")
        let $items :=
            for $item in $list/listitem
            return
                util:node-by-id(doc(substring-before($item/@id, '#')), substring-after($item/@id, '#'))
        let $null := session:set-attribute('mods:cached', $items)
        return
            count($items)
    ) else
        biblio:eval-query($query, $sort)
};

declare function biblio:query($node as node(), $params as element(parameters)?, $model as item()*) {
    session:create(),
    (: We receive an HTML template as input :)
    let $filter := request:get-parameter("filter", ())
    let $history := request:get-parameter("history", ())
    let $reload := request:get-parameter("reload", ())
    let $clear := request:get-parameter("clear", ())
    let $mylist := request:get-parameter("mylist", ())
    let $collection := uu:escape-collection-path(request:get-parameter("collection", $config:mods-root))
    let $collection := if (starts-with($collection, "/db")) then $collection else concat("/db", $collection)
    let $id := request:get-parameter("id", ())
    (:the search term passed in the url:)
    let $value := request:get-parameter("value",())
    let $sort := request:get-parameter("sort", ())
    
    (: Process request parameters and generate an XML representation of the query :)
    let $query-as-xml := biblio:prepare-query($id, $collection, $reload, $history, $clear, $filter, $mylist, $value)
    
    (: Get the results :)
    let $results := biblio:get-or-create-cached-results($mylist, $query-as-xml, $sort)
    return
        templates:process($node/node(), ($query-as-xml, $results))
};