<powershell>
  Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force -ErrorAction Ignore

  $ProgressPreference = 'SilentlyContinue';
  $ErrorActionPreference = 'Stop';

  cmd.exe /c winrm quickconfig -q
  cmd.exe /c winrm quickconfig '-transport:http'
  cmd.exe /c winrm set "winrm/config" '@{MaxTimeoutms="1800000"}'
  cmd.exe /c winrm set "winrm/config/winrs" '@{MaxMemoryPerShellMB="1024"}'
  cmd.exe /c winrm set "winrm/config/service" '@{AllowUnencrypted="true"}'
  cmd.exe /c winrm set "winrm/config/service/auth" '@{Basic="true"}'
  cmd.exe /c winrm set "winrm/config/service/auth" '@{CredSSP="true"}'

  cmd.exe /c netsh advfirewall firewall set rule group="remote administration" new enable=yes
  cmd.exe /c netsh advfirewall firewall add rule name="Open Port 5985" dir=in action=allow protocol=TCP localport=5985
  
  cmd.exe /c net stop winrm
  cmd.exe /c sc config winrm start= auto
  cmd.exe /c net start winrm
</powershell>