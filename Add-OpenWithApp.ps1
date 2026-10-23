$ErrorActionPreference = 'Stop'

function Read-NonEmpty([string]$Prompt, [string]$Default = '') {
    while ($true) {
        if ($Default) {
            $value = Read-Host "$Prompt [$Default]"
            if ([string]::IsNullOrWhiteSpace($value)) { $value = $Default }
        } else {
            $value = Read-Host $Prompt
        }
        if (-not [string]::IsNullOrWhiteSpace($value)) { return $value.Trim().Trim('"') }
        Write-Host 'Input tidak boleh kosong.' -ForegroundColor Yellow
    }
}

try {
    Write-Host ''
    Write-Host '=== Add Open With App (HKCU, incremental) ===' -ForegroundColor Cyan
    Write-Host 'Menambahkan aplikasi ke menu Open with; tidak mengubah default app.'
    Write-Host ''

    $exeInput = Read-NonEmpty 'Path lengkap executable (.exe), contoh C:\Program Files\Notepad++\notepad++.exe'
    $exePath = [Environment]::ExpandEnvironmentVariables($exeInput)
    if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) { throw "Executable tidak ditemukan: $exePath" }
    if ([IO.Path]::GetExtension($exePath) -ine '.exe') { throw 'Path harus menunjuk ke file .exe.' }

    $extInput = Read-NonEmpty 'Ekstensi file (contoh .json)' '.json'
    if (-not $extInput.StartsWith('.')) { $extInput = ".$extInput" }
    if ($extInput -notmatch '^\.[A-Za-z0-9][A-Za-z0-9._-]*$') { throw "Ekstensi tidak valid: $extInput" }
    $extension = $extInput.ToLowerInvariant()
    $exeName = [IO.Path]::GetFileName($exePath)

    $appKey = "HKCU:\Software\Classes\Applications\$exeName"
    $commandKey = Join-Path $appKey 'shell\open\command'
    $supportedKey = Join-Path $appKey 'SupportedTypes'
    $fileExtKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$extension"
    $openWithListKey = Join-Path $fileExtKey 'OpenWithList'

    # Show exact Registry paths before touching anything.
    $appRegPath = "HKCU\Software\Classes\Applications\$exeName"
    $extRegPath = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$extension"
    $commandRegPath = "$appRegPath\shell\open\command"
    $supportedRegPath = "$appRegPath\SupportedTypes"
    $openWithListRegPath = "$extRegPath\OpenWithList"

    # Read the currently effective association for context; this is read-only.
    $effectiveExtKey = [Microsoft.Win32.Registry]::ClassesRoot.OpenSubKey($extension)
    $effectiveProgId = if ($effectiveExtKey) { [string]$effectiveExtKey.GetValue('') } else { '' }
    if ($effectiveExtKey) { $effectiveExtKey.Dispose() }
    $effectiveCommand = $null
    if (-not [string]::IsNullOrWhiteSpace($effectiveProgId)) {
        $effectiveCommandKey = [Microsoft.Win32.Registry]::ClassesRoot.OpenSubKey("$effectiveProgId\shell\open\command")
        if ($effectiveCommandKey) { $effectiveCommand = $effectiveCommandKey.GetValue(''); $effectiveCommandKey.Dispose() }
    }

    Write-Host 'Registry yang akan dibaca/diubah:' -ForegroundColor Cyan
    Write-Host "  BACA  : $appRegPath (cek/backup jika sudah ada)"
    Write-Host "  BACA  : $extRegPath (cek/backup jika sudah ada)"
    Write-Host "  BACA  : HKCR\$extension (asosiasi efektif saat ini; read-only)"
    if ($effectiveProgId) {
        Write-Host "  BACA  : HKCR\$effectiveProgId\shell\open\command (command efektif saat ini; read-only)"
        Write-Host "  INFO  : ProgID saat ini = $effectiveProgId"
        Write-Host "  INFO  : Command saat ini = $(if ($effectiveCommand) { $effectiveCommand } else { '[command tidak ditemukan]' })"
    } else {
        Write-Host "  INFO  : HKCR\$extension belum memiliki default ProgID yang terbaca."
    }
    Write-Host "  TULIS : $commandRegPath (command untuk membuka file)"
    Write-Host "  TULIS : $supportedRegPath\$extension (registrasi ekstensi aplikasi)"
    Write-Host "  TULIS : $openWithListRegPath\<slot a-z> (daftar Open With; hanya jika slot baru diperlukan)"
    Write-Host "  TULIS : $openWithListRegPath\MRUList (urutan daftar Open With)"
    Write-Host '  TIDAK disentuh: UserChoice dan UserChoice\Hash' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '[Kondisi sebelum perubahan]' -ForegroundColor Yellow
    Write-Host "  HKCU\Software\Classes\$exeName\shell\open\command : $(if (Test-Path -LiteralPath $commandKey) { (Get-Item -LiteralPath $commandKey).GetValue('') } else { '[key belum ada]' })"
    Write-Host "  HKCU\Software\Classes\Applications\$exeName\SupportedTypes\$extension : $(if (Test-Path -LiteralPath $supportedKey) { if ((Get-Item -LiteralPath $supportedKey).GetValueNames() -contains $extension) { '[nilai sudah ada]' } else { '[nilai belum ada]' } } else { '[key belum ada]' })"
    Write-Host "  HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$extension\OpenWithList : $(if (Test-Path -LiteralPath $openWithListKey) { '[key ada]' } else { '[key belum ada]' })"
    Write-Host ''

    # Back up existing keys before editing. Backup files are timestamped.
    $backupDir = Join-Path $env:USERPROFILE 'Registry-OpenWith-Backups'
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    & reg.exe query $appRegPath *> $null
    if ($LASTEXITCODE -eq 0) { & reg.exe export $appRegPath (Join-Path $backupDir "Applications-$exeName-$stamp.reg") /y | Out-Null }
    & reg.exe query $extRegPath *> $null
    if ($LASTEXITCODE -eq 0) { & reg.exe export $extRegPath (Join-Path $backupDir "FileExts-$($extension.TrimStart('.'))-$stamp.reg") /y | Out-Null }

    # Register the executable command for Open With.
    New-Item -Path $commandKey -Force | Out-Null
    $command = '"' + $exePath + '" "%1"'
    Set-Item -Path $commandKey -Value $command

    # Advertise the extension for this app.
    New-Item -Path $supportedKey -Force | Out-Null
    New-ItemProperty -Path $supportedKey -Name $extension -PropertyType String -Value '' -Force | Out-Null

    # Create OpenWithList if missing.
    New-Item -Path $openWithListKey -Force | Out-Null
    $listProps = Get-ItemProperty -Path $openWithListKey
    $existingName = $null
    foreach ($prop in $listProps.PSObject.Properties) {
        if ($prop.Name -match '^[a-z]$' -and [string]$prop.Value -ieq $exeName) {
            $existingName = $prop.Name
            break
        }
    }

    if ($existingName) {
        $slot = $existingName
        Write-Host "Sudah terdaftar pada slot '$slot'; tidak membuat duplikat." -ForegroundColor Yellow
    } else {
        # Use first unused a-z slot without overwriting existing entries.
        $used = @{}
        foreach ($prop in $listProps.PSObject.Properties) {
            if ($prop.Name -match '^[a-z]$') { $used[$prop.Name.ToLowerInvariant()] = $true }
        }
        $slot = $null
        foreach ($letter in [char[]]([char]'a'..[char]'z')) {
            $candidate = [string]$letter
            if (-not $used.ContainsKey($candidate)) { $slot = $candidate; break }
        }
        if (-not $slot) { throw 'Slot a-z pada OpenWithList penuh; daftar tidak diubah.' }

        New-ItemProperty -Path $openWithListKey -Name $slot -PropertyType String -Value $exeName -Force | Out-Null
        Write-Host "Ditambahkan ke OpenWithList pada slot '$slot'." -ForegroundColor Green
    }

    # Read/write MRUList through .NET RegistryKey: SetValue creates the value
    # when absent, avoiding Windows PowerShell Registry-provider edge cases.
    $registrySubKey = 'Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\' + $extension + '\OpenWithList'
    $registryKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($registrySubKey, $true)
    if ($null -eq $registryKey) { throw "Tidak bisa membuka Registry key untuk menulis: HKCU\$registrySubKey" }
    try {
        $mruValue = $registryKey.GetValue('MRUList', '')
        $mru = if ($null -eq $mruValue) { '' } else { [string]$mruValue }
        if ([string]::IsNullOrEmpty($mru)) {
            $newMru = [string]$slot
        } elseif ($mru.Contains([string]$slot)) {
            $newMru = $mru
        } else {
            $newMru = $mru + [string]$slot
        }
        $registryKey.SetValue('MRUList', $newMru, [Microsoft.Win32.RegistryValueKind]::String)
    } finally {
        $registryKey.Dispose()
    }

    Write-Host ''
    Write-Host 'Berhasil mendaftarkan aplikasi:' -ForegroundColor Green
    Write-Host "EXE      : $exePath"
    Write-Host "Ekstensi : $extension"
    Write-Host "Slot     : $slot"
    Write-Host "Command  : $command"
    Write-Host ''
    Write-Host '[Kondisi setelah perubahan]' -ForegroundColor Yellow
    $verifyCommand = (Get-Item -LiteralPath $commandKey).GetValue('')
    $verifySupported = (Get-Item -LiteralPath $supportedKey).GetValueNames() -contains $extension
    $verifyList = Get-ItemProperty -LiteralPath $openWithListKey
    $verifySlotValue = $verifyList.PSObject.Properties[$slot].Value
    $verifyKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($registrySubKey)
    try { $verifyMru = $verifyKey.GetValue('MRUList', '') } finally { if ($verifyKey) { $verifyKey.Dispose() } }
    Write-Host "  $commandRegPath = $verifyCommand"
    Write-Host "  $supportedRegPath\$extension = $(if ($verifySupported) { '[terdaftar]' } else { '[TIDAK DITEMUKAN]' })"
    Write-Host "  $openWithListRegPath\$slot = $verifySlotValue"
    Write-Host "  $openWithListRegPath\MRUList = $verifyMru"
    Write-Host "  Verifikasi = $(if ($verifyCommand -eq $command -and $verifySupported -and $verifySlotValue -ieq $exeName) { 'LOLOS' } else { 'GAGAL' })"
    Write-Host ''
    Write-Host '[Backup]' -ForegroundColor Yellow
    Write-Host "  Folder: $backupDir"
    $backupFiles = @(Get-ChildItem -LiteralPath $backupDir -Filter "*-$stamp.reg" -ErrorAction SilentlyContinue)
    if ($backupFiles.Count -gt 0) { foreach ($file in $backupFiles) { Write-Host "  File: $($file.FullName)" } }
    else { Write-Host '  Tidak ada key lama yang perlu diekspor; belum ada file backup untuk eksekusi ini.' }
    Write-Host ''
    Write-Host 'Tutup lalu buka kembali Settings/File Explorer untuk mengecek Open with.'
    Write-Host 'Default app tidak diubah; UserChoice/Hash sengaja tidak disentuh.'
}
catch {
    Write-Host ''
    Write-Host "GAGAL: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Default app UserChoice/Hash tidak diubah.' -ForegroundColor Yellow
    exit 1
}

Write-Host ''
Read-Host 'Tekan Enter untuk menutup'
