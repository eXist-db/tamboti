xquery version "3.0";

module namespace tamboti-common="http://exist-db.org/tamboti/common";

(:
tamboti-common:get-query-as-regex
tamboti-common:highlight-matches()
:)

(: Later move
tamboti-common:clean-up-punctuation()
tamboti-common:simple-row()
tamboti-common:add-part()
tamboti-common:serialize-list()
tamboti-common:remove-parent-with-missing-required-node()
functx:capitalize-first()
functx:camel-case-to-words()
functx:trim()
:)

(:~
: The tamboti-common:get-query-as-regex function gets the query ($query-as-xml) from the session
: and reformats the Lucene search expressions into regex expressions, for use in tamboti-common:highlight-matches().
:)
declare function tamboti-common:get-query-as-regex() as xs:string { 
    let $query := session:get-attribute("query")
    let $query := $query//field/text()
    let $query := replace(replace(replace($query, '\sAND\s', ' ', 'i'), '\sOR\s', ' ', 'i'), '\sNOT\s', ' ', 'i')
    (:we assume that '+' and '-' are only used for prefixing:)
    (:NB: why can one not use '\b'?:)
    let $query := replace(replace($query, '\+', ' '), '\-', ' ')
    let $query := translate(translate($query, '(', ''), ')', '')
    let $query := normalize-space($query)
    let $query := 
        if (starts-with($query, '"') and ends-with($query, '"')) 
        then translate($query, '"', '')
        else concat(
            '\b'
            , 
            replace(
                replace(
                    replace(
                        translate(
                            string-join($query, '|')
                        , ' ', '|')
                    , '\?', '\\w')
                , '\*', '\\w*?')
            , '~', '') (:we can do nothing with fuzzy searches:)
            ,
            '\b')
        let $log := util:log("DEBUG", ("##$query): ", $query))
        return $query
};

(:~
: The tamboti-common:highlight-matches function highlights the search result in detail view with the search string, including 
: searches made with wildcards. Slightly adapted from Joe Wicentowski's function in order to dealt with Lucene casing.
: @author Joe Wicentowski
: @param $nodes the search result to apply highlighting to
: @param $pattern the regex used for applying highlighting
: @param $highlight the highlight function
: @return one or more items
: @see https://gist.github.com/joewiz/5937897
:)
declare function tamboti-common:highlight-matches($nodes as node()*, $pattern as xs:string, $highlight as function(xs:string) as item()* ) { 
    for $node in $nodes
    return
        typeswitch ( $node )
            case element() return
                element { name($node) } { $node/@*, tamboti-common:highlight-matches($node/node(), $pattern, $highlight) }
            case text() return
                let $normalized := replace($node, '\s+', ' ')
                (:apply case-insensitive search for use with Lucene:)
                for $segment in analyze-string($normalized, $pattern, 'i')/node()
                return
                    if ($segment instance of element(fn:match)) then 
                        $highlight($segment/string())
                    else 
                        $segment/string()
            case document-node() return
                document { tamboti-common:highlight-matches($node/node(), $pattern, $highlight) }
            default return
                $node
};

