function Show-Menu {
    Clear-Host
    Write-Host "Windows Startup Manager"
    Write-Host "======================="
    Write-Host "1. List registry startup items"
    Write-Host "2. List startup folder items"
    Write-Host "3. List logon scheduled tasks"
    Write-Host "4. Disable registry startup item"
    Write-Host "5. Remove startup folder item"
    Write-Host "6. Exit"
}

function List-RegistryStartup {
    Write-Host "`nCurrent User Run:"
    Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Run

    Write-Host "`nAll Users Run:"
    Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Run
}

function List-StartupFolder {
    $user = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    $all = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"

    Write-Host "`nUser Startup Folder:"
    Get-ChildItem $user

    Write-Host "`nAll Users Startup Folder:"
    Get-ChildItem $all
}

function List-ScheduledTasks {
    Get-ScheduledTask | Where-Object {
        $_.Triggers.TriggerType -eq "Logon"
    } | Select TaskName, State
}

function Disable-RegistryStartup {
    $name = Read-Host "Enter startup item name"
    Remove-ItemProperty `
        -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Run `
        -Name $name `
        -ErrorAction SilentlyContinue
}

function Remove-StartupFolderItem {
    $path = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    Get-ChildItem $path

    $name = Read-Host "Enter file name to delete"
    Remove-Item "$path\$name"
}

do {
    Show-Menu
    $choice = Read-Host "Select option"

    switch ($choice) {
        1 { List-RegistryStartup; Pause }
        2 { List-StartupFolder; Pause }
        3 { List-ScheduledTasks; Pause }
        4 { Disable-RegistryStartup; Pause }
        5 { Remove-StartupFolderItem; Pause }
        6 { break }
    }

} while ($true)
