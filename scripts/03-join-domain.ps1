$ErrorActionPreference = "Stop"

$DomainName = "lab.local"
$NetbiosName = "LAB"
$AdminUsername = "ITAdmin"
$AdminPassword = ConvertTo-SecureString "Password1234!" -AsPlainText -Force

Start-Sleep -Seconds 120

$Credential = New-Object System.Management.Automation.PSCredential(
    "$NetbiosName\$AdminUsername",
    $AdminPassword
)

for ($i = 1; $i -le 20; $i++) {
    try {
        Resolve-DnsName $DomainName -ErrorAction Stop | Out-Null
        break
    }
    catch {
        Start-Sleep -Seconds 30
    }
}

Add-Computer `
    -DomainName $DomainName `
    -Credential $Credential `
    -OUPath "OU=Computers,DC=lab,DC=local" `
    -Restart `
    -Force