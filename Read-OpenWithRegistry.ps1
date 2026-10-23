$ErrorActionPreference = 'Stop'

function Get-RegKeyValue {
    param([Microsoft.Win32.RegistryKey]$Root, [string]$SubPath, [string]$Name = '')
    $key = $null
    try {
        $key = $Root.OpenSubKey($SubPath)
        if ($null -eq $key) { return $null }
        return $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    } finally { if ($key) { $key.Dispose() } }
}
function Show-RegValue {
    param([string]$Label, $Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { Write-Host "$Label : [tidak ada]" }
    else { Write-Host "$Label : $Value" }
}

try {
    $extensionInput = Read-Host 'Ekstensi yang mau dibaca (contoh .json; Enter = .json)'
    if ([string]::IsNullOrWhiteSpace($extensionInput)) { $extensionInput = '.json' }
    $extensionInput = $extensionInput.Trim().Trim('"')
    if (-not $extensionInput.StartsWith('.')) { $extensionInput = ".$extensionInput" }
    if ($extensionInput -notmatch '^\.[A-Za-z0-9][A-Za-z0-9._-]*$') { throw "Format ekstensi tidak valid: $extensionInput" }
    $extension = $extensionInput.ToLowerInvariant()

    $fileExtSubPath = "Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$extension"
    $userClassesExt = "Software\Classes\$extension"
    $machineClassesExt = "Software\Classes\$extension"
    $fileExtKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($fileExtSubPath)

    Write-Host ''
    Write-Host "=== Open With Registry Reader: $extension ===" -ForegroundColor Cyan
    Write-Host 'Mode: READ-ONLY; tidak mengubah Registry.' -ForegroundColor DarkGray
    Write-Host 'Registry path yang dibaca:' -ForegroundColor Cyan
    Write-Host "  HKCU\$fileExtSubPath"
    Write-Host "  HKCU\$fileExtSubPath\UserChoice"
    Write-Host "  HKCU\$fileExtSubPath\OpenWithList"
    Write-Host "  HKCU\$fileExtSubPath\OpenWithProgids"
    Write-Host "  HKCU\$userClassesExt (per-user class registration)"
    Write-Host "  HKLM\$machineClassesExt (machine class registration)"
    Write-Host "  HKCR\$extension (effective/merged extension association)"
    Write-Host '  HKCR\<ProgID>\shell\open\command (effective open command)'
    Write-Host '  HKCU/HKLM\Software\Classes\<ProgID>\shell\open\command'
    Write-Host "  HKCU\Software\Classes\Applications\<app>\SupportedTypes dan shell\open\command"
    Write-Host ''

    $userChoiceProgId = $null
    if ($fileExtKey) {
        Write-Host '[FileExts\UserChoice]' -ForegroundColor Yellow
        $uc = $fileExtKey.OpenSubKey('UserChoice')
        if ($uc) {
            $userChoiceProgId = $uc.GetValue('ProgId', $null)
            $hash = $uc.GetValue('Hash', $null)
            Show-RegValue 'ProgId' $userChoiceProgId
            Write-Host ("Hash : " + $(if ($hash) { '[ada; disamarkan]' } else { '[tidak ada]' }))
            $uc.Dispose()
        } else { Write-Host 'UserChoice: tidak ada' }

        Write-Host ''
        Write-Host '[OpenWithList]' -ForegroundColor Yellow
        $owl = $fileExtKey.OpenSubKey('OpenWithList')
        if ($owl) {
            $slots = @($owl.GetValueNames() | Where-Object { $_ -match '^[a-z]$' } | Sort-Object)
            if ($slots.Count -eq 0) { Write-Host '(belum ada slot aplikasi)' }
            foreach ($slot in $slots) { Write-Host ("{0} : {1}" -f $slot, $owl.GetValue($slot)) }
            Show-RegValue 'MRUList' ($owl.GetValue('MRUList', $null))
            $owl.Dispose()
        } else { Write-Host 'OpenWithList: tidak ada' }

        Write-Host ''
        Write-Host '[OpenWithProgids]' -ForegroundColor Yellow
        $owp = $fileExtKey.OpenSubKey('OpenWithProgids')
        if ($owp) {
            $names = @($owp.GetValueNames())
            if ($names.Count -eq 0) { Write-Host '(kosong)' }
            foreach ($name in $names) { Write-Host ("{0} (jenis nilai: {1})" -f $name, $owp.GetValueKind($name)) }
            $owp.Dispose()
        } else { Write-Host 'OpenWithProgids: tidak ada' }
        $fileExtKey.Dispose()
    } else { Write-Host "FileExts key tidak ditemukan untuk $extension" -ForegroundColor DarkYellow }

    Write-Host ''
    Write-Host '[Extension association: HKCU / HKLM / HKCR]' -ForegroundColor Yellow
    $hkcuExt = Get-RegKeyValue -Root ([Microsoft.Win32.Registry]::CurrentUser) -SubPath $userClassesExt
    $hklmExt = Get-RegKeyValue -Root ([Microsoft.Win32.Registry]::LocalMachine) -SubPath $machineClassesExt
    $hkcrExt = Get-RegKeyValue -Root ([Microsoft.Win32.Registry]::ClassesRoot) -SubPath $extension
    Show-RegValue "HKCU\$userClassesExt (default ProgID)" $hkcuExt
    Show-RegValue "HKLM\$machineClassesExt (default ProgID)" $hklmExt
    Show-RegValue "HKCR\$extension (effective default ProgID)" $hkcrExt

    $effectiveProgId = if (-not [string]::IsNullOrWhiteSpace([string]$userChoiceProgId)) { [string]$userChoiceProgId }
                       elseif (-not [string]::IsNullOrWhiteSpace([string]$hkcrExt)) { [string]$hkcrExt }
                       else { $null }
    Write-Host ''
    Write-Host '[Effective default / open command]' -ForegroundColor Yellow
    if ($userChoiceProgId) { Write-Host 'Sumber pilihan: UserChoice\ProgId (user-specific choice)' }
    elseif ($hkcrExt) { Write-Host 'Sumber fallback: HKCR extension default (merged classes association)' }
    else { Write-Host 'Sumber pilihan: tidak dapat ditentukan dari key yang ditemukan' }
    Show-RegValue 'Effective ProgID' $effectiveProgId
    if ($effectiveProgId) {
        $progCommandPath = "$effectiveProgId\shell\open\command"
        $userProgCommand = Get-RegKeyValue -Root ([Microsoft.Win32.Registry]::CurrentUser) -SubPath ("Software\Classes\$progCommandPath")
        $machineProgCommand = Get-RegKeyValue -Root ([Microsoft.Win32.Registry]::LocalMachine) -SubPath ("Software\Classes\$progCommandPath")
        $effectiveCommand = Get-RegKeyValue -Root ([Microsoft.Win32.Registry]::ClassesRoot) -SubPath $progCommandPath
        Show-RegValue "HKCU\Software\Classes\$progCommandPath (command)" $userProgCommand
        Show-RegValue "HKLM\Software\Classes\$progCommandPath (command)" $machineProgCommand
        Show-RegValue "HKCR\$progCommandPath (effective command)" $effectiveCommand
    }

    Write-Host ''
    Write-Host '[Registered Applications matching extension]' -ForegroundColor Yellow
    $appsKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Classes\Applications')
    $foundApps = 0
    if ($appsKey) {
        foreach ($appName in $appsKey.GetSubKeyNames()) {
            $appKey = $appsKey.OpenSubKey($appName)
            if (-not $appKey) { continue }
            $supported = $appKey.OpenSubKey('SupportedTypes')
            if ($supported -and ($supported.GetValueNames() -contains $extension)) {
                $commandKey = $appKey.OpenSubKey('shell\open\command')
                $command = if ($commandKey) { $commandKey.GetValue('') } else { $null }
                Write-Host ("HKCU\Software\Classes\Applications\{0} -> {1}" -f $appName, $command)
                $foundApps++
                if ($commandKey) { $commandKey.Dispose() }
            }
            if ($supported) { $supported.Dispose() }
            $appKey.Dispose()
        }
        $appsKey.Dispose()
    }
    if ($foundApps -eq 0) { Write-Host '(tidak ditemukan aplikasi per-user dengan SupportedTypes untuk ekstensi ini)' }

    Write-Host ''
    Write-Host 'Catatan:' -ForegroundColor Cyan
    Write-Host '- HKCR adalah tampilan gabungan HKCU\Software\Classes dan HKLM\Software\Classes.'
    Write-Host '- UserChoice\ProgId, jika ada, diprioritaskan untuk pilihan user; Hash tidak ditampilkan.'
    Write-Host '- Untuk ekstensi .bat, ProgID umumnya batfile; perintah aktual ditampilkan dari HKCR\batfile\shell\open\command.'
    Write-Host '- Reader ini read-only.'
}
catch {
    Write-Host ''
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ''
Read-Host 'Tekan Enter untuk menutup'
