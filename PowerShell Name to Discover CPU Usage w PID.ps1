Param(
    [Parameter(Mandatory=$false)][String]$ComputerName =  $a,
    [Parameter(Mandatory=$false)][Switch]$Loop
) 
function GetTotalCPU {
$a = Read-Host "Enter ServerName to Discover CPU Usage"
   $cpu = Get-Counter -ComputerName $ComputerName -Counter "\processor(_total)\% processor time"
   $cpu = [math]::Round($cpu.CounterSamples.CookedValue) 
   return $cpu
   }
function GetRawProcessData {
    $Procs = (Get-Counter -ComputerName $ComputerName -Counter "\process(*)\% processor time" -ErrorAction SilentlyContinue).CounterSamples | Where-Object { $_.CookedValue -ne 0}
    $idle = ($Procs | Where-Object {$_.InstanceName -eq "idle"}).CookedValue
    $total = ($Procs | Where-Object {$_.InstanceName -eq "_total"}).CookedValue
    $Procs | ForEach-Object {
        $_.CookedValue = [math]::Round($_.CookedValue/$total*100,1)
        $_.InstanceName = $_.Path.Substring($_.Path.indexof("(")+1)
        $_.InstanceName = $_.InstanceName.Substring(0,$_.InstanceName.indexof(")"))
    }
    return $Procs
}
function GetRefinedProcessData ($Procs) {
    $procsList = @()
    $idProcess = (Get-Counter -ComputerName $ComputerName -Counter "\process(*)\ID Process" -ErrorAction SilentlyContinue).CounterSamples
    foreach ($Proc in $Procs) {
        $procName = $Proc.InstanceName
        $procPID = $idProcess | ? {$_.Path -match $procName } | Select-Object CookedValue
        $procPID = $procPID.CookedValue
        $procCPU = $Proc.CookedValue
        if ($procName -ne "_total") {
            $procsList += New-Object PSObject -Property @{Name = $procName; PID = $procPID; CPU = $procCPU}
        }
    }
    return $procsList
}
do {
    $cpu = GetTotalCPU
    $Procs = GetRawProcessData
    $ProcsList = GetRefinedProcessData $Procs
    clear
    "{0} CPU: {1}%" -f $ComputerName, $cpu
    $ProcsList | Sort-Object CPU -Descending | FT Name, PID, @{Label="CPU"; Expression={"{0}%" -f $_.CPU}}
}
while ($Loop)