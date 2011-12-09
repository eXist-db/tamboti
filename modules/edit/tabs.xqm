xquery version "1.0";

module namespace mods = "http://www.loc.gov/mods/v3";

import module namespace config="http://exist-db.org/mods/config" at "../config.xqm";

declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace xforms="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events";

declare variable $mods:tabs-file := concat($config:edit-app-root, '/tab-data.xml');

(: Display the tabs in a div using triggers that hide or show sub-tabs and tabs. :)
declare function mods:tabs($tab-id as xs:string, $record-id as xs:string, $data-collection as xs:string) as node()  {

(: get the type param from the URL. :)
let $type := request:get-parameter("type", '')

(: get the top-tab-number param from the URL; if it is empty, it is because the record has just been initialised; 
if it is a non-basic template, set it to 2 (to show Citation Forms/Title Information), 
otherwise set it to 1 (to show Basic Input Forms/Main Publication). :)
let $top-tab-number := xs:integer(request:get-parameter("top-tab-number", 
    if ($type = ('insert-templates','new-instance'))
    then 2
    else
        if ($type = 'mads')
        then 5
        else 1
    ))

(: get the sequence of tabs from the tabs file :)
let $tabs-data := doc($mods:tabs-file)/tabs/tab

return
<div class="tabs">
    <table class="top-tabs" width="100%">
        <tr>
            {
            for $top-tab-label in distinct-values($tabs-data/top-tab-label)
            return
            <td style="{
                if ($tabs-data[top-tab-label = $top-tab-label]/top-tab-number = $top-tab-number) 
                then "background:white;border-bottom-color:white;" 
                else "background:#EDEDED"
            }">
            {attribute{'width'}{25}}
                <xf:trigger appearance="minimal">
                    <xf:label>
                        <div class="label" style="{
                            if ($tabs-data[top-tab-label = $top-tab-label]/top-tab-number = $top-tab-number) 
                            then "font-weight:bold;color:#3681B3;" 
                            else "font-weight:bold;color:darkgray"
                        }">
                    <span class="tab-text">{$top-tab-label}</span>
                    </div>
                    </xf:label>
                    <xf:action ev:event="DOMActivate">
                        <!--When clicking on the top tabs, save the record. -->
                        <xf:send submission="save-submission"/>
                        <!--When clicking on a top tab, select the first of the bottom tabs that belongs to it. -->
                        <xf:load resource="edit.xq?tab-id={$tabs-data[top-tab-label = $top-tab-label][1]/tab-id[1]}&amp;id={$record-id}&amp;top-tab-number={$tabs-data[top-tab-label = $top-tab-label][1]/top-tab-number[1]}&amp;type={$type}&amp;collection={$data-collection}" show="replace"/>
                    </xf:action>
                </xf:trigger>                
            </td>
            }
            </tr>
            </table>
            <table class="bottom-tabs">                    
                <tr>
                {
                for $tab in $tabs-data[top-tab-number = $top-tab-number]
                let $tab-for-type := $tab/*[local-name() = $type]/text()
				let $top-tab-count := count($tabs-data[top-tab-label/text() = $tab/top-tab-label/text()])
                return
                <td style="{
                    if ($tab-id = $tab/tab-id/text()) 
                    then "background:white;border-bottom-color:white;color:#3681B3;" 
                    else "background:#EDEDED"}
                    ">
                    {attribute{'width'}
                    {100 div $top-tab-count}}
                    <xf:trigger appearance="minimal">
                        <xf:label>
                            <div class="label" style="{
                                if ($tab-id = $tab/tab-id/text()) 
                                then "color:#3681B3;font-weight:bold;" 
                                else "color:darkgray;font-weight:bold"
                            }">{
                        if ($tab-for-type) 
                        then $tab-for-type 
                        else $tab/label
                        }</div>
                        </xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:send submission="save-submission"/>
                            <!--When clicking on the bottom tabs, keep the top-tab-number the same. -->
                            <xf:load resource="edit.xq?tab-id={$tab/tab-id/text()}&amp;id={$record-id}&amp;top-tab-number={$top-tab-number}&amp;type={$type}&amp;collection={$data-collection}" show="replace"/>
                        </xf:action>
                    </xf:trigger>
                </td>
                }
                </tr>
            </table>
</div>
};