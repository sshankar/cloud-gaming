# create an alternate admin user for autologin.
$User = "CloudGamer"
$Password = "sm4r7A$$C10udGam3r"

New-LocalUser $User -Password $(ConvertTo-SecureString $Password) -FullName "Cloud Gamer"
Add-LocalGroupMember -Group "Administrators" -Member $User

$WinLogonRegPath = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty $WinLogonRegPath "AutoAdminLogon" -Value "1" -Type String -Force
Set-ItemProperty $RegPath "DefaultUsername" -Value $User -type String
Set-ItemProperty $RegPath "DefaultPassword" -Value $Password -type String