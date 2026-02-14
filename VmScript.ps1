# =========================
# STOP ON ERROR (IMPORTANT FOR CSE)
# =========================
$ErrorActionPreference = "Stop"

# =========================
# CONFIGURATION
# =========================

$InnerVMName = "InnerVM"
$InnerUsername = "Administrator"
$InnerPassword = "YourPasswordHere"    # CHANGE THIS
$OuterSavePath = "C:\OuterTemp"

# =========================
# CREDENTIAL SETUP
# =========================

$SecurePass = ConvertTo-SecureString $InnerPassword -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential ($InnerUsername, $SecurePass)

# =========================
# ENSURE OUTER FOLDER EXISTS
# =========================

if (!(Test-Path $OuterSavePath)) {
    New-Item -ItemType Directory -Path $OuterSavePath | Out-Null
}

# =========================
# STEP 1 - RUN INSIDE INNER VM
# =========================

Invoke-Command -VMName $InnerVMName -Credential $Cred -ScriptBlock {

    $ErrorActionPreference = "Stop"

    # Ensure temp folder
    if (!(Test-Path "C:\Temp")) {
        New-Item -ItemType Directory -Path "C:\Temp" | Out-Null
    }

    # Generate process file
    Get-Process | Out-File "C:\Temp\InnerProcess.txt" -Force

    # Create SMB Share if not exists
    if (!(Get-SmbShare -Name "InnerShare" -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name "InnerShare" -Path "C:\Temp" -FullAccess "Everyone"
    }

}

Write-Host "Process file created and shared inside Inner VM." -ForegroundColor Green

# =========================
# STEP 2 - GET INNER VM IP
# =========================

$InnerIP = Invoke-Command -VMName $InnerVMName -Credential $Cred -ScriptBlock {
    (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -notmatch '^169\.254' -and $_.IPAddress -ne "127.0.0.1" } |
        Select-Object -First 1 -ExpandProperty IPAddress)
}

if (-not $InnerIP) {
    throw "Unable to retrieve Inner VM IP address."
}

Write-Host "Inner VM IP: $InnerIP" -ForegroundColor Yellow

# =========================
# STEP 3 - MAP SHARE
# =========================

$SharePath = "\\$InnerIP\InnerShare"
$DriveName = "Z"

if (Get-PSDrive -Name $DriveName -ErrorAction SilentlyContinue) {
    Remove-PSDrive -Name $DriveName -Force
}

New-PSDrive -Name $DriveName `
            -PSProvider FileSystem `
            -Root $SharePath `
            -Credential $Cred `
            -ErrorAction Stop | Out-Null

# =========================
# STEP 4 - COPY FILE TO OUTER VM
# =========================

Copy-Item "${DriveName}:\InnerProcess.txt" `
          "$OuterSavePath\CopiedFromInner.txt" `
          -Force `
          -ErrorAction Stop

Write-Host "File copied successfully to Outer VM." -ForegroundColor Cyan

# =========================
# SUCCESS EXIT
# =========================
exit 0
