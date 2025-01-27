# Define the username and password
$username = "shareuser"
$password = "a9Tp2R7K1vNxL6dYwZ3BqV0sH4JmP8Gc"

# Create a secure password
$securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force

# Check if the user already exists
if (Get-LocalUser -Name $username -ErrorAction SilentlyContinue) {
    Write-Output "User '$username' already exists. Updating the password."
    # Update the user's password
    Set-LocalUser -Name $username -Password $securePassword
} else {
    Write-Output "User '$username' does not exist. Creating the user."
    # Create the user account
    New-LocalUser -Name $username -Password $securePassword -FullName "Share User" -Description "User account for folder sharing" -PasswordNeverExpires

    # Explicitly deny the user login rights locally and through RDP
    $denyLoginLocally = "SeDenyInteractiveLogonRight"
    $denyLoginRemote = "SeDenyRemoteInteractiveLogonRight"

    # Add the user to the deny login policies
    secedit /export /cfg C:\Windows\Temp\secpol.cfg
    Add-Content -Path C:\Windows\Temp\secpol.cfg -Value "[Privilege Rights]"
    Add-Content -Path C:\Windows\Temp\secpol.cfg -Value "$denyLoginLocally = *$username"
    Add-Content -Path C:\Windows\Temp\secpol.cfg -Value "$denyLoginRemote = *$username"
    secedit /configure /db C:\Windows\security\database\secedit.sdb /cfg C:\Windows\Temp\secpol.cfg /areas USER_RIGHTS

    # Remove the temporary configuration file
    Remove-Item C:\Windows\Temp\secpol.cfg
}
