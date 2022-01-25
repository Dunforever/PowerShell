$a = Get-Content c:\temp\usernames.txt

Get-ADUser -Identity $a -Properties * | Export-csv c:\temp\UsernamesToFullNames.csv -NoType