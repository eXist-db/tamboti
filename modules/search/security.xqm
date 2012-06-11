xquery version "1.0";

module namespace security="http://exist-db.org/mods/security";

import module namespace config="http://exist-db.org/mods/config" at "../config.xqm";
import module namespace session="http://exist-db.org/xquery/session";
import module namespace sm="http://exist-db.org/xquery/securitymanager";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

declare variable $security:GUEST_CREDENTIALS := ("guest", "guest");
declare variable $security:SESSION_USER_ATTRIBUTE := "biblio.user";
declare variable $security:SESSION_PASSWORD_ATTRIBUTE := "biblio.password";

declare variable $security:biblio-users-group := "biblio.users";
declare variable $security:user-metadata-file := "security.metadata.xml";

(:~
: Authenticates a user and creates their mods home collection if it does not exist
:
: @param user The username of the user
: @param password The password of the user
:)
declare function security:login($user as xs:string, $password as xs:string?) as xs:boolean
{
    let $username := config:rewrite-username(
        if($config:force-lower-case-usernames)then
            fn:lower-case($user)
        else
            $user
        )
    return

        (: authenticate against eXist-db :)
        if(xmldb:login("/db", $username, $password))then
        (
            (: check if the users mods home collectin exists, if not create it (i.e. first login) :)
            if(security:home-collection-exists($username))then
            (
                (: update the last login time:)
                security:update-login-time($username),
                
                true()
            )
            else
            (
                 let $users-collection-uri := security:create-home-collection($username) return
                    true()
            )
            
            
        ) else
            (: authentication failed:)
            false()
};

(:~
: Stores a users credentials for the mods app into the http session
:
: @param user The username
: @param password The password
:)
declare function security:store-user-credential-in-session($user as xs:string, $password as xs:string?) as empty()
{
    let $username := config:rewrite-username(
        if($config:force-lower-case-usernames)then
            fn:lower-case($user)
        else $user
    ) return
    (
        session:set-attribute($security:SESSION_USER_ATTRIBUTE, $username),
        session:set-attribute($security:SESSION_PASSWORD_ATTRIBUTE, $password)
    )
};

(:~
: Retrieves a users credentials for the mods app from the http session
: 
: @return The sequence (username as xs:string, password as xs:string)
: If there is no entry in the session, then the guest account credentials are returned
:)
declare function security:get-user-credential-from-session() as xs:string+
{
    let $user := session:get-attribute($security:SESSION_USER_ATTRIBUTE) return
        if($user)then
        (
            $user,
            session:get-attribute($security:SESSION_PASSWORD_ATTRIBUTE)
        )
        else
            $security:GUEST_CREDENTIALS
};

(:~
: Gets a users email address
:
: @param the username of the user
: @return the email address for the user
:)
declare function security:get-email-address-for-user($username as xs:string) as xs:string?
{
    sm:get-account-metadata($username, xs:anyURI("http://axschema.org/contact/email"))
};

declare function security:get-human-name-for-user($username as xs:string) as xs:string?
{
    sm:get-account-metadata($username, xs:anyURI("http://axschema.org/namePerson"))
};

(:~
: Checks whether a users mods home collection exists
:
: @param user The username
:)
declare function security:home-collection-exists($user as xs:string) as xs:boolean
{
    let $username := if($config:force-lower-case-usernames)then(fn:lower-case($user))else($user) return
        xmldb:collection-available(security:get-home-collection-uri($username))
};

(:~
: Get the URI of a users mods home collection
:)
declare function security:get-home-collection-uri($user as xs:string) as xs:string
{
    let $username := if($config:force-lower-case-usernames)then(fn:lower-case($user))else($user) return
        fn:concat($config:users-collection, "/", $username)
};

(:~
: Creates a users mods home collection and sets permissions
:
: @return The uri of the users home collection or an empty sequence if it could not be created
:)
declare function security:create-home-collection($user as xs:string) as xs:string?
{
    let $username := if($config:force-lower-case-usernames)then(fn:lower-case($user))else($user) return
        if(xmldb:collection-available($config:users-collection))then
        (
            let $collection-uri := xmldb:create-collection($config:users-collection, $username) return
                if($collection-uri) then
                (
                    (:
                    TODO do we need the group 'read' to allow sub-collections to be enumerated?
                        NOTE - this will need to be updated to 'execute' when permissions are finalised in trunk
                    :)
                    let $null := sm:chmod(xs:anyURI($collection-uri), "rwxr-x---"),
                    
                    (: set the group as biblio users group, so that other users can enumerate our sub-collections :)
                    $null := sm:chgrp(xs:anyURI($collection-uri), $security:biblio-users-group),
                    
                    $null := security:create-user-metadata($collection-uri, $username) return
                        $collection-uri
                ) else (
                    $collection-uri
                )
        )else()
};

(:~
: Stores some basic metadata about a user into their home collection
:)
declare function security:create-user-metadata($user-collection-uri as xs:string, $owner as xs:string) as xs:string {
    let $login-time := util:system-dateTime() return
        let $metadata-doc-uri := xmldb:store($user-collection-uri, $security:user-metadata-file,
         <security:metadata>
             <security:last-login-time>{$login-time}</security:last-login-time>
             <security:login-time>{$login-time}</security:login-time>
         </security:metadata>
        ) return
            let $null := sm:chmod($metadata-doc-uri, "rwx------") return
                $metadata-doc-uri
};

(:~
: Update the last login time of a user
:)
declare function security:update-login-time($user as xs:string) as empty() {
    let $user-home-collection := security:get-home-collection-uri($user),
    $security-metadata := fn:doc(fn:concat($user-home-collection, "/", $security:user-metadata-file)) return
        (
            update value $security-metadata/security:metadata/security:last-login-time with string($security-metadata/security:metadata/security:login-time),
            update value $security-metadata/security:metadata/security:login-time with util:system-dateTime()
        )
};

(:~
: Get the last login time of a user
:)
declare function security:get-last-login-time($user as xs:string) as xs:dateTime {
    let $user-home-collection := security:get-home-collection-uri($user) return
        let $last-login := fn:doc(fn:concat($user-home-collection, "/", $security:user-metadata-file))/security:metadata/security:last-login-time return
        if(exists($last-login))then
            $last-login
        else (
            util:log("WARN", fn:concat("Could not find the last-login time for the user '", $user,"'. Does the users metdata exist?")),
            util:system-dateTime()
        )
};

(:~
: Determines if a user has read access to a collection
:
: @param user The username
: @param collection The path of the collection
:)
declare function security:can-read-collection($collection as xs:string) as xs:boolean
{
    sm:has-access($collection, "r")
};

(:~
: Determines if a user has write access to a collection
:
: @param user The username
: @param collection The path of the collection
:)
declare function security:can-write-collection($collection as xs:string) as xs:boolean
{
    sm:has-access($collection, "w")
};

(:~
: Determines if a user has execute to a collection
:
: @param user The username
: @param collection The path of the collection
:)
declare function security:can-execute-collection($collection as xs:string) as xs:boolean
{
    (: TODO remove the 'u' when u is renamed to execute :)
    (sm:has-access($collection, "u") or sm:has-access($collection, "x"))
};

(:~
: Determines if a group has read access to a collection
:
: @param group The group name
: @param collection The path of the collection
:)

(:
declare function security:group-can-read-collection($group as xs:string, $collection as xs:string) as xs:boolean
{
    if(xmldb:collection-available($collection))then
    
        let $permissions := sm:get-permissions($collection) return
        
            (: check the group owner :)
            if($permissions/@group eq $group and (fn:matches($permissions/@mode, "...r.....", "") or fn:matches($permissions/@mode, "......r..")))then
                true()
            else
                (: check the acl :)
                if($permissions/sm:permission/sm:acl/sm:ace[@target eq "GROUP"][@who eq $group][@access_type eq "ALLOWED"][fn:contains(@mode, "r")])then
                    true()
                else
                    false()
    else
        false()
};

(:~
: Determines if a group has write access to a collection
:
: @param group The group name
: @param collection The path of the collection
:)
declare function security:group-can-write-collection($group as xs:string, $collection as xs:string) as xs:boolean
{
    if(xmldb:collection-available($collection))then
    
        let $permissions := sm:get-permissions($collection) return
        
            (: check the group owner :)
            if($permissions/@group eq $group and (fn:matches($permissions/@mode, "....w....", "") or fn:matches($permissions/@mode, ".......w.")))then
                true()
            else
                (: check the acl :)
                if($permissions/sm:permission/sm:acl/sm:ace[@target eq "GROUP"][@who eq $group][@access_type eq "ALLOWED"][fn:contains(@mode, "w")])then
                    true()
                else
                    false()
    else
        false()
};

(:~
: Determines if everyone has read access to a collection
:
: @param collection The path of the collection
:)
declare function security:other-can-read-collection($collection as xs:string) as xs:boolean
{
    if(xmldb:collection-available($collection))then
        let $permissions := sm:get-permissions($collection) return
            fn:matches($permissions/@mode, "......r..")
    else
        false()
};

(:~
: Determines if everyone has write access to a collection
:
: @param collection The path of the collection
:)
declare function security:other-can-write-collection($collection as xs:string) as xs:boolean
{
    if(xmldb:collection-available($collection))then
        let $permissions := sm:get-permissions($collection) return
            fn:matches($permissions/@mode, ".......w.")
    else
        false()
};
:)

(:~
: Determines if the user is the collection owner
:
: @param user The username
: @param collection The path of the collection
:)
declare function security:is-collection-owner($user as xs:string, $collection as xs:string) as xs:boolean
{
    let $username := if($config:force-lower-case-usernames)then(fn:lower-case($user))else($user) return

        if(xmldb:collection-available($collection))then
            let $owner := xmldb:get-owner($collection) return
                $username eq $owner
        else
            false()
};

(:~
: Gets the users for a group
:
: @param the group name
: @return The list of users in the group
:)
declare function security:get-group-members($group as xs:string) as xs:string*
{
    xmldb:get-users($group)
};

(:~
: Gets the managers for a group
:
: @param the group name
: @return The list of managers in the group
:)
(:
declare function security:get-group-managers($group as xs:string) as xs:string*
{
    sm:get-group-managers($group)
};
:)

(:~
: Gets a list of other biblio users
:)
(:
declare function security:get-other-biblio-users() as xs:string*
{
    security:get-group-members($security:biblio-users-group)[. ne security:get-user-credential-from-session()[1]]
};

declare function security:get-group($collection as xs:string) as xs:string?
{
    if(xmldb:collection-available($collection))then
    (
        xmldb:get-group($collection)
    ) else()
};
:)

(:
declare function security:set-other-can-read-collection($collection, $read as xs:boolean) as xs:boolean
{
    let $permissions := xmldb:permissions-to-string(xmldb:get-permissions($collection)) return
        let $new-permissions := if($read)then(
            fn:replace($permissions, "(......)(.)(..)", "$1r$3")
        ) else (
           fn:replace($permissions, "(......)(.)(..)", "$1-$3")
        )
        return
            xmldb:set-collection-permissions($collection, xmldb:get-owner($collection), xmldb:get-group($collection), xmldb:string-to-permissions($new-permissions)),
            
            true()
};

declare function security:set-other-can-write-collection($collection, $write as xs:boolean) as xs:boolean
{
    let $permissions := xmldb:permissions-to-string(xmldb:get-permissions($collection)) return
        let $new-permissions := if($write)then(
            fn:replace($permissions, "(.......)(.)(.)", "$1w$3")
        ) else (
           fn:replace($permissions, "(.......)(.)(.)", "$1-$3")
        )
        return        
            xmldb:set-collection-permissions($collection, xmldb:get-owner($collection), xmldb:get-group($collection), xmldb:string-to-permissions($new-permissions)),
            
            true()
};

declare function security:set-group-can-read-collection($collection, $read as xs:boolean) as xs:boolean
{
    security:set-group-can-read-collection($collection, xmldb:get-group($collection), $read)
};

declare function security:set-group-can-write-collection($collection, $write as xs:boolean) as xs:boolean
{
    security:set-group-can-write-collection($collection, xmldb:get-group($collection), $write)
};

declare function security:set-group-can-read-collection($collection, $group as xs:string, $read as xs:boolean) as xs:boolean
{
    let $permissions := xmldb:permissions-to-string(xmldb:get-permissions($collection)) return
        let $new-permissions := if($read)then(
            fn:replace($permissions, "(...)(.)(.....)", "$1r$3")
        ) else (
           fn:replace($permissions, "(...)(.)(.....)", "$1-$3")
        )
        return
            xmldb:set-collection-permissions($collection, xmldb:get-owner($collection), $group, xmldb:string-to-permissions($new-permissions)),
            true()
};

declare function security:set-group-can-write-collection($collection, $group as xs:string, $write as xs:boolean) as xs:boolean
{
    let $permissions := xmldb:permissions-to-string(xmldb:get-permissions($collection)) return
        let $new-permissions := if($write)then(
            fn:replace($permissions, "(....)(.)(....)", "$1w$3")
        ) else (
           fn:replace($permissions, "(....)(.)(....)", "$1-$3")
        )
        return
            xmldb:set-collection-permissions($collection, xmldb:get-owner($collection), $group, xmldb:string-to-permissions($new-permissions)),
            true()
};
:)

(:~
: Creates a security group
:
: Note - The currently logged in user will be the group owner
:)
(:
declare function security:create-group($group-name as xs:string, $group-members as xs:string*) as xs:boolean
{       
    (: create the group, currently logged in user will be the groups manager :)
    if(xmldb:create-group($group-name, security:get-user-credential-from-session()[1]))then
    (
        (: add members to group :)
        let $add-results :=
            for $group-member in $group-members            
            let $group-member-username := if($config:force-lower-case-usernames)then(fn:lower-case($group-member))else($group-member) return
                xmldb:add-user-to-group($group-member-username, $group-name)
        return
            fn:not(fn:contains($add-results, false()))
    )
    else
    (
        false()
    )
};
:)

(:
declare function security:add-user-to-group($username as xs:string, $group-name as xs:string) as xs:boolean
{
    xmldb:add-user-to-group($username, $group-name)
};

declare function security:remove-user-from-group($username as xs:string, $group-name as xs:string) as xs:boolean
{
    xmldb:remove-user-from-group($username, $group-name)
};
:)

(:
declare function security:set-group-can-read-resource($group-name as xs:string, $resource as xs:string, $read as xs:boolean) as xs:boolean
{
    let $collection-uri := fn:replace($resource, "(.*)/.*", "$1"),
    $resource-uri := fn:replace($resource, ".*/", ""),
    $permissions := xmldb:permissions-to-string(xmldb:get-permissions($collection-uri, $resource-uri)) return
        let $new-permissions := if($read)then(
            fn:replace($permissions, "(...)(.)(.....)", "$1r$3")
        ) else (
           fn:replace($permissions, "(...)(.)(.....)", "$1-$3")
        )
        return
            xmldb:set-resource-permissions($collection-uri, $resource-uri, xmldb:get-owner($collection-uri, $resource-uri), $group-name, xmldb:string-to-permissions($new-permissions)),
            
            true()
};
:)
declare function security:set-resource-permissions($resource as xs:string, $owner as xs:string, $group as xs:string, $owner-read as xs:boolean, $owner-write as xs:boolean, $group-read as xs:boolean, $group-write as xs:boolean, $other-read as xs:boolean, $other-write as xs:boolean) as empty() {
    
    let $owner-username := if($config:force-lower-case-usernames)then(fn:lower-case($owner))else($owner) return
        let $permissions := fn:concat(
            if($owner-read)then("r")else("-"),
            if($owner-write)then("w")else("-"),
            if($owner-write)then("u")else("-"),
            
            if($group-read)then("r")else("-"),
            if($group-write)then("w")else("-"),
            if($group-write)then("u")else("-"),
            
            if($other-read)then("r")else("-"),
            if($other-write)then("w")else("-"),
            if($other-write)then("u")else("-")
        ) return
            let $collection-uri := fn:replace($resource, "(.*)/.*", "$1"),
            $resource-uri := fn:replace($resource, ".*/", "") return
                xmldb:set-resource-permissions($collection-uri, $resource-uri, $owner-username, $group, xmldb:string-to-permissions($permissions))
};

(:
declare function security:get-groups($user as xs:string) as xs:string*
{
    (: TODO if you remove this line, then for some reason you get an error -
    XPTY0004: The actual cardinality for parameter 1 does not match the cardinality declared in the function's signature: xmldb:get-user-groups($user-id as xs:string) xs:string+. Expected cardinality: exactly one, got 2.
    :)
    let $null := util:log("debug", fn:concat("USER=========", $user)) return
    
    let $username := if($config:force-lower-case-usernames)then(fn:lower-case($user))else($user) return
        xmldb:get-user-groups($username)
};
:)

(:
declare function security:find-collections-with-group($collection-path as xs:string, $group as xs:string) as xs:string*
{
	for $child-collection in xmldb:get-child-collections($collection-path)
	let $child-collection-path := fn:concat($collection-path, "/", $child-collection) return
		(
			if(xmldb:get-group($child-collection-path) eq $group)then(
				$child-collection-path
			)else(),
			security:find-collections-with-group($child-collection-path, $group)
		)
};
:)

declare function security:set-ace-writeable($resource as xs:anyURI, $id as xs:int, $is-writeable as xs:boolean) as xs:boolean {
    let $permissions := sm:get-permissions($resource),
        $ace := $permissions/sm:permission/sm:acl/sm:ace[xs:int(@index) eq $id] return
            if(empty($ace))then
                false()
            else (
                
                (: TODO - write implies update until update is replaced with execute :)
                let $regexp-replacement := if($is-writeable)then
                    "wx"    
                else
                    "--"
                ,
                $new-mode := fn:replace($ace/@mode, "(.)..", fn:concat("$1", $regexp-replacement)),
                $null := sm:modify-ace($resource, $id, $ace/@access_type eq 'ALLOWED', $new-mode) return
                    true()
            
                (:
                let $regexp-replacement := if($is-writeable)then
                    "w"    
                else
                    "-"
                ,
                $new-mode := fn:replace($ace/@mode, "(.).(.)", fn:concat("$1", $regexp-replacement, "$2")),
                $null := sm:modify-ace($resource, $id, $ace/@access_type eq 'ALLOWED', $new-mode) return
                    true()
                :)
            )
};

(:~
: @return a sequence if the removal succeeded, otherwise the empty sequence
:   The sequence contains USER or GROUP as the first item, and then the who as the second item
:)
declare function security:remove-ace($resource as xs:anyURI, $id as xs:int) as xs:string* {
    
    let $permissions := sm:get-permissions($resource),
    $ace := $permissions/sm:permission/sm:acl/sm:ace[xs:int(@index) eq $id] return
        if(empty($ace))then(
            ()
        ) else (
            let $null := sm:remove-ace($resource, $id) return
                ($ace/@target, $ace/@who)
        )
};

(: adds a group ace and returns its index:)
declare function security:add-group-ace($resource as xs:anyURI, $groupname as xs:string, $mode as xs:string) as xs:int? {
    sm:add-group-ace($resource, $groupname, true(), $mode),
    
    xs:int(sm:get-permissions($resource)/sm:permission/sm:acl/@entries) - 1 
};

declare function security:insert-group-ace($resource as xs:anyURI, $id as xs:int, $groupname as xs:string, $mode as xs:string) as xs:boolean {
    
    (: if the ace index is one past the end of the acl, then we actually want an append :)
    if($id eq xs:int(sm:get-permissions($resource)/sm:permission/sm:acl/@entries))then
        fn:not(fn:empty(security:add-group-ace($resource, $groupname, $mode)))
    else(
        sm:insert-group-ace($resource, $id, $groupname, true(), $mode)
        ,
        true()
    )
};

(: adds a user ace and returns its index:)
declare function security:add-user-ace($resource as xs:anyURI, $username as xs:string, $mode as xs:string) as xs:int? {
    sm:add-user-ace($resource, $username, true(), $mode),
    
    xs:int(sm:get-permissions($resource)/sm:permission/sm:acl/@entries) - 1 
};

declare function security:insert-user-ace($resource as xs:anyURI, $id as xs:int, $username as xs:string, $mode as xs:string) as xs:boolean {
    
    (: if the ace index is one past the end of the acl, then we actually want an append:)
    if($id eq xs:int(sm:get-permissions($resource)/sm:permission/sm:acl/@entries))then
        fn:not(fn:empty(security:add-user-ace($resource, $username, $mode)))
    else(
        sm:insert-user-ace($resource, $id, $username, true(), $mode)
        ,
        true()
    )
};

(:~
: If the user creates a collection which is not inside their home
: collection, then the collection will be given full access by
: the owner of the parent collection
:)
declare function security:grant-parent-owner-access-if-foreign-collection($collection as xs:string) as empty() {
    
    let $collection-owner := sm:get-permissions($collection)/sm:permission/@owner,
    $parent-collection := fn:replace($collection, "(.*)/.*", "$1"),
    $parent-collection-owner := sm:get-permissions(xs:anyURI($parent-collection))/sm:permission/@owner return
    
        if(string($collection-owner) ne string($parent-collection-owner))then
            sm:add-user-ace(xs:anyURI($collection), $parent-collection-owner, true(), "rwx")
        else()
};

(: ~
: Resources always inherit the permissions of the parent Collection
:)
declare function security:apply-parent-collection-permissions($resource as xs:anyURI) as empty() {

    let $parent-permissions := sm:get-permissions(xs:anyURI(fn:replace($resource, "(.*)/.*", "$1"))),
    $this-permissions := sm:get-permissions($resource),
	$this-last-acl-index := xs:int($this-permissions/sm:permission/sm:acl/@entries) -1 return

        (
            for $ace in $parent-permissions/sm:permission/sm:acl/sm:ace return
             
				if($ace/@target eq "USER") then
                    sm:add-user-ace($resource, $ace/@who, $ace/@access_type eq "ALLOWED", $ace/@mode)
                else if($ace/@target eq "GROUP") then
                    sm:add-group-ace($resource, $ace/@who, $ace/@access_type eq "ALLOWED", $ace/@mode)
                else()
			,
            if($this-permissions/sm:permission/@owner ne $parent-permissions/sm:permission/@owner)then
                let $owner-mode := fn:replace($parent-permissions/sm:permission/@mode, "(...).*", "$1") return
                    sm:add-user-ace($resource, $parent-permissions/sm:permission/@owner, true(), $owner-mode)
            else()
    		,
            if($this-permissions/sm:permission/@group ne $parent-permissions/sm:permission/@group)then
                let $group-mode := fn:replace($parent-permissions/sm:permission/@mode, "...(...)...", "$1") return
                sm:add-group-ace($resource, $parent-permissions/sm:permission/@group, true(), $group-mode)
            else()
			,
			(: clear any prev entries :)
			for $i in 0 to $this-last-acl-index return
				sm:remove-ace($resource, $i)
        )
};

declare function security:is-biblio-user($username as xs:string) as xs:boolean {
    xmldb:get-user-groups($username) = $security:biblio-users-group
};
