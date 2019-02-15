# Download files for setup.
New-Item -ItemType directory -Path "C:\SetupFiles\"
Invoke-WebRequest "https://dl.razerzone.com/drivers/Surround/win/RazerSurroundInstaller_v2.0.29.20.exe" -OutFile "C:\SetupFiles\RazerSurroundInstaller.exe"
Invoke-WebRequest "https://download.zerotier.com/dist/ZeroTier%20One.msi" -OutFile "C:\SetupFiles\ZeroTierOne.msi"
Invoke-WebRequest "https://steamcdn-a.akamaihd.net/client/installer/SteamSetup.exe" -OutFile "C:\SetupFiles\SteamSetup.exe"

Invoke-WebRequest "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip" -OutFile "C:\SetupFiles\steamcmd.zip"
Expand-Archive -Path "C:\SetupFiles\steamcmd.zip" -DestinationPath "C:\SetupFiles\"