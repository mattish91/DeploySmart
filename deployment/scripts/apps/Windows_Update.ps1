# Script made by Mattias Magnusson 2025-08-21
# Checks and installs Windows Updates after application installation is done. 
# Doing this before application installations can and will result in applications failing to install.
# Updated 2026-01-16

function Get-And-Install-AllUpdates {
    $logPath = "C:\logs\UpdateLog.txt"
    if (-not (Test-Path "C:\logs")) {
        New-Item -Path "C:\logs" -ItemType Directory -Force | Out-Null
    }

    function Log($message) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$timestamp - $message" | Out-File -FilePath $logPath -Append -Encoding UTF8
        Write-Output $message
    }

    function Get-ResultMeaning([int]$code) {
        switch ($code) {
            0 { "Not Started" }
            1 { "In Progress" }
            2 { "Succeeded" }
            3 { "Succeeded With Errors" }
            4 { "Failed" }
            5 { "Aborted" }
            default { "Unknown" }
        }
    }

    function Format-EventMessage([string]$s, [int]$max = 2048) {
        if ([string]::IsNullOrWhiteSpace($s)) { return "" }
        $flat = ($s -replace "(\r?\n)+", " ").Trim()
        if ($flat.Length -gt $max) { return $flat.Substring(0, $max) }
        return $flat
    }

    try {
        Log "Creating Microsoft.Update.Session COM object"
        $session = New-Object -ComObject Microsoft.Update.Session -ErrorAction Stop
        $searcher = $session.CreateUpdateSearcher()

        # Force use of Microsoft Update instead of WSUS
        Log "Forcing use of Microsoft Update instead of WSUS..."
        $serviceManager = New-Object -ComObject Microsoft.Update.ServiceManager
        $serviceManager.ClientApplicationID = "PowerShell Script"

        $muService = $serviceManager.Services | Where-Object { $_.Name -eq "Microsoft Update" }
        if (-not $muService) {
            Log "Registering Microsoft Update service..."
            $serviceManager.AddService2("7971f918-a847-4430-9279-4a52d1efe18d", 7, "")
        } else {
            Log "Microsoft Update service already registered."
        }

        Log "Searching for all missing updates (software, drivers, definitions, etc.)..."
        $searchResult = $searcher.Search("IsInstalled=0")

        $updates = $searchResult.Updates
        Log "Total updates found: $($updates.Count)"
        if ($updates.Count -eq 0) {
            Log "No missing updates found."
            return
        }

        # --- Build download list + event per item queued ---
        $updatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($update in $updates) {
            if (-not $update.IsDownloaded) {
                Log "Adding to download list: $($update.Title)"
                $updatesToDownload.Add($update) | Out-Null

                # Event for user visibility: queued to download
                $title = Format-EventMessage $update.Title
                $msg   = "Queued to download: $title"
                eventcreate /ID 3000 /L APPLICATION /T INFORMATION /SO "CustomWindowsUpdate" /D "$msg" | Out-Null
            }
        }

        if ($updatesToDownload.Count -gt 0) {
            Log "Downloading updates..."
            $downloader = $session.CreateUpdateDownloader()
            $downloader.Updates = $updatesToDownload
            $downloader.Download()
        } else {
            Log "All updates already downloaded."
        }

        # --- Build install list ---
        $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($update in $updates) {
            if ($update.IsDownloaded -and -not $update.IsInstalled) {
                Log "Adding to install list: $($update.Title)"
                $updatesToInstall.Add($update) | Out-Null
            }
        }

        if ($updatesToInstall.Count -gt 0) {
            Log "Installing updates..."
            $installer = $session.CreateUpdateInstaller()
            $installer.Updates = $updatesToInstall
            $installationResult = $installer.Install()

            # Overall result + friendly meaning
            $overallCode    = [int]$installationResult.ResultCode
            $overallMeaning = Get-ResultMeaning $overallCode
            Log "Installation Result Code: $overallCode ($overallMeaning)"
            Log "Reboot Required: $($installationResult.RebootRequired)"

            # Optional: overall/batch summary event (user-visible)
            $summaryId  = if ($overallCode -eq 2 -and -not $installationResult.RebootRequired) { 3101 } else { 3100 }
            $summaryMsg = "Batch install completed. Overall: $overallMeaning ($overallCode). RebootRequired=$($installationResult.RebootRequired)."
            eventcreate /ID $summaryId /L APPLICATION /T INFORMATION /SO "CustomWindowsUpdate" /D "$summaryMsg" | Out-Null

            # Per-update results + events
            for ($i = 0; $i -lt $updatesToInstall.Count; $i++) {
                $update = $updatesToInstall.Item($i)
                $result = $installationResult.GetUpdateResult($i)
                $code   = [int]$result.ResultCode
                $codeMeaning = Get-ResultMeaning $code

                Log "Update: $($update.Title)"
                Log "  Result Code: $code ($codeMeaning)"
                Log "  Reboot Required: $($result.RebootRequired)"

                # Defender note
                if (($code -eq 2 -or $code -eq 3) -and $update.Title -like "*Defender*") {
                    Log "  Note: Result code $code is common for Defender updates and usually not a problem."
                }

                # User-visible event per update installed
                $title = Format-EventMessage $update.Title
                $eventMsg = "Installed via script: $title, Result Code: $code ($codeMeaning). RebootRequired=$($result.RebootRequired)."

                $eventId = switch ($code) {
                    2 { 3001 } # Succeeded
                    3 { 3002 } # Succeeded with errors
                    4 { 3003 } # Failed
                    5 { 3004 } # Aborted
                    default { 3005 } # Other/Unknown
                }

                eventcreate /ID $eventId /L APPLICATION /T INFORMATION /SO "CustomWindowsUpdate" /D "$eventMsg" | Out-Null
            }

            if ($installationResult.RebootRequired) {
                Log "System will reboot now to complete installation."
                Restart-Computer -Force
            }

        } else {
            Log "No updates to install."
        }

    } catch {
        Log "Fatal Exception: $($_.Exception.Message)"
    }
}

# Run the function
Get-And-Install-AllUpdates
