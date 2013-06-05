xquery version "1.0";

declare namespace mods="http://www.loc.gov/mods/v3";
declare namespace vra = "http://www.vraweb.org/vracore4.htm";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare option exist:serialize "media-type=text/json";

declare variable $local:COLLECTION := '/db/resources';
declare variable $local:FIELDS :=
	<fields>
		<field name="Title">mods:titleInfo</field>
		<field name="Title">vra:titleSet</field>
		<field name="Title">tei:title</field>
		
		<field name="Name">mods:name</field>
		<field name="Name">vra:agentSet</field>
		<field name="Name">tei:name</field>
		<field name="Name">tei:persName</field>
		
		<field name="Origin">mods:placeTerm</field>
		<field name="Origin">mods:publisher</field>
		
		<field name="Date">mods:dateCreated</field>
		<field name="Date">mods:dateIssued</field>
		<field name="Date">mods:dateCaptured</field>
		<field name="Date">mods:copyrightDate</field>
		<field name="Date">mods:date</field>
		
		<field name="Identifier">mods:identifier</field> 
		
		<field name="Abstract/Description">mods:abstract</field>
		<field name="Abstract/Description">vra:descriptionSet</field>
		
		<field name="Note">mods:note</field>
		
		<field name="Subject">mods:subject</field>
		<field name="Subject">vra:subjectSet</field>
		
		<field name="Genre">mods:genre</field>
		
		<field name="Language">mods:language</field>
		
		<field name="All">mods:mods</field>
		<field name="All">vra:vra</field>
		<field name="All">tei:TEI</field>
	</fields>;

declare function local:key($key, $options) {
    concat('"', $key, '"')
};

let $collection := xmldb:encode(request:get-parameter("collection", $local:COLLECTION))
let $term := request:get-parameter("term", ())
let $field := request:get-parameter("field", "All")
let $qnames :=
    if ($field eq "All") 
    then 
        for $field in $local:FIELDS/field 
            return xs:QName($field/string())
    else 
        for $field in $local:FIELDS/field[@name eq $field]
            return xs:QName($field/string())
let $callback := util:function(xs:QName("local:key"), 2)
let $autocompletes := string-join(collection($collection)/util:index-keys-by-qname($qnames, $term, $callback, 20, "lucene-index"),', ')
return
    concat("[", $autocompletes, "]")