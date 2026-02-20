# ==============================
# Output + Logging
# ==============================
$OutDir = "C:\CSE"
New-Item -Path $OutDir -ItemType Directory -Force | Out-Null
Start-Transcript -Path "$OutDir\install.log" -Force

Write-Output "===== Script Started ====="

# ==============================
# Install Google Chrome
# ==============================
try {
    Write-Output "Downloading Chrome..."
    $chromeInstaller = "$env:TEMP\chrome.msi"
    Invoke-WebRequest `
        -Uri "https://dl.google.com/chrome/install/GoogleChromeEnterprise64.msi" `
        -OutFile $chromeInstaller `
        -UseBasicParsing

    Write-Output "Installing Chrome..."
    $process = Start-Process msiexec.exe `
        -ArgumentList "/i `"$chromeInstaller`" /qn /norestart" `
        -PassThru

    $process.WaitForExit(600000)  # 10 minutes max

    if ($process.ExitCode -ne 0) {
        Write-Output "Chrome install failed with exit code $($process.ExitCode)"
    } else {
        Write-Output "Chrome installed successfully"
    }
}
catch {
    Write-Output "Chrome installation error: $_"
}

# ==============================
# Install VS Code
# ==============================
try {
    Write-Output "Downloading VS Code..."
    $vscodeInstaller = "$env:TEMP\vscode.exe"
    Invoke-WebRequest `
        -Uri "https://update.code.visualstudio.com/latest/win32-x64/stable" `
        -OutFile $vscodeInstaller `
        -UseBasicParsing

    Write-Output "Installing VS Code..."
    Start-Process -FilePath $vscodeInstaller `
        -ArgumentList "/VERYSILENT /NORESTART /MERGETASKS=!runcode" `
        -Wait

    Start-Sleep -Seconds 15
    Write-Output "VS Code installed"
}
catch {
    Write-Output "VS Code installation error: $_"
}

# ==============================
# Install VS Code Extensions (SYSTEM Profile)
# ==============================
try {
    $codeCmd = "C:\Program Files\Microsoft VS Code\bin\code.cmd"

    if (Test-Path $codeCmd) {

        Write-Output "Installing VS Code extensions..."

        & $codeCmd --install-extension ms-azuretools.vscode-azurearmtools --force
        & $codeCmd --install-extension ms-vscode.powershell --force
        & $codeCmd --install-extension ms-azuretools.vscode-docker --force

        Start-Sleep -Seconds 10

        Write-Output "Installed Extensions:"
        & $codeCmd --list-extensions | Tee-Object "$OutDir\extensions-installed.txt"

        Write-Output "Extensions installed successfully"

    } else {
        Write-Output "VS Code command not found"
    }
}
catch {
    Write-Output "Extension installation error: $_"
}

Write-Output "===== Script Completed ====="
Stop-Transcript
