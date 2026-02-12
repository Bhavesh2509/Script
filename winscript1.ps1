param(
    [string]$CustomHtml,
    [string]$CustomAuthData
)

# Install IIS
Install-WindowsFeature -name Web-Server -IncludeManagementTools

# Deploy HTML
Set-Content -Path "C:\inetpub\wwwroot\index.html" -Value $CustomHtml

# Optional: Handle Auth data
Set-Content -Path "C:\inetpub\wwwroot\auth.txt" -Value $CustomAuthData
