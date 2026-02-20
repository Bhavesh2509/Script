# Install Google Chrome (Enterprise MSI)
Write-Output "Installing Google Chrome..."
$chromeInstaller = "$env:TEMP\chrome.msi"
Invoke-WebRequest -Uri "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi" -OutFile $chromeInstaller
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$chromeInstaller`" /quiet /norestart" -Wait
Remove-Item $chromeInstaller -Force

# Install IIS
Write-Output "Installing IIS..."
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# Add custom HTML page
Write-Output "Adding custom HTML page..."
$sitePath = "C:\inetpub\wwwroot\index.html"
$htmlContent = @"
<html>
<head><title>Welcome</title></head>
<body>
<h1>Hello from Azure VM!</h1>
<p>This is a custom IIS page deployed via raw script + CSE.</p>
</body>
</html>
"@
Set-Content -Path $sitePath -Value $htmlContent -Force

# Install Visual Studio Code (Silent EXE)
Write-Output "Installing Visual Studio Code..."
$vsInstaller = "$env:TEMP\vscode_installer.exe"
Invoke-WebRequest -Uri "https://update.code.visualstudio.com/latest/win32-x64-user/stable" -OutFile $vsInstaller
Start-Process -FilePath $vsInstaller -ArgumentList "/VERYSILENT /MERGETASKS=!runcode" -Wait
Remove-Item $vsInstaller -Force

# Create logon task for VS Code extensions
Write-Output "Creating logon task for VS Code extensions..."
$taskName = "InstallVSCodeExtensions"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -Command `"code --install-extension ms-python.python; code --install-extension ms-vscode.cpptools`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -User "<ADMIN_USERNAME>" -RunLevel Highest -Force

