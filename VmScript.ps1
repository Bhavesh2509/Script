# ============================================
# STRICT MODE FOR CSE
# ============================================
$ErrorActionPreference = "Stop"

Write-Host "Starting Nested VM Process Sync Script..."

# ============================================
# ENSURE HYPER-V MODULE IS AVAILABLE
# ============================================

try {
    Import-Module Hyper-V -ErrorAction Stop
    Write-Host "Hyper-V module loaded successfully."
}
catch {
    throw "Hyper-V PowerShell module is not available. Ensure Hyper-V + Management Tools are installed."
}

# ============================================
# CONFIGURATION
# ============================================

$InnerVMName   = "InnerVM"
$InnerUsername = "Administrator"
$InnerPassword = "YourPasswordHere"   # CHANGE THIS
$OuterSavePath = "C:\OuterTemp"
$DriveName     = "Z"

# ============================================
# CREATE CREDENTIAL
# ============================================

$SecurePass = ConvertTo-SecureString $InnerPassword -AsPlainText -Force
$Cred       = New-Object System.Management.Automation.PSCredential ($InnerUsername, $SecurePass)

# ============================================
# VALIDATE INNER VM EXISTS & RUNNING
# ============================================

$VM = Get-VM -Name $InnerVMName -ErrorAction Stop

if ($VM.State -ne "Running") {
    throw "Inner VM is not running."
}

Write-Host "Inner VM is running."

# ============================================
# ENSURE OUTER DIRECTORY EXISTS
# ============================================

if (!(Test-Path $OuterSavePath)) {
    New-Item -ItemType Directory -Path $OuterSavePath | Out-Null
}

# ============================================
# STEP 1 - RUN INSIDE INNER VM
# ============================================

Invoke-Command -VMName $InnerVMName -Credential $Cred -ScriptBlock {

    $ErrorActionPreference = "Stop"

    if (!(Test-Path "C:\Temp")) {
        New-Item -ItemType Directory -Path "C:\Temp" | Out-Null
    }

    Get-Process | Out-File "C:\Temp\InnerProcess.txt" -Force

    if (!(Get-SmbShare -Name "InnerShare" -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name "InnerShare" -Path "C:\Temp" -FullAccess "Everyone"
    }

}

Write-Host "Process file created and shared inside Inner VM."

# ============================================
# STEP 2 - GET INNER VM IP
# ============================================

$InnerIP = Invoke-Command -VMName $InnerVMName -Credential $Cred -ScriptBlock {

    (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notmatch '^169\.254' -and
            $_.IPAddress -ne "127.0.0.1"
        } |
        Select-Object -First 1 -ExpandProperty IPAddress)

}

if (-not $InnerIP) {
    throw "Failed to retrieve Inner VM IP address."
}

Write-Host "Inner VM IP: $InnerIP"

# ============================================
# STEP 3 - MAP SHARE
# ============================================

$SharePath = "\\$InnerIP\InnerShare"

if (Get-PSDrive -Name $DriveName -ErrorAction SilentlyContinue) {
    Remove-PSDrive -Name $DriveName -Force
}

New-PSDrive -Name $DriveName `
            -PSProvider FileSystem `
            -Root $SharePath `
            -Credential $Cred `
            -ErrorAction Stop | Out-Null

Write-Host "Mapped share successfully."

# ============================================
# STEP 4 - COPY FILE TO OUTER VM
# ============================================

Copy-Item "${DriveName}:\InnerProcess.txt" `
          "$OuterSavePath\CopiedFromInner.txt" `
          -Force `
          -ErrorAction Stop

Write-Host "File copied successfully to Outer VM."

# ============================================
# CLEANUP
# ============================================

Remove-PSDrive -Name $DriveName -Force -ErrorAction SilentlyContinue

Write-Host "Script completed successfully."

exit 0
