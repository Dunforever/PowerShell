#requires -module ActiveDirectory

#Reporting on deleted items requires the Active Directory Recycle Bin feature
[cmdletbinding()]
Param(
    [Parameter(Position = 0,HelpMessage = "Enter a last modified datetime for AD objects. The default is the last 8 hours.")]
    [ValidateNotNullOrEmpty()]
    [datetime]$Since = ((Get-Date).AddHours(-8)),
    [Parameter(HelpMessage = "What is the report title?")]
    [string]$ReportTitle = "Active Directory Change Report",
    [Parameter(HelpMessage = "Add a second grouping based on the object's container or OU.")]
    [switch]$ByContainer,
    [Parameter(HelpMessage = "Specify the path for the output file.")]
    [ValidateNotNullOrEmpty()]
    [string]$Path = ".\ADChangeReport.html",
    [Parameter(HelpMessage = "Specifies the Active Directory Domain Services domain controller to query. The default is your Logon server.")]
    [string]$Server = $env:LOGONSERVER.SubString(2),
    [Parameter(HelpMessage = "Specify an alternate credential for authentication.")]
    [pscredential]$Credential,
    [ValidateSet("Negotiate","Basic")]
    [string]$AuthType
)

#region helper functions

#a private helper function to convert the objects to html fragments
Function _convertObjects {
    Param([object[]]$Objects)
    #convert each table to an XML fragment so I can insert a class attribute
    [xml]$frag = $objects | Sort-Object -property WhenChanged |
    Select-Object -Property DistinguishedName,Name,WhenCreated,WhenChanged,IsDeleted |
    ConvertTo-Html -Fragment

    for ($i = 1; $i -lt $frag.table.tr.count;$i++) {
        if (($frag.table.tr[$i].td[2] -as [datetime]) -ge $since) {
            #highlight new objects in green
            $class = $frag.CreateAttribute("class")
            $class.value="new"
            [void]$frag.table.tr[$i].Attributes.append($class)
        } #if new

        #insert the alert attribute if the object has been deleted.
        if ($frag.table.tr[$i].td[-1] -eq 'True') {
            #highlight deleted objects in red
            $class = $frag.CreateAttribute("class")
            $class.value="alert"
            [void]$frag.table.tr[$i].Attributes.append($class)
        } #if deleted
    } #for

    #write the innerXML (ie HTML code) as the function output
    $frag.InnerXml
}

# private helper function to insert javascript code into my html
function _insertToggle {
    [cmdletbinding()]
    #The text to display, the name of the div, the data to collapse, and the heading style
    #the div Id needs to be simple text
    Param([string]$Text, [string]$div, [object[]]$Data, [string]$Heading = "H2", [switch]$NoConvert)

    $out = [System.Collections.Generic.list[string]]::New()
    if (-Not $div) {
        $div = $Text.Replace(" ", "_")
    }
    $out.add("<a href='javascript:toggleDiv(""$div"");' title='click to collapse or expand this section'><$Heading>$Text</$Heading></a><div id=""$div"">")
    if ($NoConvert) {
        $out.Add($Data)
    }
    else {
        $out.Add($($Data | ConvertTo-Html -Fragment))
    }
    $out.Add("</div>")
    $out
}

#endregion

#some report metadata
$reportVersion = "2.1.1"
$thisScript = Convert-Path $myinvocation.InvocationName

Write-Verbose "[$(Get-Date)] Starting $($myinvocation.MyCommand)"
Write-Verbose "[$(Get-Date)] Detected these bound parameters"
$PSBoundParameters | Out-String | Write-Verbose

#set some default parameter values
$params = "Credential","AuthType"
$script:PSDefaultParameterValues = @{"Get-AD*:Server" = $Server}
ForEach ($param in $params) {
    if ($PSBoundParameters.ContainsKey($param)) {
        Write-Verbose "[$(Get-Date)] Adding 'Get-AD*:$param' to script PSDefaultParameterValues"
        $script:PSDefaultParameterValues["Get-AD*:$param"] = $PSBoundParameters.Item($param)
    }
}

Write-Verbose "[$(Get-Date)] Getting current Active Directory domain"
$domain = Get-ADDomain

#create a list object to hold all of the HTML fragments
Write-Verbose "[$(Get-Date)] Initializing fragment list"
$fragments = [System.Collections.Generic.list[string]]::New()
$fragments.Add("<H2>$($domain.dnsroot)</H2>")
$fragments.Add("<a href='javascript:toggleAll();' title='Click to toggle all sections'>+/-</a>")

Write-Verbose "[$(Get-Date)] Querying $($domain.dnsroot)"
$filter = {(objectclass -eq 'user' -or objectclass -eq 'group' -or objectclass -eq 'organizationalunit' ) -AND (WhenChanged -gt $since )}

Write-Verbose "[$(Get-Date)] Filtering for changed objects since $since"
$items = Get-ADObject -filter $filter -IncludeDeletedObjects -Properties WhenCreated,WhenChanged,IsDeleted -OutVariable all | Group-Object -property objectclass

Write-Verbose "[$(Get-Date)] Found $($all.count) total items"

if ($items.count -gt 0) {
    foreach ($item in $items) {
        $category = "{0}{1}" -f $item.name[0].ToString().toUpper(),$item.name.Substring(1)
        Write-Verbose "[$(Get-Date)] Processing $category [$($item.count)]"

        if ($ByContainer) {
            Write-Verbose "[$(Get-Date)] Organizing by container"
            $subgroup = $item.group | Group-Object -Property { $_.distinguishedname.split(',', 2)[1] } | Sort-Object -Property Name
            $fraghtml = [System.Collections.Generic.list[string]]::new()
            foreach ($subitem in $subgroup) {
                Write-Verbose "[$(Get-Date)] $($subItem.name)"
                $fragGroup = _convertObjects $subitem.group
                $divid = $subitem.name -replace "=|,",""
                $fraghtml.Add($(_inserttoggle -Text "$($subItem.name) [$($subitem.count)]" -div $divid -Heading "H4" -Data $fragGroup -NoConvert))
            } #foreach subitem
        } #if by container
        else {
            $fragHtml = _convertObjects $item.group
        }
         $code = _insertToggle -Text "$category [$($item.count)]" -div $category -Heading "H3" -Data $fragHtml -NoConvert
        $fragments.Add($code)
    } #foreach item

#my embedded CSS
    $head = @"
<Title>$ReportTitle</Title>
<style>
h2 {
    width:95%;
    background-color:#7BA7C7;
    font-family:Tahoma;
    font-size:12pt;
}
h4 {
    width:95%;
    background-color:#b5f144;
}
body {
    background-color:#FFFFFF;
    font-family:Tahoma;
    font-size:12pt;
}
td, th {
    border:1px solid black;
    border-collapse:collapse;
}
th {
    color:white;
    background-color:black;
}
table, tr, td, th {
    padding-left: 10px;
    margin: 0px
}
tr:nth-child(odd) {background-color: lightgray}
table {
    width:95%;
    margin-left:5px;
    margin-bottom:20px;
}
.alert { color:red; }
.new { color:green; }
.footer { font-size:10pt; }
.footer tr:nth-child(odd) {background-color: white}
.footer td,tr {
    border-collapse:collapse;
    border:none;
}
.footer table {width:15%;}
td.size {
    text-align: right;
    padding-right: 25px;
}
</style>
<script type='text/javascript' src='https://ajax.googleapis.com/ajax/libs/jquery/1.4.4/jquery.min.js'>
</script>
<script type='text/javascript'>
function toggleDiv(divId) {
`$("#"+divId).toggle();
}
function toggleAll() {
var divs = document.getElementsByTagName('div');
for (var i = 0; i < divs.length; i++) {
var div = divs[i];
`$("#"+div.id).toggle();
}
}
</script>
<H1>$ReportTitle</H1>
"@

#a footer for the report. This could be styled with CSS
    $post = @"
<table class='footer'>
    <tr align = "right"><td>Report run: <i>$(Get-Date)</i></td></tr>
    <tr align = "right"><td>Report version: <i>$ReportVersion</i></td></tr>
    <tr align = "right"><td>Source: <i>$thisScript</i></td></tr>
</table>
"@

    $htmlParams = @{
        Head = $head
        precontent = "Active Directory changes since $since. Reported from $($Server.toUpper()). Replication only changes may be included."
        Body =($fragments | Out-String)
        PostContent = $post
    }
    Write-Verbose "[$(Get-Date)] Creating report $ReportTitle version $reportversion saved to $path"
    ConvertTo-HTML @htmlParams | Out-File -FilePath $Path
    Get-Item -Path $Path
}
else {
    Write-Warning "No modified objects found in the $($domain.dnsroot) domain since $since."
}

Write-Verbose "[$(Get-Date)] Ending $($myinvocation.MyCommand)"