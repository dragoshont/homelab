# Ensure Admin rights
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Run this script as Administrator."
    exit 1
}

Write-Host "Unregistering existing Ubuntu (if any)..."
$existingDistros = wsl --list --quiet
if ($existingDistros -contains "Ubuntu") {
    wsl --unregister Ubuntu
    Start-Sleep -Seconds 3
}

Write-Host "Installing Ubuntu..."
wsl --install -d Ubuntu

Write-Host ""
Write-Host "Waiting for Ubuntu to finish initial setup..."
Write-Host "A new Ubuntu window may pop up. Let it finish and return here."
Read-Host -Prompt "Press Enter ONLY AFTER the Ubuntu terminal finishes initializing the system"

# Create the Linux setup script (no BOM, LF-only)
$linuxSetup = @"
#!/bin/bash
set -e

# Install NFS if missing
sudo apt-get update
sudo apt-get install -y nfs-kernel-server

# Make sure directories are in place
sudo mkdir -p /mnt/externalshare
sudo mkdir -p /mnt/internalshare

# Backup exports
if [ ! -f /etc/exports.bak ]; then
  sudo cp /etc/exports /etc/exports.bak
fi

# Append exports if not present
grep -q "^/mnt/externalshare " /etc/exports || echo "/mnt/externalshare *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
grep -q "^/mnt/internalshare " /etc/exports || echo "/mnt/internalshare *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports

# Apply exports
sudo exportfs -ra
sudo service nfs-kernel-server restart || echo "Note: systemd may not be supported in WSL."
"@

# Save script with LF-only line endings (Unix style) and without BOM
$scriptPath = "$env:USERPROFILE\setup-nfs.sh"
$utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false)

# Ensure the script uses LF endings instead of CRLF
$cleanedScript = $linuxSetup -replace "`r`n", "`n"

[System.IO.File]::WriteAllText($scriptPath, $cleanedScript, $utf8NoBomEncoding)

Write-Host "Running Linux setup inside WSL..."
wsl bash "/mnt/c/Users/$env:USERNAME/setup-nfs.sh"

# Open firewall port if needed
$ruleName = "WSL NFS"
$ruleExists = netsh advfirewall firewall show rule name="$ruleName" | Select-String "Rule Name"
if (-not $ruleExists) {
    netsh advfirewall firewall add rule name="$ruleName" dir=in action=allow protocol=TCP localport=2049
    Write-Host "Firewall rule added for TCP port 2049."
} else {
    Write-Host "Firewall rule already exists."
}

Write-Host ""
Write-Host "✅ NFS setup completed. Ubuntu WSL shares /mnt/externalshare and /mnt/internalshare via NFS."
Write-Host "You can now mount them from your client machines."
