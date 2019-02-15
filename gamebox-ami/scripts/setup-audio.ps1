# Setup Audio
Get-Service | Where {$_.Name -match "audio"} | set-service -StartupType "Automatic"
Get-Service | Where {$_.Name -match "audio"} | start-service