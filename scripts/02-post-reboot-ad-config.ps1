$ErrorActionPreference = "Stop"

Start-Sleep -Seconds 180

Import-Module ActiveDirectory
Import-Module GroupPolicy

$DomainName = "lab.local"
$BaseDN = "DC=lab,DC=local"

for ($i = 1; $i -le 30; $i++) {
    try {
        Get-ADDomain -Identity $DomainName | Out-Null
        break
    }
    catch {
        Start-Sleep -Seconds 30
    }
}

$OUs = @("IT", "Finance", "HR", "Sales", "Workstations")

foreach ($OU in $OUs) {
    $OUPath = "OU=$OU,$BaseDN"

    try {
        Get-ADOrganizationalUnit -Identity $OUPath -ErrorAction Stop | Out-Null
        Write-Output "OU already exists: $OU"
    }
    catch {
        Write-Output "Creating OU: $OU"

        New-ADOrganizationalUnit `
            -Name $OU `
            -Path $BaseDN `
            -ProtectedFromAccidentalDeletion $false
    }
}

$Groups = @(
    @{ Name = "IT_Admins"; Path = "OU=IT,$BaseDN" },
    @{ Name = "Finance_Users"; Path = "OU=Finance,$BaseDN" },
    @{ Name = "HR_Users"; Path = "OU=HR,$BaseDN" },
    @{ Name = "Sales_Users"; Path = "OU=Sales,$BaseDN" }
)

foreach ($Group in $Groups) {
    if (-not (Get-ADGroup -Filter "Name -eq '$($Group.Name)'" -ErrorAction SilentlyContinue)) {
        New-ADGroup `
            -Name $Group.Name `
            -GroupScope Global `
            -GroupCategory Security `
            -Path $Group.Path
    }
}

$UserPassword = ConvertTo-SecureString "Welcome@2026!" -AsPlainText -Force

$Users = @(
    @{ Name = "steven.lucas"; GivenName = "Steven"; Surname = "Lucas"; OU = "IT"; Group = "IT_Admins" },
    @{ Name = "sarah.johnson"; GivenName = "Sarah"; Surname = "Johnson"; OU = "Finance"; Group = "Finance_Users" },
    @{ Name = "michael.lee"; GivenName = "Michael"; Surname = "Lee"; OU = "HR"; Group = "HR_Users" },
    @{ Name = "jessica.brown"; GivenName = "Jessica"; Surname = "Brown"; OU = "Sales"; Group = "Sales_Users" }
)

foreach ($User in $Users) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($User.Name)'" -ErrorAction SilentlyContinue)) {
        New-ADUser `
            -Name $User.Name `
            -GivenName $User.GivenName `
            -Surname $User.Surname `
            -SamAccountName $User.Name `
            -UserPrincipalName "$($User.Name)@$DomainName" `
            -Path "OU=$($User.OU),$BaseDN" `
            -AccountPassword $UserPassword `
            -Enabled $true `
            -ChangePasswordAtLogon $false
    }

    Add-ADGroupMember -Identity $User.Group -Members $User.Name -ErrorAction SilentlyContinue
}

Set-ADDefaultDomainPasswordPolicy `
    -Identity $DomainName `
    -MinPasswordLength 12 `
    -ComplexityEnabled $true

if (-not (Get-GPO -Name "IT Security Policy" -ErrorAction SilentlyContinue)) {
    New-GPO -Name "IT Security Policy" | Out-Null
}

New-GPLink `
    -Name "IT Security Policy" `
    -Target "OU=IT,$BaseDN" `
    -LinkEnabled Yes `
    -ErrorAction SilentlyContinue

Set-GPRegistryValue `
    -Name "IT Security Policy" `
    -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
    -ValueName "InactivityTimeoutSecs" `
    -Type DWord `
    -Value 900

Set-GPRegistryValue `
    -Name "IT Security Policy" `
    -Key "HKLM\Software\Policies\Microsoft\Windows\RemovableStorageDevices" `
    -ValueName "Deny_All" `
    -Type DWord `
    -Value 1

Unregister-ScheduledTask -TaskName "ADLab-PostRebootConfig" -Confirm:$false