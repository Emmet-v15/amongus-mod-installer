# Define the URL to download the mod and the output path for the downloaded file
$url = "https://github.com/TheOtherRolesAU/TheOtherRoles/releases/download/v4.6.0/TheOtherRoles.zip"
$output = "$env:TEMP\TheOtherRoles.zip"

# Check if the file already exists
if (Test-Path -Path $output) {
    # Calculate the SHA256 checksum of the existing file
    $checksum = Get-FileHash -Path $output -Algorithm SHA256
    # Compare the calculated checksum with the expected checksum
    if ($checksum.Hash -eq "7300fc6125bd0b36a7d9d92befaaf98e6b2b24ebd587714c2bef1fa1cdddc813") {
        Write-Host "The Other Roles mod file already downloaded." -ForegroundColor Red 
    } else {
        # If checksum does not match, inform the user and delete the file for redownloading
        Write-Host "The Other Roles mod file checksum mismatch, redownloading..." -ForegroundColor Red
        Remove-Item -Path $output -Force
    }
} else {
    # Download the file if it doesn't exist
    Write-Host "Downloading The Other Roles..." -ForegroundColor Red
    Invoke-WebRequest -Uri $url -OutFile $output
}

# Define the Steam AppID for Among Us
$APPID = 945360
# Retrieve the Steam installation path from the registry
$steamPath = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath"
# Read Steam library folders configuration
$steamLibraryFolders = Get-Content -Path "$($steamPath.SteamPath)\steamapps\libraryfolders.vdf"
$steamLibraryFolders = $steamLibraryFolders | Select-String -Pattern "path"
$pattern = '^\s+"path"\s+"(.+?)"'

# Search for the Among Us game in the Steam library folders
foreach ($line in $steamLibraryFolders) {
    if ($line -match $pattern) {
        $path = $matches[1]
        $normalizedPath = $path -replace '\\\\', '\'
        $normalizedPath = $normalizedPath + "\steamapps"
        $files = Get-ChildItem -Path $normalizedPath -Filter "*$APPID.acf"
        $foundAmongUsManifest = 0

        # Check if the Among Us manifest file exists
        if ($files.Count -eq 1) {
            $file = $files[0]
            $foundAmongUsManifest = 1
            $normalPath = "$normalizedPath\common\Among Us"
            $publicPrevious = $fileContent | Select-String -Pattern "public-previous"
            
            if ($null -ne $publicPrevious) {
                # Warn if the BetaKey is already added
                Write-Warning "BetaKey already added in $file, is the script already running?"
                Pause
                return
            }

            # Read file content
            $fileContent = Get-Content -Path $file.FullName
            $betaKeyLine = $fileContent | Select-String -Pattern "BetaKey"

            # Close Steam
            Write-Host "Closing Steam..." -ForegroundColor Red
            Get-Process -Name "steam*" -ErrorAction SilentlyContinue | Stop-Process -ErrorAction SilentlyContinue
            $process = Get-Process -Name "steam*" -ErrorAction SilentlyContinue
            while ($null -ne $process) {
                Start-Sleep -Seconds 1
                $process = Get-Process -Name "steam*" -ErrorAction SilentlyContinue
            }
            Write-Host "Steam closed" -ForegroundColor Red

            # Backup existing Among Us installation
            if (Test-Path -Path $normalPath) {
                $backupPath = "$normalizedPath\common\Among Us Backup"
                if (Test-Path -Path $backupPath) {
                    Remove-Item -Path $backupPath -Recurse -Force
                }
                Write-Host "Backing up Among Us to ""$backupPath""" -ForegroundColor Red
                Copy-Item -Path $normalPath -Destination $backupPath -Recurse
            }

            # Modify file content to add BetaKey
            $fileContent = Get-Content -Path $file.FullName
            $betaKeyLine = $fileContent | Select-String -Pattern "BetaKey"
            if ($betaKeyLine -eq $0) {
                # Insert BetaKey if not present
                $lineNumber = $fileContent | Select-String -Pattern "UserConfig" | Select-Object -ExpandProperty LineNumber
                $fileContent[$lineNumber] = $fileContent[$lineNumber] -replace "{", "{`n""BetaKey"" ""public-previous"""
                $lineNumber = $fileContent | Select-String -Pattern "MountedConfig" | Select-Object -ExpandProperty LineNumber
                $fileContent[$lineNumber] = $fileContent[$lineNumber] -replace "{", "{`n""BetaKey"" ""public-previous"""
                Set-Content -Path $file.FullName -Value $fileContent
                Write-Host "BetaKey added for public-previous in ""$file""" -ForegroundColor Red
            } else {
                # Replace existing public with public-previous
                $fileContent = $fileContent -replace """public""", """public-previous"""
                Set-Content -Path $file.FullName -Value $fileContent
                Write-Host "BetaKey edited to public-previous in ""$file""" -ForegroundColor Red
            }
        }
    }
}

# Check if Among Us was found
if ($foundAmongUsManifest -eq 0) {
    Write-Warning "Among Us not found in any Steam library folder."
} else {
    Write-Host "Among Us found in ""$normalizedPath""" -ForegroundColor Red

    # Launch Steam to trigger download of the Public Previous version
    Write-Host "Waiting for Among Us Public Previous (v2024.6.18) to download..." -ForegroundColor Red
    Start-Process -FilePath "$($steamPath.SteamPath)\steam.exe" -ArgumentList "-applaunch $APPID"
    $process = Get-Process -Name "Among Us" -ErrorAction SilentlyContinue
    while ($null -eq $process) {
        Start-Sleep -Seconds 1
        $process = Get-Process -Name "Among Us" -ErrorAction SilentlyContinue
    }
    # Close Steam and Among Us processes
    Get-Process -Name "steam*" -ErrorAction SilentlyContinue | Stop-Process -ErrorAction SilentlyContinue
    Get-Process -Name "among us*" -ErrorAction SilentlyContinue | Stop-Process -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Write-Host "Among Us (v2024.6.18) installed" -ForegroundColor Red
    
    # Revert BetaKey changes
    $fileContent = $fileContent -replace """public-previous""", """public"""
    Set-Content -Path $file.FullName -Value $fileContent
    Write-Host "BetaKey reverted to public in ""$file""" -ForegroundColor Red

    # Move Among Us installation to modded folder
    if (Test-Path -Path $normalPath) {
        $moddedPath = "$normalizedPath\common\Among Us Modded\"
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

    # Install the mod
    Write-Host "Installing The other roles to ""$moddedPath""" -ForegroundColor Red
    Expand-Archive -Path $output -Destination $moddedPath -Force
    Start-Process -FilePath "$($steamPath.SteamPath)\steam.exe" 

    # Create desktop and Start Menu shortcuts
    $targetPath = $moddedPath + "Among Us.exe"
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
    
    # Create Steam shortcut
    Write-Host "Patching Steam shortcut files..." -ForegroundColor Red
    $shortcuts = Get-ChildItem -Path "$($steamPath.SteamPath)\userdata"
    foreach ($shortcut in $shortcuts) {
        $shortcutPath = "$($steamPath.SteamPath)/userdata/$($shortcut.Name)/config/shortcuts.vdf"
        Write-Host "Patching ""$shortcutPath""" -ForegroundColor Red
        if (Test-Path -Path $shortcutPath) {
            $shortcutContent = Get-Content -Path $shortcutPath -Raw -Encoding Byte
            $shortcutContent = [System.BitConverter]::ToString($shortcutContent).Replace("-", "")
            $patched = $shortcutContent -match '.*(00(3[0-9]){1,}0002.*?416D6F6E672055732E65786522.*?0808)'
            if ($patched) {
                Write-Host "Steam shortcut file already patched, reapplying..." -ForegroundColor Red
                $shortcutContent = $shortcutContent -replace $matches[1], ''
            }
            $tmp = $shortcutContent.ToCharArray()
            [Array]::Reverse($tmp)
            $tmp = -join $tmp
            $hasItems = $tmp -match '2000([0-9]3){1,}00' | Out-Null
            # if doesn't have any items, set index to 0
            $index = '0'
            if (!$hasItems) {
                $index = '30' # 0 in ASCII
            } else {
                $tmp = $matches[0].ToCharArray()
                [Array]::Reverse($tmp)
                $match = -join $tmp
                $match = $match.Substring(2)
                $match = $match.Substring(0, $match.Length - 4)
                $match = $match -split '(..)' | Where-Object { $_ }
                $match = $match -replace '^\d', ''
                $match = $match -join ''
                $match = [int]$match + 1
                $match = $match.ToString()
                $match = $match.ToCharArray()
                $index = ''
                for ($i = 0; $i -lt $match.Length; $i++) {
                    $index = $index + '3' + $match[$i]
                }
            }

            $path = [System.BitConverter]::ToString([System.Text.Encoding]::ASCII.GetBytes($moddedPath)).Replace("-", "")
            $shortcutName = [System.BitConverter]::ToString([System.Text.Encoding]::ASCII.GetBytes("Among Us Modded")).Replace("-", "")
            $executableName = [System.BitConverter]::ToString([System.Text.Encoding]::ASCII.GetBytes("Among Us.exe")).Replace("-", "")
            $favouritesPatch = "" # set this to "0130006661766F7269746500" to add the favourite flag, this it buggy as steam doesn't update the shortcuts properly
            # :D
            $amongusPatch="00${index}0002617070696400A798A9BF014170704E616D6500${shortcutName}00014578650022${path}${executableName}220001537461727444697200${path}000169636F6E00000153686F7274637574506174680000014C61756E63684F7074696F6E73000002497348696464656E000000000002416C6C6F774465736B746F70436F6E666967000100000002416C6C6F774F7665726C61790001000000024F70656E56520000000000024465766B69740000000000014465766B697447616D6549440000024465766B69744F7665727269646541707049440000000000024C617374506C617954696D65000000000001466C617470616B41707049440000007461677300${favouritesPatch}0808"
            $shortcutContent = $shortcutContent.Insert($shortcutContent.Length - 4, $amongusPatch)
            $byteArray = [byte[]]::new($shortcutContent.Length / 2)
            for ($i = 0; $i -lt $shortcutContent.Length; $i += 2) {
                $byteArray[$i / 2] = [Convert]::ToByte($shortcutContent.Substring($i, 2), 16)
            }
            Set-Content -Path $shortcutPath -Value $byteArray -Encoding Byte
            Write-Host "Steam shortcut file patched successfully!" -ForegroundColor Red
        } else {
            Write-Host "Steam shortcut file not found, creating..." -ForegroundColor Red
            $index = "30"
            $shortcutName = [System.BitConverter]::ToString([System.Text.Encoding]::ASCII.GetBytes("Among Us Modded")).Replace("-", "")
            $executableName = [System.BitConverter]::ToString([System.Text.Encoding]::ASCII.GetBytes("Among Us.exe")).Replace("-", "")
            $defaultShortcutContent = "0073686F72746375747300"
            $amongusPatch = "${defaultShortcutContent}00${index}0002617070696400A798A9BF014170704E616D6500${shortcutName}00014578650022${path}${executableName}220001537461727444697200${path}000169636F6E00000153686F7274637574506174680000014C61756E63684F7074696F6E73000002497348696464656E000000000002416C6C6F774465736B746F70436F6E666967000100000002416C6C6F774F7665726C61790001000000024F70656E56520000000000024465766B69740000000000014465766B697447616D6549440000024465766B69744F7665727269646541707049440000000000024C617374506C617954696D65000000000001466C617470616B4170704944000000746167730008080808"
            $byteArray = [byte[]]::new($amongusPatch.Length / 2)
            for ($i = 0; $i -lt $amongusPatch.Length; $i += 2) {
                $byteArray[$i / 2] = [Convert]::ToByte($amongusPatch.Substring($i, 2), 16)
            }
            $directory = "$($steamPath.SteamPath)/userdata/$($shortcut.Name)/config"
            if (!(Test-Path -Path $directory)) {
                New-Item -Path $directory -ItemType Directory
            }
            Set-Content -Path $shortcutPath -Value $byteArray -Encoding Byte
        }
    }

    Write-Host "The Other Hats (Cosmetics) are being downloaded, do not close Among Us!" -ForegroundColor Red

    $moddedPath = "C:\Program Files (x86)\Steam\steamapps\common\Among Us Modded"
    Start-Process -FilePath "$moddedPath\Among Us.exe"
    
    # Folder to simulate downloads
    
    $destinationFolder = "$moddedPath\TheOtherHats"
    
    # Ensure the folder exists
    if (-not (Test-Path -Path $destinationFolder)) {
        New-Item -Path $destinationFolder -ItemType Directory | Out-Null
    }
    
    # Parameters for the fake loading bar
    $totalSteps = 872       # Total number of steps in the loading bar
    
    # Start the fake loading bar
    while (((Get-ChildItem -Path $destinationFolder -File).Count / $totalSteps) -le 0.99) {
        # Calculate the percentage completed
        $percentComplete = ((Get-ChildItem -Path $destinationFolder -File).Count / $totalSteps) * 100
        $percentComplete = "{0:N2}" -f $percentComplete
    
        # Display the progress bar
        Write-Progress -Activity "Processing" -Status "$percentComplete% Complete" -PercentComplete $percentComplete
    
        # Wait for the calculated delay
        Start-Sleep -Milliseconds 1000
    }
    
    Write-Host "The Other Hats (Cosmetics) are downloaded!" -ForegroundColor Red
    Write-Host "Shortcut created in Start Menu, Desktop and The Steam Library" -ForegroundColor Red
    Write-Host "Among Us Modded is ready to play, Have fun!" -ForegroundColor Red
    Pause
}
