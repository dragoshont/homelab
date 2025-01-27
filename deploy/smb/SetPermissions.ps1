param (
    [string]$sharedFolderPath
)

# Define the permissions for the shareuser account
$permission = "shareuser", "FullControl", "Allow"

# Get the current ACL
$acl = Get-Acl -Path $sharedFolderPath

# Create a new access rule
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission

# Add the access rule to the ACL
$acl.SetAccessRule($accessRule)

# Apply the updated ACL to the folder
Set-Acl -Path $sharedFolderPath -AclObject $acl

Write-Output "Permissions have been set for shareuser on $sharedFolderPath"
