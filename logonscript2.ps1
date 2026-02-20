$ErrorActionPreference = "Stop"
Write-Output "Starting configuration..."

# ========================
# Install Chrome (MSI)
# ========================
try {
    Write-Output "Installing Chrome..."
    $chromeInstaller = "$env:TEMP\chrome.msi"

    Invoke-WebRequest `
        -Uri "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi" `
        -OutFile $chromeInstaller

    Start-Process msiexec.exe `
        -ArgumentList "/i `"$chromeInstaller`" /qn /norestart" `
        -Wait

    Remove-Item $chromeInstaller -Force
}
catch {
    Write-Output "Chrome install failed: $($_.Exception.Message)"
}

# ========================
# Install IIS (Server vs Client safe)
# ========================
try {
    Write-Output "Installing IIS..."
    
    if (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue) {
        Install-WindowsFeature -Name Web-Server -IncludeManagementTools
    }
    else {
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart
    }
}
catch {
    Write-Output "IIS failed: $($_.Exception.Message)"
}

# ========================
# Add Custom HTML
# ========================
try {
    Write-Output "Adding IIS page..."
    
    $sitePath = "C:\inetpub\wwwroot\index.html"
    $htmlContent = @"
<html>
<head><title>Welcome</title></head>
<body>
<h1>Hello from Azure VM!</h1>
<p>Deployed via Azure CSE.</p>
</body>
</html>
"@

    Set-Content -Path $sitePath -Value $htmlContent -Force
}
catch {
    Write-Output "HTML failed"
}

# ========================
# Install VS Code SYSTEM Version
# ========================
try {
    Write-Output "Installing VS Code..."
    
    $vsInstaller = "$env:TEMP\vscode.exe"
    $vsPath = "C:\Program Files\Microsoft VS Code\Code.exe"

    Invoke-WebRequest `
        -Uri "https://update.code.visualstudio.com/latest/win32-x64/stable" `
        -OutFile $vsInstaller

    Start-Process $vsInstaller `
        -ArgumentList "/VERYSILENT /NORESTART /MERGETASKS=!runcode" `
        -Wait

    Remove-Item $vsInstaller -Force

    if (Test-Path $vsPath) {
        Write-Output "Installing extensions..."
        & $vsPath --install-extension ms-python.python --force
        & $vsPath --install-extension ms-vscode.cpptools --force
    }
}
catch {
    Write-Output "VS Code failed: $($_.Exception.Message)"
}

Write-Output "Script completed successfully."
exit 0
