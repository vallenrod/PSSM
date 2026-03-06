param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("list","disable","remove","help")]
    [string]$Command = "help",

    [int]$Entry
)

# Global variable to hold the combined list
$Global:StartupEntries = @()

# ----------------------------
# Functions
# ----------------------------
function Show-Help {
    Write-Host @"
PSSM - PowerShell Startup Manager

Usage:
    PSSM.ps1 list               - List all startup items
    PSSM.ps1 remove <number>    - Remove or disable a startup item by its number
    PSSM.ps1 help               - Show this help
"@
}

function Get-StartupItems {
    $entries = @()

    # Registry Run keys (Current User)
    if (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run") {
        Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" | ForEach-Object {
            $_.PSObject.Properties |
            Where-Object { $_.Name -ne "PSPath" -and $_.Name -ne "PSParentPath" -and $_.Name -ne "PSChildName" -and $_.Name -ne "PSDrive" -and $_.Name -ne "PSProvider"} |
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
            Where-Object { $_.Name -ne "PSPath" -and $_.Name -ne "PSParentPath" -and $_.Name -ne "PSChildName" -and $_.Name -ne "PSDrive" -and $_.Name -ne "PSProvider"} |
            ForEach-Object {
                $entries += [PSCustomObject]@{
                    Type = "Registry (LM)"
                    Name = $_.Name
                    Command = $_.Value
                }
            }
        }
    }

    # Startup folders (Current User)
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

    # Startup folders (All Users)
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
        $num = $i
        $i++
        # Adjust formatting for terminal width
        Write-Host ("[{0}] {1,-20} | {2,-18} | {3}" -f $num, $_.Type, $_.Name, $_.Command)
    }
    Write-Host "`nTotal: $($Global:StartupEntries.Count)`n"
}

function Remove-StartupItem {
    if(-not $Entry){
        Write-Host "Please provide an entry number to remove."
        return
    }
    if(-not $Global:StartupEntries){
        Get-StartupItems
    }
    if($Entry -le 0 -or $Entry -gt $Global:StartupEntries.Count){
        Write-Host "Invalid entry number."
        return
    }

    $item = $Global:StartupEntries[$Entry-1]

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

# ----------------------------
# Command Dispatcher
# ----------------------------
switch ($Command){
    "list" { List-Startup }
    "remove" { Remove-StartupItem }
    "help" { Show-Help }
    default { Show-Help }
}
