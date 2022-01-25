#load a list of computers
$computerList = Get-Content "C:\temp\servers.txt"

#results array
$results = @()

#for each computer
foreach($computerName in $computerList) {
    #add result of command to results array
    $results += Get-ADComputer $computerName -Properties Name, DistinguishedName | Select Name, DistinguishedName
}

#send results to CSV file
$results | Export-Csv "C:\TEMP\computerOUs.txt" -NoTypeInformation