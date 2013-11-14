xquery version "1.0";

declare namespace user="http://exist-db.org/xquery/biblio/user";
declare namespace mods="http://www.loc.gov/mods/v3";

declare function user:add-to-personal-list() {
    let $cached := session:get-attribute("mods:cached")
    let $pos := xs:integer(request:get-parameter("pos", 1))
    let $oldList := session:get-attribute("personal-list")
    let $oldList :=
        if ($oldList) then $oldList else <mylist/>
    let $id := concat(document-uri(root($cached[$pos])), '#', util:node-id($cached[$pos]))
    let $newList :=
        <myList>
            <listitem id="{$id}">{ $cached[$pos] }</listitem>
            { $oldList/listitem }
        </myList>
    let $stored := session:set-attribute("personal-list", $newList)
    return
        ()
};

declare function user:remove-from-personal-list() {
    (:Where does "save_" come from?:)
    let $id := substring-after(request:get-parameter("id", ()), "save_")
    let $oldList := session:get-attribute("personal-list")
    let $newList :=
        <myList>
            { $oldList/listitem[not(@id = $id)] }
        </myList>
    let $stored := session:set-attribute("personal-list", $newList)
    return
        ()
};

declare function user:personal-list($list as xs:string) {
    if ($list eq 'add') 
    then user:add-to-personal-list()
    else user:remove-from-personal-list()
};

declare function user:personal-list-size() {
    let $list := session:get-attribute("personal-list")
    (:let $log := util:log("DEBUG", ("##$list): ", $list)):)
    return
        if (count($list/listitem) eq 1)
        then <span>{count($list/listitem)} item</span>
        else <span>{count($list/listitem)} items</span>
};

declare function user:export-personal-list() as element(mods:modsCollection) {
    util:declare-option("exist:serialize", "method=xml media-type=application/xml"),   
    response:set-header("Content-Disposition", "attachment; filename=export.mods.xml"),
    <mods:modsCollection>
    {
        session:get-attribute("personal-list")/listitem/mods:mods
    }
    </mods:modsCollection>
};

let $log := util:log("DEBUG", ("##param-names: ", string-join(request:get-parameter-names(), ' || ')))
let $log := util:log("DEBUG", ("##$module-param): ", request:get-parameter('action', '')))

let $list := request:get-parameter("list", ())
let $export := request:get-parameter("export", ())
let $list-size := user:personal-list-size()

return
    if ($export)
    then user:export-personal-list()
    else 
        if ($list) 
        then user:personal-list($list)
        else user:personal-list-size()