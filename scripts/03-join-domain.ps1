$ErrorActionPreference = "Stop"

$DomainName = "lab.local"
$NetbiosName = "LAB"
$AdminUsername = "ITAdmin"
$AdminPassword = ConvertTo-SecureString "Password1234!" -AsPlainText -Force

$Credential = New-Object System.Management.Automation.PSCredential(
    "$AdminUsername@$DomainName",
    $AdminPassword
)

Write-Output "Waiting for domain DNS records..."

$MaxAttempts = 60
$DelaySeconds = 30

for ($i = 1; $i -le $MaxAttempts; $i++) {
    try {
        Resolve-DnsName $DomainName -ErrorAction Stop | Out-Null

        Resolve-DnsName "_ldap._tcp.dc._msdcs.$DomainName" -Type SRV -ErrorAction Stop | Out-Null

        Write-Output "Domain DNS and SRV records found. Continuing with domain join."
        break
    }
    catch {
      Write-Output "Attempt $($i) of $($MaxAttempts): Domain not ready yet. Waiting $($DelaySeconds) seconds..."
    Start-Sleep -Seconds $DelaySeconds
    }

    if ($i -eq $MaxAttempts) {
        throw "Domain DNS/SRV records were not ready after waiting."
    }
}

Write-Output "Testing secure channel prerequisites..."

Resolve-DnsName $DomainName -ErrorAction Stop
Resolve-DnsName "_ldap._tcp.dc._msdcs.$DomainName" -Type SRV -ErrorAction Stop
Test-NetConnection -ComputerName "ad-dc-01.lab.local" -Port 389
Test-NetConnection -ComputerName "ad-dc-01.lab.local" -Port 445

$CurrentDomain = (Get-CimInstance Win32_ComputerSystem).Domain

if ($CurrentDomain -ieq $DomainName) {
    Write-Output "Computer is already joined to $DomainName. Skipping domain join."
    exit 0
}


Add-Computer `
    -DomainName $DomainName `
    -Credential $Credential `
    -Restart `
    -Force