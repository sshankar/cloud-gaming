# Disable defender & firewall.
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
Set-MpPreference -DisableRealtimeMonitoring $true

# Install windows features
Install-WindowsFeature Net-Framework-Core
Install-WindowsFeature Server-Media-Foundation -IncludeAllSubFeature

# Set pagefile to 16MB
$ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem -EnableAllPrivileges
if ($ComputerSystem.AutomaticManagedPagefile) {
  $ComputerSystem.AutomaticManagedPagefile = $false
  $ComputerSystem.Put()
}

$CurrentPageFile = Get-WmiObject -Class Win32_PageFileSetting
$CurrentPageFile.Delete()

Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{Name="C:\pagefile.sys"; InitialSize = 16; MaximumSize = 16}