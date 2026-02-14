$flagFile = "C:\hyperv_installed.txt"

# If Hyper-V not installed
if (!(Test-Path $flagFile)) {

    Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart

    # Create flag file after restart
    New-Item -Path $flagFile -ItemType File -Force
    exit
}

# After reboot - continue

# Create shared folder
New-Item -Path C:\SharedFolder -ItemType Directory -Force

# Create internal switch
if (-not (Get-VMSwitch -Name "InternalSwitch" -ErrorAction SilentlyContinue)) {
    New-VMSwitch -Name "InternalSwitch" -SwitchType Internal
}

# Create VHD
if (-not (Test-Path "C:\InnerVM.vhdx")) {
    New-VHD -Path "C:\InnerVM.vhdx" -SizeBytes 20GB -Dynamic
}

# Create Inner VM
if (-not (Get-VM -Name "InnerVM" -ErrorAction SilentlyContinue)) {
    New-VM -Name "InnerVM" `
        -MemoryStartupBytes 2GB `
        -VHDPath "C:\InnerVM.vhdx" `
        -SwitchName "InternalSwitch"
}

Start-VM -Name "InnerVM"

# Save simulated output
Get-Process | Out-File C:\SharedFolder\process.txt