# =========================
# CONFIGURATION
# =========================

$InnerVMName = "InnerVM"
$InnerUsername = "Administrator"
$InnerPassword = "YourPasswordHere"   # change this
$OuterSavePath = "C:\OuterTemp"

# Convert password
$SecurePass = ConvertTo-SecureString $InnerPassword -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential ($InnerUsername, $SecurePass)

# Ensure outer folder exists
if (!(Test-Path $OuterSavePath)) {
    New-Item -ItemType Directory -Path $OuterSavePath
}

# =========================
# STEP 1 - Run inside Inner VM
# =========================

Invoke-Command -VMName $InnerVMName -Credential $Cred -ScriptBlock {

    # Create Temp folder if missing
    if (!(Test-Path "C:\Temp")) {
        New-Item -ItemType Directory -Path "C:\Temp"
    }

    # Save process list
    Get-Process | Out-File "C:\Temp\InnerProcess.txt"

    # Create SMB Share
    if (!(Get-SmbShare -Name "InnerShare" -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name "InnerShare" -Path "C:\Temp" -FullAccess "Everyone"
    }

}

Write-Host "Process file created and shared inside Inner VM." -ForegroundColor Green

# =========================
# STEP 2 - Get Inner VM IP
# =========================

$InnerIP = (Invoke-Command -VMName $InnerVMName -Credential $Cred -ScriptBlock {
    (Get-NetIPAddress -AddressFamily IPv4 `
        | Where-Object {$_.IPAddress -notlike "169.*"} `
        | Select-Object -First 1).IPAddress
})

Write-Host "Inner VM IP is $InnerIP" -ForegroundColor Yellow

# =========================
# STEP 3 - Map & Copy To Outer
# =========================

$SharePath = "\\$InnerIP\InnerShare"
$DriveName = "Z"

# Remove drive if exists
if (Get-PSDrive -Name $DriveName -ErrorAction SilentlyContinue) {
    Remove-PSDrive -Name $DriveName -Force
}

# Map drive
New-PSDrive -Name $DriveName `
            -PSProvider FileSystem `
            -Root $SharePath `
            -Credential $Cred

# Copy file to Outer VM
Copy-Item "$DriveName:\InnerProcess.txt" "$OuterSavePath\CopiedFromInner.txt"

Write-Host "File copied to outer VM successfully." -ForegroundColor Cyan
