$ErrorActionPreference = "Stop"

$DomainName = "lab.local"
$NetbiosName = "LAB"
$AdminUsername = "ITAdmin"
$AdminPassword = ConvertTo-SecureString "Password1234!" -AsPlainText -Force

$Credential = New-Object System.Management.Automation.PSCredential(
    "$NetbiosName\$AdminUsername",
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

Add-Computer `
    -DomainName $DomainName `
    -Credential $Credential `
    -OUPath "OU=Computers,DC=lab,DC=local" `
    -Restart `
    -Force