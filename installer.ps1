$url = "https://github.com/TheOtherRolesAU/TheOtherRoles/releases/download/v4.6.0/TheOtherRoles.zip"
$output = "$env:TEMP\TheOtherRoles.zip"
if (Test-Path -Path $output) {
    $checksum = Get-FileHash -Path $output -Algorithm SHA256
    if ($checksum.Hash -eq "7300fc6125bd0b36a7d9d92befaaf98e6b2b24ebd587714c2bef1fa1cdddc813") {
        Write-Host "The Other Roles mod file already downloaded." -ForegroundColor Red 
    } else {
        Write-Host "The Other Roles mod file checksum mismatch, redownloading..." -ForegroundColor Red
        Remove-Item -Path $output -Force
    }
} else {
    Write-Host "Downloading The Other Roles..." -ForegroundColor Red
    Invoke-WebRequest -Uri $url -OutFile $output
}

$APPID = 945360
$steamPath = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath"
$steamLibraryFolders = Get-Content -Path "$($steamPath.SteamPath)\steamapps\libraryfolders.vdf"
$steamLibraryFolders = $steamLibraryFolders | Select-String -Pattern "path"
$pattern = '^\s+"path"\s+"(.+?)"'
foreach ($line in $steamLibraryFolders) {
    if ($line -match $pattern) {
        $path = $matches[1]
        $normalizedPath = $path -replace '\\\\', '\'
        $normalizedPath = $normalizedPath + "\steamapps"
        $files = Get-ChildItem -Path $normalizedPath -Filter "*$APPID.acf"
        $foundAmongUsManifest = 0
        if ($files.Count -eq 1) {
            $file = $files[0]
            $foundAmongUsManifest = 1
            $normalPath = "$normalizedPath\common\Among Us"
            $publicPrevious = $fileContent | Select-String -Pattern "public-previous"
            if ($null -ne $publicPrevious) {
                Write-Warning "BetaKey already added in $file, is the script already running?"
                Pause
                return
            }
            $fileContent = Get-Content -Path $file.FullName
            $betaKeyLine = $fileContent | Select-String -Pattern "BetaKey"

            Write-Host "Closing Steam..." -ForegroundColor Red
            Get-Process -Name "steam*" -ErrorAction SilentlyContinue | Stop-Process -ErrorAction SilentlyContinue
            $process = Get-Process -Name "steam*" -ErrorAction SilentlyContinue
            while ($null -ne $process) {
                Start-Sleep -Seconds 1
                $process = Get-Process -Name "steam*" -ErrorAction SilentlyContinue
            }
            Write-Host "Steam closed" -ForegroundColor Red

            if (Test-Path -Path $normalPath) {
                $backupPath = "$normalizedPath\common\Among Us Backup"
                if (Test-Path -Path $backupPath) {
                    Remove-Item -Path $backupPath -Recurse -Force
                }
                Write-Host "Backing up Among Us to ""$backupPath""" -ForegroundColor Red
                Copy-Item -Path $normalPath -Destination $backupPath -Recurse
            }

            $fileContent = Get-Content -Path $file.FullName
            $betaKeyLine = $fileContent | Select-String -Pattern "BetaKey"
            if ($betaKeyLine -eq $0) {
                $lineNumber = $fileContent | Select-String -Pattern "UserConfig" | Select-Object -ExpandProperty LineNumber
                $fileContent[$lineNumber] = $fileContent[$lineNumber] -replace "{", "{`n""BetaKey"" ""public-previous"""
                $lineNumber = $fileContent | Select-String -Pattern "MountedConfig" | Select-Object -ExpandProperty LineNumber
                $fileContent[$lineNumber] = $fileContent[$lineNumber] -replace "{", "{`n""BetaKey"" ""public-previous"""
                Set-Content -Path $file.FullName -Value $fileContent
                $file
                Write-Host "BetaKey added for public-previous in ""$file""" -ForegroundColor Red
            } else {
                $fileContent = $fileContent -replace """public""", """public-previous"""
                Set-Content -Path $file.FullName -Value $fileContent
                Write-Host "BetaKey edited to public-previous in ""$file""" -ForegroundColor Red
            }
        }
    }
}
if ($foundAmongUsManifest -eq 0) {
    Write-Warning "Among Us not found in any Steam library folder."
} else {
    Write-Host "Among Us found in ""$normalizedPath""" -ForegroundColor Red

    Write-Host "Waiting for Among Us Public Previous (v2024.6.18) to download..." -ForegroundColor Red
    Start-Process -FilePath "$($steamPath.SteamPath)\steam.exe" -ArgumentList "-applaunch $APPID"
    $process = Get-Process -Name "Among Us" -ErrorAction SilentlyContinue
    while ($null -eq $process) {
        Start-Sleep -Seconds 1
        $process = Get-Process -Name "Among Us" -ErrorAction SilentlyContinue
    }
    Get-Process -Name "steam*" -ErrorAction SilentlyContinue | Stop-Process -ErrorAction SilentlyContinue
    Get-Process -Name "among us*" -ErrorAction SilentlyContinue | Stop-Process -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Write-Host "Among Us (v2024.6.18) installed" -ForegroundColor Red
    
    $fileContent = $fileContent -replace """public-previous""", """public"""
    Set-Content -Path $file.FullName -Value $fileContent
    Write-Host "BetaKey revereted to public in ""$file""" -ForegroundColor Red

    if (Test-Path -Path $normalPath) {
        $moddedPath = "$normalizedPath\common\Among Us Modded"
        if (Test-Path -Path $moddedPath) {
            Remove-Item -Path $moddedPath -Recurse -Force
        }
        Move-Item -Path $normalPath -Destination $moddedPath
        Write-Host "Among Us modded folder moved to ""$moddedPath""" -ForegroundColor Red
        if (Test-Path -Path $normalPath) {
            Remove-Item -Path $normalPath -Recurse -Force
        }
        Move-Item -Path $backupPath -Destination $normalPath
        Write-Host "Among Us backup folder moved to ""$normalPath""" -ForegroundColor Red
    }

    Write-Host "Installing The other roles to ""$moddedPath""" -ForegroundColor Red
    Expand-Archive -Path $output -Destination $moddedPath -Force
    Start-Process -FilePath "$($steamPath.SteamPath)\steam.exe" 

    $targetPath = $moddedPath + "\Among Us.exe"
    $shortcutPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath('StartMenu'), 'Programs', 'Among Us Modded.lnk')
    $WScriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $targetPath
    $shortcut.WorkingDirectory = [System.IO.Path]::GetDirectoryName($targetPath)
    $shortcut.IconLocation = $targetPath
    $shortcut.Save()
    $shortcutPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath('Desktop'), 'Among Us Modded.lnk')
    $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $targetPath
    $shortcut.WorkingDirectory = [System.IO.Path]::GetDirectoryName($targetPath)
    $shortcut.IconLocation = $targetPath
    $shortcut.Save()
    
    Write-Host "Shortcut created in Start Menu and Desktop" -ForegroundColor Red
    Write-Host "Among Us Modded is ready to play, Have fun!" -ForegroundColor Red
    Pause
}
