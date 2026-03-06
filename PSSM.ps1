# =========================
# PSSM - PowerShell Startup Manager
# =========================

# Global variable to hold startup entries
$Global:StartupEntries = @()

# ----------------------------
# Functions
# ----------------------------
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
        Write-Host ("[{0}] {1,-20} | {2,-18} | {3}" -f $i, $_.Type, $_.Name, $_.Command)
        $i++
    }
    Write-Host "`nTotal: $($Global:StartupEntries.Count)`n"
}

function Disable-RegistryItem {
    # List only registry entries
    $regItems = $Global:StartupEntries | Where-Object { $_.Type -like "Registry*" }
    if($regItems.Count -eq 0){
        Write-Host "No registry startup items to disable."
        return
    }

    Write-Host "`nRegistry Startup Items:`n"
    $i = 1
    $regItems | ForEach-Object {
        Write-Host ("[{0}] {1,-18} | {2,-20} | {3}" -f $i, $_.Type, $_.Name, $_.Command)
        $i++
    }

    $entryNum = Read-Host "Enter the number of the registry item to disable (or Enter to cancel)"
    if(-not [int]::TryParse($entryNum,[ref]$null)){
        Write-Host "Cancelled."
        return
    }
    $entryNum = [int]$entryNum
    if($entryNum -le 0 -or $entryNum -gt $regItems.Count){
        Write-Host "Invalid number."
        return
    }

    $item = $regItems[$entryNum-1]
    $newName = "_DISABLED_$($item.Name)"
    $path = if($item.Type -eq "Registry (CU)") { "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" } else { "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" }
    Rename-ItemProperty -Path $path -Name $item.Name -NewName $newName
    Write-Host "Disabled $($item.Name) (renamed to $newName)."
}

function Remove-StartupItem {
    $entryNum = Read-Host "Enter the entry number to remove (or press Enter to cancel)"
    if(-not [int]::TryParse($entryNum,[ref]$null)){
        Write-Host "Cancelled."
        return
    }
    $entryNum = [int]$entryNum
    if($entryNum -le 0 -or $entryNum -gt $Global:StartupEntries.Count){
        Write-Host "Invalid number."
        return
    }

    $item = $Global:StartupEntries[$entryNum-1]

    switch ($item.Type){
        "Registry (CU)" {
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $item.Name -ErrorAction SilentlyContinue
            Write-Host "Removed $($item.Name) from Current User Registry Run."
        }
        "Registry (LM)" {
            Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $item.Name -ErrorAction SilentlyContinue
            Write-Host "Removed $($item.Name) from Local Machine Registry Run."
        }
        "Startup Folder (CU)" {
            Remove-Item $item.Command -ErrorAction SilentlyContinue
            Write-Host "Removed $($item.Name) from Current User Startup folder."
        }
        "Startup Folder (All)" {
            Remove-Item $item.Command -ErrorAction SilentlyContinue
            Write-Host "Removed $($item.Name) from All Users Startup folder."
        }
        "Scheduled Task" {
            schtasks /delete /tn $item.Name /f | Out-Null
            Write-Host "Removed scheduled task $($item.Name)."
        }
        default {
            Write-Host "Cannot remove this item type: $($item.Type)"
        }
    }
}

function Show-Menu {
    Clear-Host
    Write-Host "=============================="
    Write-Host " PSSM - PowerShell Startup Manager"
    Write-Host "=============================="
    Write-Host "1. List startup items"
    Write-Host "2. Disable a registry startup item"
    Write-Host "3. Remove a startup item"
    Write-Host "4. Exit"
    Write-Host "=============================="
}

# ----------------------------
# Main Loop
# ----------------------------
do {
    Show-Menu
    $choice = Read-Host "Enter your choice (1-4)"

    # Refresh global entries each loop
    Get-StartupItems

    switch ($choice){
        "1" { List-Startup; Pause }
        "2" { Disable-RegistryItem; Pause }
        "3" { Remove-StartupItem; Pause }
        "4" { break }
        default { Write-Host "Invalid choice. Try again."; Pause }
    }
} while ($true)
