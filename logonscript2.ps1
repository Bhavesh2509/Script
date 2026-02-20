$ErrorActionPreference = "Stop"
Write-Output "Starting VM configuration..."

# ==============================
# INSTALL CHROME (Enterprise MSI)
# ==============================
try {
    Write-Output "Installing Chrome..."
    $chromeInstaller = "$env:TEMP\chrome.msi"

    Invoke-WebRequest `
        -Uri "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi" `
        -OutFile $chromeInstaller `
        -UseBasicParsing

    $process = Start-Process msiexec.exe `
        -ArgumentList "/i `"$chromeInstaller`" /qn /norestart" `
        -PassThru

    $process.WaitForExit(600000)

    if ($process.ExitCode -ne 0) {
        Write-Output "Chrome install failed with exit code $($process.ExitCode)"
    }
    else {
        Write-Output "Chrome installed successfully."
    }

    Remove-Item $chromeInstaller -Force
}
catch {
    Write-Output "Chrome installation error: $($_.Exception.Message)"
}

# ==============================
# INSTALL IIS
# ==============================
try {
    Write-Output "Installing IIS..."

    if (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue) {
        Install-WindowsFeature -Name Web-Server -IncludeManagementTools
    }
    else {
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart
    }

    Write-Output "IIS installed."
}
catch {
    Write-Output "IIS installation error: $($_.Exception.Message)"
}

# ==============================
# DEPLOY CUSTOM HTML
# ==============================
try {
    Write-Output "Deploying IIS page..."

    $sitePath = "C:\inetpub\wwwroot\index.html"

    $htmlContent = @"
<html>
<head><title>Azure VM</title></head>
<body>
<h1>Hello from Azure VM!</h1>
<p>Installed via Custom Script Extension.</p>
</body>
</html>
"@

    Set-Content -Path $sitePath -Value $htmlContent -Force

    Write-Output "Custom page deployed."
}
catch {
    Write-Output "HTML deployment error: $($_.Exception.Message)"
}

# ==============================
# INSTALL VS CODE (SYSTEM VERSION)
# ==============================
try {
    Write-Output "Installing VS Code..."

    $vsInstaller = "$env:TEMP\vscode.exe"
    $vsPath = "C:\Program Files\Microsoft VS Code\Code.exe"

    Invoke-WebRequest `
        -Uri "https://update.code.visualstudio.com/latest/win32-x64/stable" `
        -OutFile $vsInstaller `
        -UseBasicParsing

    $vsProcess = Start-Process $vsInstaller `
        -ArgumentList "/VERYSILENT /NORESTART /MERGETASKS=!runcode" `
        -PassThru

    $vsProcess.WaitForExit(600000)

    if ($vsProcess.ExitCode -ne 0) {
        Write-Output "VS Code installer failed with exit code $($vsProcess.ExitCode)"
    }
    else {
        Write-Output "VS Code installed successfully."
    }

    Remove-Item $vsInstaller -Force

    # Install Extensions
    if (Test-Path $vsPath) {
        Write-Output "Installing VS Code extensions..."
        & $vsPath --install-extension ms-python.python --force
        & $vsPath --install-extension ms-vscode.cpptools --force
        Write-Output "Extensions installed."
    }
}
catch {
    Write-Output "VS Code installation error: $($_.Exception.Message)"
}

Write-Output "Script completed successfully."
exit 0
