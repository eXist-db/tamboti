xquery version "1.0";

declare namespace mods="http://www.loc.gov/mods/v3";
declare namespace vra = "http://www.vraweb.org/vracore4.htm";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare option exist:serialize "media-type=text/json";

declare variable $local:COLLECTION := '/db/resources';
declare variable $local:FIELDS :=
	<fields>
		<field name="the Title Field (MODS, TEI, VRA)">mods:titleInfo</field>
		<field name="the Title Field (MODS, TEI, VRA)">vra:titleSet</field>
		<field name="the Title Field (MODS, TEI, VRA)">tei:title</field>
		
		<field name="the Name Field (MODS, TEI, VRA)">mods:name</field>
		<field name="the Name Field (MODS, TEI, VRA)">vra:agentSet</field>
		<field name="the Name Field (MODS, TEI, VRA)">tei:name</field>
		<field name="the Name Field (MODS, TEI, VRA)">tei:persName</field>
		
		<field name="the Origin Field (MODS)">mods:placeTerm</field>
		<field name="the Origin Field (MODS)">mods:publisher</field>
		
		<field name="the Date Field (MODS)">mods:dateCreated</field>
		<field name="the Date Field (MODS)">mods:dateIssued</field>
		<field name="the Date Field (MODS)">mods:dateCaptured</field>
		<field name="the Date Field (MODS)">mods:copyrightDate</field>
		<field name="the Date Field (MODS)">mods:date</field>
		
		<field name="the Resource Identifier Field (MODS)">mods:identifier</field> 
		
		<field name="the Description/Abstract Field (MODS, VRA)">mods:abstract</field>
		<field name="the Description/Abstract Field (MODS, VRA)">vra:descriptionSet</field>
		
		<field name="the Note Field (MODS)">mods:note</field>
		
		<field name="the Subject/Term Field (MODS, TEI, VRA)">mods:subject</field>
		<field name="the Subject/Term Field (MODS, TEI, VRA)">vra:subjectSet</field>
		<field name="the Subject/Term Field (MODS, TEI, VRA)">tei:term</field>
		
		<field name="the Genre Field (MODS)">mods:genre</field>
		
		<field name="the Language Codes Field (MODS)">mods:language</field>
		
		<field name="any Field (MODS, TEI, VRA)">mods:mods</field>
		<field name="any Field (MODS, TEI, VRA)">vra:vra</field>
		<field name="any Field (MODS, TEI, VRA)">tei:TEI</field>
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