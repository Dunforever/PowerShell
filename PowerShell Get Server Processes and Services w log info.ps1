$computers = Read-Host "Enter ComputerName to Get Processes, Services stopped, and Sys and App log info"
function get-CPUUSAGE {
    param(
        [int] $threshold = 20
    )
 
    $ErrorActionPreference = "SilentlyContinue"
    if( !(Test-Connection -Destination $computersname -Count 1) ){
        "Could not connect to :: $computersname"
        return
    }
     $processes = Get-WmiObject -ComputerName $computersname `
    -Class Win32_PerfFormattedData_PerfProc_Process `
    -Property Name, PercentProcessorTime
 
    $return= @()
 
    # Build up a return list
    foreach( $process in $processes ){
        if( $process.PercentProcessorTime -ge $threshold `
        -and $process.Name -ne "Idle" `
        -and $process.Name -ne "_Total"){
            $item = "" | Select Name, CPU
            $item.Name = $process.Name
            $item.CPU = $process.PercentProcessorTime
            $return += $item
            $item = $null
        }
    }
 
    $return = $return | Sort-Object -Property CPU -Descending
    return $return
}
$cpuuage=get-CPUUSAGE 
foreach ($computersname in $computers) { 
   if (Test-Connection $computersname -erroraction silentlyContinue  ) {
     $computersname.ToUpper()
     $label="$computersname Status:	"
	 $label = $label.ToUpper()
     $labelup="UP";
     $label+$labelup 
     Get-WmiObject win32_processor -ComputerName $computersname | select LoadPercentage  |fl
     if (!$cpuuage)
     {"No processes currently running above 10% CPU usage"}
     else {$cpuuage}
$fields = "Name",@{label = "Memory (MB)"; Expression = {$_.ws / 1mb}; Align = "Right"}
$processlist=get-process -ComputerName $computersname 
$processlist | Sort-Object -Descending WS | format-table $fields | Out-String
$freemem = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $computersname
"System Name     : {0}" -f $freemem.csname
"Free Memory (MB): {0}" -f ([math]::round($freemem.FreePhysicalMemory / 1024, 2))
"Free Memory (GB): {0}" -f ([math]::round(($freemem.FreePhysicalMemory / 1024 / 1024), 2))
Get-WmiObject Win32_Service -ComputerName $computersname |
Where-Object { $_.StartMode -eq 'Auto' -and $_.State -ne 'Running' } |
Format-Table -AutoSize @(
    'Name'
    'DisplayName'
    @{ Expression = 'State'; Width = 9 }
    @{ Expression = 'StartMode'; Width = 9 }
    'StartName'
) | Out-String -Width 300
    #$today=$Date.ToShortDateString()
    $appevent=get-eventlog -log "Application" -entrytype Error -ComputerName $computersname
    If(!$appevent)
            {
            }
    else    {
                
                $appevent | Format-Table -AutoSize -Wrap | Out-String -Width 300 | FT
                
            }
        $sysevent=get-eventlog -log "System" -entrytype Error -ComputerName $computersname
        If(!$sysevent)
            {
            }
    else    {
         $sysevent | Format-Table -AutoSize -Wrap | Out-String -Width 300 | FT
             
            }
   }
   else {
     $computersname
     $label="$computersname Status:";
     $labeldown="DOWN";
     $label+$labeldown
   }
 } $computersname | Export-Csv C:\temp\perf.csv -NoTypeInformation