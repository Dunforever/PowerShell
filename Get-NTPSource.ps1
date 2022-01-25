Param(
    [Parameter(Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        Position=0)]
    [Alias('Name')]
    [string[]]$Computername
)

Process
{
    foreach ($Computer in $Computername)
    {
        $ntps = w32tm /query /computer:$Computer /source
        new-object psobject -property @{
            Name = $Computer
            NTPSource = $ntps
        }
    }
}