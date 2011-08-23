xquery version "1.0";

import module namespace config="http://exist-db.org/mods/config" at "../config.xqm";
import module namespace json="http://www.json.org";
import module namespace security="http://exist-db.org/mods/security" at "security.xqm";
import module namespace sharing="http://exist-db.org/mods/sharing" at "sharing.xqm";
import module namespace uu="http://exist-db.org/mods/uri-util" at "uri-util.xqm";

import module namespace session = "http://exist-db.org/xquery/session";
import module namespace request = "http://exist-db.org/xquery/request";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace xmldb = "http://exist-db.org/xquery/xmldb";

declare namespace exist = "http://exist.sourceforge.net/NS/exist";
declare namespace group = "http://commons/sharing/group";
declare namespace col = "http://library/search/collections";

declare option exist:serialize "method=json media-type=text/javascript";

(:~
: Generates tree nodes for navigation of collections in
: the library search app. Uses the JSON serializer to get JSON output.
:
: Also generates a virtual collection root called 'Groups', this starts
: as /db/commons/groups and then any sub-collection under here
: is actually a link back to the shared collection (i.e. a collection in a users home folder)
: Group collection paths look like /db/commons/group/{uuid}/{collection-name}
: The {uuid} refers to an entry stored in /db/commons/group
: The {collection-name} is the real name of the collection from the original users folder
:
: The JSON output generated is suitable for use with dynatree
:
: @author Adam Retter <adam@existsolutions.com>
:)

declare variable $user-folder-icon := "../skin/ltFld.user.gif";
declare variable $groups-folder-icon := "../skin/ltFld.groups.gif";
declare variable $writeable-folder-icon := "../skin/ltFld.page.png";
declare variable $not-writeable-folder-icon := "../skin/ltFld.locked.png";
declare variable $writeable-and-shared-folder-icon := "../skin/ltFld.page.link.png";
declare variable $not-writeable-and-shared-folder-icon := "../skin/ltFld.locked.link.png";
declare variable $commons-folder-icon := "../skin/ltFld.png";

(:~
: Outputs details about a collection as a tree-node
:
: @param title
:   Title of the tree node
: @param collection-path
:   Collection path that backs the tree node
: @param is-folder
:   Is this tree node a folder?
: @param $icon-path
:   Optional path to a custom icon
: @param $tooltip
:   Optional tooltip
: @param writeable
:   Is this tree node writeable - i.e. can folders/resources be added to it
: @param additional-classes
:   Optional additional CSS classes to apply
: @param has-lazy-children
:   Are there children for this node which can be lazily fetched?
: @param explicit-children
:   Any children that should be explicity displayed, ignored if has-lazy-children is true()
:
:)
declare function col:create-tree-node($title as xs:string, $collection-path as xs:string, $is-folder as xs:boolean, $icon-path as xs:string?, $tooltip as xs:string?, $writeable as xs:boolean, $additonal-classes as xs:string*, $has-lazy-children as xs:boolean, $explicit-children as element(node)*) as element(node) {
    <node>
        <title>{uu:unescape-collection-path($title)}</title>
        <key>{uu:unescape-collection-path($collection-path)}</key>
        <isFolder>{$is-folder}</isFolder>
        <writeable>{$writeable}</writeable>
        <addClass>{
            fn:string-join(
                (if($writeable) then 'writable' else 'readable', $additonal-classes),
                ' '
            )
        }</addClass>
        {
        if($icon-path)then
            <icon>{$icon-path}</icon>
        else if(fn:starts-with($collection-path, $config:mods-commons))then
            <icon>{$commons-folder-icon}</icon>
        else if(fn:starts-with($collection-path, security:get-home-collection-uri(security:get-user-credential-from-session()[1])) and fn:not(fn:empty($tooltip)))then
            if($writeable)then
                <icon>{$writeable-and-shared-folder-icon}</icon>
            else
                <icon>{$not-writeable-and-shared-folder-icon}</icon>
        else if($writeable)then
            <icon>{$writeable-folder-icon}</icon>
        else
            <icon>{$not-writeable-folder-icon}</icon>
        ,
        if($tooltip)then
            <tooltip>{$tooltip}</tooltip>
        else()
        }
        <isLazy>{$has-lazy-children}</isLazy>
        {
            if(not($has-lazy-children) and not(empty($explicit-children)))then
                for $explicit-child in $explicit-children return
                    <children>{$explicit-child/child::node()}</children>
            else()
        }
    </node>
};

(:~
: Gets the root collection and any special collections directly under root
:
: @param root-collection-path
:   Path to the root collection in the database
:)
declare function col:get-root-collection($root-collection-path as xs:string) as element(node) {

    let $user := security:get-user-credential-from-session()[1] return

        if(security:can-read-collection($root-collection-path)) then
            let $children := xmldb:get-child-collections($root-collection-path),
            $can-write := security:can-write-collection($root-collection-path),
            
            (: home collection :)
            $home-json := 
                if(security:home-collection-exists($user))then
                    let $home-collection-path := security:get-home-collection-uri($user),
                    $has-home-children := not(empty(xmldb:get-child-collections($home-collection-path))) return
                        col:create-tree-node("Home", $home-collection-path, true(), $user-folder-icon , "Home Folder", true(), "userHomeSubCollection", $has-home-children, ())
                else(),
            
            (: group collection :)
            $has-group-children := not(empty(sharing:get-shared-collection-roots(false()))),
            $group-json := col:create-tree-node("Groups", $config:groups-collection, true(), $groups-folder-icon, "Groups", false(), (), $has-group-children, ()),
            
            (: commons collections :)
            $public-json :=
                for $child in xmldb:get-child-collections($config:mods-commons)
                let $collection-path := fn:concat($config:mods-commons, "/", $child) return
                    <node>{col:get-collection($collection-path)/child::node()}</node>
            return
            
                (: root collection, containing home and group collection as children :)
                col:create-tree-node(fn:replace($root-collection-path, ".*/", ""), $root-collection-path, true(), (), (), $can-write, (), false(), ($home-json, $group-json, $public-json))
        else
            ()
};

(:~
: Gets lazy child collections
:
: @param collection-path
:   The parent collection path
:)
declare function col:get-child-collections($collection-path as xs:string) as element(json:value)? {
    
    if(security:can-read-collection($collection-path)) then
        
        (:get children :)
        let $children := xmldb:get-child-collections($collection-path) return
            
            if(count($children) gt 1)then   (: TODO - we need this 'if' statement at the moment because if there is only one output node then the json output gets broken :)
                <json:value>
                {
                    for $child in $children
                    let $child-collection-path := fn:concat($collection-path, "/", $child) return
                    
                        (: output the child :)
                        col:get-collection($child-collection-path)
                }
                </json:value>
            else if(count($children) eq 1)then
                let $child-collection-path := fn:concat($collection-path, "/", $children[1]) return
                    (: output the child :)
                    col:get-collection($child-collection-path)
            else()
    else()           
};

(:~
: Gets a collection
:
: @param collection-path
:    The path of the collection to retrieve
:)
declare function col:get-collection($collection-path as xs:string) as element(json:value)? {

        (: perform some checks on the collection :)
    if(security:can-read-collection($collection-path))then
        let $name := fn:replace($collection-path, ".*/", ""),
        $can-write := security:can-write-collection($collection-path),
        $has-children := not(empty(xmldb:get-child-collections($collection-path))),
        $shared-with := sharing:get-shared-with($collection-path),
        
        $tooltip := 
            if($shared-with)then
                fn:concat("Shared With: ", $shared-with)
            else()
        return
            (: output the collection :)
            <json:value>
            {
                col:create-tree-node($name, $collection-path, true(), (), $tooltip, $can-write, (), $has-children, ())/child::node()
            }
            </json:value>
    else()
};

(: gets all the shared collection roots, less the roots shared by us :)
declare function col:_get-shared-collection-roots-by-others() as xs:string* {
    
    let $my-home := security:get-home-collection-uri(security:get-user-credential-from-session()[1]) return
    
    for $root in sharing:get-shared-collection-roots(false()) return
        if(fn:starts-with($root, $my-home) eq false())then
            $root
        else()
};

(:~
: Gets the virtual "Groups" root, i.e. returns all groups that are accessible to a user
:)
declare function col:get-groups-virtual-root() as element(json:value) {
    
    let $shared-roots := col:_get-shared-collection-roots-by-others() return
        if(count($shared-roots) gt 1)then
            <json:value>
            {
                for $shared-root in $shared-roots return
                    <json:value>
                    {
                        col:create-tree-node(fn:replace($shared-root, ".*/", ""), $shared-root, true(), (), (), security:can-write-collection($shared-root), (), true(), ())/child::node()
                    }
                    </json:value>
            }
            </json:value>
        else if(count($shared-roots) eq 1) then
            <json:value>
            {
                col:create-tree-node(fn:replace($shared-roots[1], ".*/", ""), $shared-roots[1], true(), (), (), security:can-write-collection($shared-roots[1]), (), true(), ())/child::node()
            }
            </json:value>
        else
            <json:value/>
};

(:~
: Request routing
:
: If the http querystring parameter key exists then we retrieve tree nodes based on this
: key which is basically a real or virtual (for groups) collection path.
: If there is no key we deliver the tree root
:)
if(request:get-parameter("key",()))then
    let $collection-path := uu:escape-collection-path(request:get-parameter("key",())) return
        if($collection-path eq $config:groups-collection) then
            (: start of groups collection - the groups collection is virtual and so receives special treatment :)
            col:get-groups-virtual-root()
        
          (: children of virtual group collection :)
          (:else if(fn:starts-with($collection-path, $config:groups-collection)) then
            col:get-group-virtual-child-collections($collection-path) :)
            
        else
            (: just a child collection :)   
            col:get-child-collections($collection-path)
else
    (: no key, so its the root that we want :)
    col:get-root-collection($config:mods-root)