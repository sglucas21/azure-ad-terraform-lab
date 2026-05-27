$ErrorActionPreference = "Stop"

$DomainName = "lab.local"
$NetbiosName = "LAB"
$DSRMPasswordPlain = "UseAnotherStrongPassword@2026!"
$PostConfigScriptB64 = "${post_config_script_b64}"

New-Item -Path "C:\ADLab" -ItemType Directory -Force | Out-Null

[System.Text.Encoding]::UTF8.GetString(
    [System.Convert]::FromBase64String($PostConfigScriptB64)
) | Out-File -FilePath "C:\ADLab\02-post-reboot-ad-config.ps1" -Encoding UTF8 -Force

$stage2 = @"
`$ErrorActionPreference = "Stop"

Start-Sleep -Seconds 120

Import-Module ADDSDeployment

`$DSRMPassword = ConvertTo-SecureString "$DSRMPasswordPlain" -AsPlainText -Force

Install-ADDSForest ``
    -DomainName "$DomainName" ``
    -DomainNetbiosName "$NetbiosName" ``
    -InstallDns:`$true ``
    -SafeModeAdministratorPassword `$DSRMPassword ``
    -NoRebootOnCompletion:`$true ``
    -Force:`$true

`$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File C:\ADLab\02-post-reboot-ad-config.ps1"
`$Trigger = New-ScheduledTaskTrigger -AtStartup

Register-ScheduledTask ``
    -TaskName "ADLab-PostRebootConfig" ``
    -Action `$Action ``
    -Trigger `$Trigger ``
    -User "SYSTEM" ``
    -RunLevel Highest ``
    -Force

Unregister-ScheduledTask -TaskName "ADLab-PromoteDC" -Confirm:`$false

shutdown.exe /r /t 60 /f /c "Restarting after Domain Controller promotion."
"@

$stage2 | Out-File -FilePath "C:\ADLab\01b-promote-after-reboot.ps1" -Encoding UTF8 -Force

Install-WindowsFeature AD-Domain-Services,GPMC -IncludeManagementTools

$Action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File C:\ADLab\01b-promote-after-reboot.ps1"

$Trigger = New-ScheduledTaskTrigger -AtStartup

Register-ScheduledTask `
    -TaskName "ADLab-PromoteDC" `
    -Action $Action `
    -Trigger $Trigger `
    -User "SYSTEM" `
    -RunLevel Highest `
    -Force

shutdown.exe /r /t 60 /f /c "Restarting after AD DS role installation."