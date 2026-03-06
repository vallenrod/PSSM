# =====================================
# PSSM 0.1 - PowerShell Startup Manager
# =====================================

$Global:StartupEntries = @()

function Get-StartupItems {
    $entries = @()

    # Registry Run keys (Current User)
    if (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run") {
        Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" | ForEach-Object {
            $_.PSObject.Properties |
            Where-Object { $_.Name -notin "PSPath","PSParentPath","PSChildName","PSDrive","PSProvider" } |
            ForEach-Object {
                $entries += [PSCustomObject]@{
                    Type = "Registry (CU)"
                    Name = $_.Name
                    Command = $_.Value
                }
            }
        }
    }

    # Registry Run keys (Local Machine)
    if (Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run") {
        Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" | ForEach-Object {
            $_.PSObject.Properties |
            Where-Object { $_.Name -notin "PSPath","PSParentPath","PSChildName","PSDrive","PSProvider" } |
            ForEach-Object {
                $entries += [PSCustomObject]@{
                    Type = "Registry (LM)"
                    Name = $_.Name
                    Command = $_.Value
                }
            }
        }
    }

    # Startup folders
    $userStartup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    if(Test-Path $userStartup){
        Get-ChildItem $userStartup | ForEach-Object {
            $entries += [PSCustomObject]@{
                Type = "Startup Folder (CU)"
                Name = $_.Name
                Command = $_.FullName
            }
        }
    }

    $allStartup = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
    if(Test-Path $allStartup){
        Get-ChildItem $allStartup | ForEach-Object {
            $entries += [PSCustomObject]@{
                Type = "Startup Folder (All)"
                Name = $_.Name
                Command = $_.FullName
            }
        }
    }

    # Scheduled tasks (logon triggers)
    Get-ScheduledTask | Where-Object {$_.Triggers.TriggerType -eq "Logon"} | ForEach-Object {
        $entries += [PSCustomObject]@{
            Type = "Scheduled Task"
            Name = $_.TaskName
            Command = $_.TaskPath
        }
    }

    $Global:StartupEntries = $entries
}

function List-Startup {
    Get-StartupItems
    if($Global:StartupEntries.Count -eq 0){
        Write-Host "No startup items found."
        return
    }
    Write-Host "`nStartup Items:`n"
    $i = 1
    $Global:StartupEntries | ForEach-Object {
        Write-Host ("[{0}] {1,-20} | {2,-18} `n {3}" -f $i, $_.Type, $_.Name, $_.Command)
        Start-Sleep -Milliseconds 40
        $i++
    }
    Write-Host "`nTotal: $($Global:StartupEntries.Count)`n Press Enter to return to main menu"
}

function Disable-RegistryItem {
    $regItems = $Global:StartupEntries | Where-Object { $_.Type -like "Registry*" -and $_.Name -notlike "_DISABLED_*" }
    if($regItems.Count -eq 0){
        Write-Host "No registry startup items available to disable."
        return
    }

    Write-Host "`nRegistry Startup Items:`n"
    $i = 1
    $regItems | ForEach-Object {
        Write-Host ("[{0}] {1,-18} | {2,-20} `n {3}" -f $i, $_.Type, $_.Name, $_.Command)
        Start-Sleep -Milliseconds 40
        $i++
    }

    $entryNum = Read-Host "Enter the number of the registry item to disable (or Enter to cancel)"
    if(-not [int]::TryParse($entryNum,[ref]$null)){ Write-Host "Cancelled."; return }
    $entryNum = [int]$entryNum
    if($entryNum -le 0 -or $entryNum -gt $regItems.Count){ Write-Host "Invalid number."; return }

    $item = $regItems[$entryNum-1]
    $newName = "_DISABLED_$($item.Name)"
    $path = if($item.Type -eq "Registry (CU)") { "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" } else { "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" }
    Rename-ItemProperty -Path $path -Name $item.Name -NewName $newName
    Write-Host "Disabled $($item.Name) (renamed to $newName)."
}

function Reenable-RegistryItem {
    $disabledItems = $Global:StartupEntries | Where-Object { $_.Type -like "Registry*" -and $_.Name -like "_DISABLED_*" }
    if($disabledItems.Count -eq 0){
        Write-Host "No disabled registry items found."
        return
    }

    Write-Host "`nDisabled Registry Items:`n"
    $i = 1
    $disabledItems | ForEach-Object {
        Write-Host ("[{0}] {1,-18} | {2,-25} `n {3}" -f $i, $_.Type, $_.Name, $_.Command)
        Start-Sleep -Milliseconds 40
        $i++
    }

    $entryNum = Read-Host "Enter the number of the item to re-enable (or Enter to cancel)"
    if(-not [int]::TryParse($entryNum,[ref]$null)){ Write-Host "Cancelled."; return }
    $entryNum = [int]$entryNum
    if($entryNum -le 0 -or $entryNum -gt $disabledItems.Count){ Write-Host "Invalid number."; return }

    $item = $disabledItems[$entryNum-1]
    $newName = $item.Name -replace '^_DISABLED_', ''
    $path = if($item.Type -eq "Registry (CU)") { "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" } else { "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" }
    Rename-ItemProperty -Path $path -Name $item.Name -NewName $newName
    Write-Host "Re-enabled $newName."
}

function Remove-StartupItem {
    $entryNum = Read-Host "Enter the entry number to remove (or press Enter to cancel)"
    if(-not [int]::TryParse($entryNum,[ref]$null)){ Write-Host "Cancelled."; return }
    $entryNum = [int]$entryNum
    if($entryNum -le 0 -or $entryNum -gt $Global:StartupEntries.Count){ Write-Host "Invalid number."; return }

    $item = $Global:StartupEntries[$entryNum-1]
    switch ($item.Type){
        "Registry (CU)" { Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $item.Name -ErrorAction SilentlyContinue; Write-Host "Removed $($item.Name) from Current User Registry Run." }
        "Registry (LM)" { Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $item.Name -ErrorAction SilentlyContinue; Write-Host "Removed $($item.Name) from Local Machine Registry Run." }
        "Startup Folder (CU)" { Remove-Item $item.Command -ErrorAction SilentlyContinue; Write-Host "Removed $($item.Name) from Current User Startup folder." }
        "Startup Folder (All)" { Remove-Item $item.Command -ErrorAction SilentlyContinue; Write-Host "Removed $($item.Name) from All Users Startup folder." }
        "Scheduled Task" { schtasks /delete /tn $item.Name /f | Out-Null; Write-Host "Removed scheduled task $($item.Name)." }
        default { Write-Host "Cannot remove this item type: $($item.Type)" }
    }
}

function Show-Menu {
    Clear-Host
    Write-Host "====================================`n PSSM - PowerShell Startup Manager`n===================================="
    Write-Host "1. List startup items"
    Write-Host "2. Disable a registry startup item"
    Write-Host "3. Re-enable a registry startup item"
    Write-Host "4. Remove a startup item"
    Write-Host "5. Exit"
    Write-Host "===================================="
}

# ----------------------------
# Main Loop
# ----------------------------
$running = $true
do {
    Show-Menu
    $choice = Read-Host "Enter your choice (1-5)"
    Get-StartupItems

    switch ($choice){
        "1" { List-Startup; Pause }
        "2" { Disable-RegistryItem; Pause }
        "3" { Reenable-RegistryItem; Pause }
        "4" { Remove-StartupItem; Pause }
        "5" { $running = $false }
        default { Write-Host "Invalid choice. Try again."; Pause }
    }
} while ($running)
