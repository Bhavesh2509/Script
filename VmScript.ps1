$ErrorActionPreference = "Stop"

Write-Host "Starting deployment..."

# =======================================
# CONFIG
# =======================================

$InnerVMName   = "InnerVM"
$InnerUsername = "Administrator"
$InnerPassword = "YourPasswordHere"   # CHANGE
$OuterSavePath = "C:\OuterTemp"

# =======================================
# ENSURE OUTER FOLDER
# =======================================

if (!(Test-Path $OuterSavePath)) {
    New-Item -ItemType Directory -Path $OuterSavePath | Out-Null
}

# =======================================
# CREATE REAL WORK SCRIPT
# =======================================

$NestedScriptPath = "C:\NestedExecution.ps1"

@"
Import-Module Hyper-V

`$SecurePass = ConvertTo-SecureString "$InnerPassword" -AsPlainText -Force
`$Cred = New-Object System.Management.Automation.PSCredential ("$InnerUsername", `$SecurePass)

# Validate VM
`$VM = Get-VM -Name "$InnerVMName"

if (`$VM.State -ne "Running") {
    Start-VM -Name "$InnerVMName"
    Start-Sleep -Seconds 20
}

# PowerShell Direct Session
`$Session = New-PSSession -VMName "$InnerVMName" -Credential `$Cred

Invoke-Command -Session `$Session -ScriptBlock {

    if (!(Test-Path "C:\Temp")) {
        New-Item -ItemType Directory -Path "C:\Temp"
    }

    Get-Process | Out-File "C:\Temp\InnerProcess.txt" -Force

    if (!(Get-SmbShare -Name "InnerShare" -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name "InnerShare" -Path "C:\Temp" -FullAccess "Everyone"
    }

}

Remove-PSSession `$Session

# Copy file to outer VM
`$InnerIP = Invoke-Command -VMName "$InnerVMName" -Credential `$Cred -ScriptBlock {
    (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {`$_.IPAddress -notmatch '^169\.254'} |
        Select-Object -First 1 -ExpandProperty IPAddress)
}

`$SharePath = "\\`$InnerIP\InnerShare"

if (Get-PSDrive -Name Z -ErrorAction SilentlyContinue) {
    Remove-PSDrive -Name Z -Force
}

New-PSDrive -Name Z -PSProvider FileSystem -Root `$SharePath -Credential `$Cred

Copy-Item "Z:\InnerProcess.txt" "$OuterSavePath\CopiedFromInner.txt" -Force

Remove-PSDrive -Name Z -Force
"@ | Out-File -FilePath $NestedScriptPath -Force

# =======================================
# CREATE SCHEDULED TASK TO RUN SCRIPT
# =======================================

$Action  = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File $NestedScriptPath"
$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
$Principal = New-ScheduledTaskPrincipal -UserId "Administrator" -LogonType Password -RunLevel Highest

Register-ScheduledTask -TaskName "NestedVMTask" `
                        -Action $Action `
                        -Trigger $Trigger `
                        -User "Administrator" `
                        -Password "$InnerPassword" `
                        -RunLevel Highest `
                        -Force

Write-Host "Scheduled task created. Nested execution will run in 1 minute."

exit 0
