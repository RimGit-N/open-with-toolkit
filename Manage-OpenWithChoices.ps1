$ErrorActionPreference = 'Stop'
$script:BackupDir = Join-Path $PSScriptRoot 'OpenWith-Backups'

function Write-Title([string]$Text) {
    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor DarkCyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host ('=' * 72) -ForegroundColor DarkCyan
}
function Read-NonEmpty([string]$Prompt, [string]$Default = '') {
    while ($true) {
        if ($Default) {
            $value = Read-Host "$Prompt [$Default]"
            if ([string]::IsNullOrWhiteSpace($value)) { $value = $Default }
        } else { $value = Read-Host $Prompt }
        if (-not [string]::IsNullOrWhiteSpace($value)) { return $value.Trim().Trim('"') }
        Write-Host 'Input tidak boleh kosong.' -ForegroundColor Yellow
    }
}
function Read-Extension([string]$Prompt = 'Ekstensi file (contoh .php)') {
    $e = Read-NonEmpty $Prompt '.php'
    if (-not $e.StartsWith('.')) { $e = ".$e" }
    if ($e -notmatch '^\.[A-Za-z0-9][A-Za-z0-9._-]*$') { throw "Ekstensi tidak valid: $e" }
    return $e.ToLowerInvariant()
}
function Read-DefaultValue([Microsoft.Win32.RegistryKey]$Key) {
    if (-not $Key) { return '' }
    try { return [string]$Key.GetValue('') } catch { return '' }
}
function Get-UserChoiceEntries {
    $results = New-Object System.Collections.Generic.List[object]
    $rootPath = 'Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts'
    $root = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($rootPath)
    if ($root) {
        try {
            foreach ($ext in $root.GetSubKeyNames()) {
                $uc = $root.OpenSubKey("$ext\UserChoice")
                if (-not $uc) { continue }
                try {
                    $progId = [string]$uc.GetValue('ProgId', '')
                    $hash = [string]$uc.GetValue('Hash', '')
                    $results.Add([pscustomobject]@{
                        Extension=$ext; ProgId=$progId; HashPresent=[bool]$hash
                        RegistryPath="HKCU\$rootPath\$ext\UserChoice"
                    })
                } finally { $uc.Dispose() }
            }
        } finally { $root.Dispose() }
    }
    return @($results | Sort-Object Extension)
}
function Export-UserChoiceReport {
    $entries = @(Get-UserChoiceEntries)
    if (-not (Test-Path -LiteralPath $script:BackupDir)) { New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $csv = Join-Path $script:BackupDir "UserChoice-$stamp.csv"
    $txt = Join-Path $script:BackupDir "UserChoice-$stamp.txt"
    $entries | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8
    $lines = @("UserChoice scan: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')", "Count: $($entries.Count)", "NOTE: Hash values are never exported.")
    foreach ($e in $entries) {
        $hs = if ($e.HashPresent) { 'Hash present' } else { 'Hash missing' }
        $lines += ("{0}`tProgId={1}`t{2}`t{3}" -f $e.Extension,$e.ProgId,$hs,$e.RegistryPath)
    }
    $lines | Set-Content -LiteralPath $txt -Encoding UTF8
    Write-Host "Ditemukan $($entries.Count) ekstensi UserChoice." -ForegroundColor Green
    Write-Host "CSV: $csv"
    Write-Host "TXT: $txt"
    return $entries
}
function Add-Choice {
    param([System.Collections.Generic.List[object]]$List,[string]$Label,[string]$Kind,[string]$Hive,[string]$SubPath,[string]$ValueName,[string]$Detail,[bool]$Deletable=$false)
    $List.Add([pscustomobject]@{Label=$Label;Kind=$Kind;Hive=$Hive;SubPath=$SubPath;ValueName=$ValueName;Detail=$Detail;Deletable=$Deletable})
}
function Get-OpenWithChoices([string]$Extension) {
    $choices = New-Object System.Collections.Generic.List[object]
    $fileExtPath = "Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension"
    $root = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($fileExtPath)
    if ($root) {
        try {
            $owl = $root.OpenSubKey('OpenWithList')
            if ($owl) {
                try {
                    foreach ($name in ($owl.GetValueNames() | Where-Object { $_ -match '^[a-z]$' } | Sort-Object)) {
                        $value = [string]$owl.GetValue($name, '')
                        if ($value) { Add-Choice $choices $value 'OpenWithList' 'HKCU' "$fileExtPath\OpenWithList" $name "slot '$name'" $true }
                    }
                } finally { $owl.Dispose() }
            }
            $owp = $root.OpenSubKey('OpenWithProgids')
            if ($owp) {
                try {
                    foreach ($name in $owp.GetValueNames()) { Add-Choice $choices $name 'OpenWithProgids' 'HKCU' "$fileExtPath\OpenWithProgids" $name 'ProgID entry' $true }
                } finally { $owp.Dispose() }
            }
            $uc = $root.OpenSubKey('UserChoice')
            if ($uc) {
                try {
                    $progId = [string]$uc.GetValue('ProgId','')
                    $hash = [string]$uc.GetValue('Hash','')
                    Add-Choice $choices $progId 'UserChoice' 'HKCU' $null '' "Default selection; Hash present=$([bool]$hash). Read-only." $false
                } finally { $uc.Dispose() }
            }
        } finally { $root.Dispose() }
    }

    foreach ($reg in @(
        @{Hive='HKCU';Root=[Microsoft.Win32.Registry]::CurrentUser;Base='Software\Classes\Applications';Writable=$true},
        @{Hive='HKLM';Root=[Microsoft.Win32.Registry]::LocalMachine;Base='Software\Classes\Applications';Writable=$false}
    )) {
        $apps = $reg.Root.OpenSubKey($reg.Base)
        if (-not $apps) { continue }
        try {
            foreach ($appName in $apps.GetSubKeyNames()) {
                $app = $apps.OpenSubKey($appName)
                if (-not $app) { continue }
                try {
                    $supported = $app.OpenSubKey('SupportedTypes')
                    if ($supported) {
                        try {
                            if ($supported.GetValueNames() -contains $Extension) {
                                $cmd = $app.OpenSubKey('shell\open\command')
                                $command = Read-DefaultValue $cmd
                                if ($cmd) { $cmd.Dispose() }
                                Add-Choice $choices $appName 'SupportedTypes' $reg.Hive "$($reg.Base)\$appName\SupportedTypes" $Extension $command ([bool]$reg.Writable)
                            }
                        } finally { $supported.Dispose() }
                    }
                } finally { $app.Dispose() }
            }
        } finally { $apps.Dispose() }
    }

    foreach ($reg in @(
        @{Hive='HKCU';Root=[Microsoft.Win32.Registry]::CurrentUser;Path='Software\RegisteredApplications';Writable=$true},
        @{Hive='HKLM';Root=[Microsoft.Win32.Registry]::LocalMachine;Path='Software\RegisteredApplications';Writable=$false},
        @{Hive='HKLM';Root=[Microsoft.Win32.Registry]::LocalMachine;Path='Software\WOW6432Node\RegisteredApplications';Writable=$false}
    )) {
        $registered = $reg.Root.OpenSubKey($reg.Path)
        if (-not $registered) { continue }
        try {
            foreach ($appLabel in $registered.GetValueNames()) {
                $capPath = [string]$registered.GetValue($appLabel,'')
                if (-not $capPath) { continue }
                $cap = $reg.Root.OpenSubKey($capPath)
                if (-not $cap) { continue }
                try {
                    $fa = $cap.OpenSubKey('FileAssociations')
                    if ($fa) {
                        try {
                            $progId = [string]$fa.GetValue($Extension,'')
                            if ($progId) {
                                $sub = "$capPath\FileAssociations"
                                Add-Choice $choices $appLabel 'RegisteredApplications' $reg.Hive $sub $Extension "ProgID=$progId; Capabilities=$capPath" ([bool]($reg.Writable -and $reg.Hive -eq 'HKCU'))
                            }
                        } finally { $fa.Dispose() }
                    }
                } finally { $cap.Dispose() }
            }
        } finally { $registered.Dispose() }
    }

    foreach ($reg in @(
        @{Hive='HKCU';Root=[Microsoft.Win32.Registry]::CurrentUser;Path="Software\Classes\$Extension"},
        @{Hive='HKLM';Root=[Microsoft.Win32.Registry]::LocalMachine;Path="Software\Classes\$Extension"}
    )) {
        $key = $reg.Root.OpenSubKey($reg.Path)
        if ($key) {
            try {
                $progId = Read-DefaultValue $key
                if ($progId) {
                    $cmdKey = $reg.Root.OpenSubKey("Software\Classes\$progId\shell\open\command")
                    $cmd = Read-DefaultValue $cmdKey
                    if ($cmdKey) { $cmdKey.Dispose() }
                    Add-Choice $choices $progId 'ExtensionProgID' $reg.Hive $null '' "Extension mapping; command=$cmd" $false
                }
            } finally { $key.Dispose() }
        }
    }
    return @($choices | Sort-Object Hive,SubPath,ValueName,Kind -Unique)
}
function Inspect-Extension {
    $extension = Read-Extension
    Write-Title "INSPECT EXTENSION: $extension"
    $items = @(Get-OpenWithChoices $extension)
    $uc = @(Get-UserChoiceEntries | Where-Object { $_.Extension -ieq $extension })
    if ($uc.Count) {
        foreach ($u in $uc) {
            Write-Host "UserChoice ProgId: $($u.ProgId) | Hash present: $($u.HashPresent)" -ForegroundColor Cyan
            Write-Host "Source: $($u.RegistryPath)" -ForegroundColor DarkGray
        }
    } else { Write-Host 'Tidak ada UserChoice untuk ekstensi ini.' -ForegroundColor Yellow }
    if (-not $items.Count) { Write-Host 'Tidak ditemukan entri lain dari sumber yang diperiksa.' -ForegroundColor Yellow; return }
    for ($i=0; $i -lt $items.Count; $i++) {
        $c=$items[$i]
        $perm=if($c.Deletable){'HKCU - bisa dipilih untuk hapus'}else{'READ-ONLY'}
        Write-Host ("[{0}] {1} | {2} | {3}" -f ($i+1),$c.Label,$c.Kind,$perm) -ForegroundColor White
        if($c.Hive -and $c.SubPath){Write-Host "    Registry: $($c.Hive)\$($c.SubPath)" -ForegroundColor DarkGray}
        if($c.ValueName){Write-Host "    Value: $($c.ValueName)" -ForegroundColor DarkGray}
        if($c.Detail){Write-Host "    Detail: $($c.Detail)" -ForegroundColor DarkGray}
    }
}
function Backup-RegistryKey([string]$Hive,[string]$SubPath) {
    if (-not (Test-Path -LiteralPath $script:BackupDir)) { New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null }
    $stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
    $safe=($SubPath -replace '[\\/:*?"<>|]','_')
    $file=Join-Path $script:BackupDir "$stamp-$Hive-$safe.reg"
    $regPath="$Hive\$SubPath"
    # Windows PowerShell 5.1 joins ArgumentList arrays into one command line;
    # quote both paths explicitly so folders containing spaces work correctly.
    $regExe = Join-Path $env:SystemRoot 'System32\reg.exe'
    $arguments = 'export "{0}" "{1}" /y' -f $regPath, $file
    $proc=Start-Process -FilePath $regExe -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
    if ($proc.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $file)) {
        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue }
        throw "Backup registry gagal untuk $regPath (reg.exe exit code $($proc.ExitCode)). Penghapusan dibatalkan. Periksa apakah key masih ada dan folder backup bisa ditulisi."
    }
    return $file
}
function Manage-OpenWith {
    $extension=Read-Extension
    Write-Title "MANAGE OPEN WITH: $extension"
    $choices=@(Get-OpenWithChoices $extension)
    if(-not $choices.Count){Write-Host 'Tidak ada entri yang ditemukan.' -ForegroundColor Yellow;return}
    for($i=0;$i -lt $choices.Count;$i++){
        $c=$choices[$i];$perm=if($c.Deletable -and $c.Hive -eq 'HKCU' -and $c.SubPath -and $c.ValueName){'DELETE ENABLED (HKCU)'}else{'READ-ONLY'}
        Write-Host ("[{0}] {1} | {2} | {3}" -f ($i+1),$c.Label,$c.Kind,$perm)
        if($c.SubPath){Write-Host "    HKCU/HKLM\$($c.SubPath)" -ForegroundColor DarkGray}
        if($c.ValueName){Write-Host "    Value: $($c.ValueName)" -ForegroundColor DarkGray}
        if($c.Detail){Write-Host "    $($c.Detail)" -ForegroundColor DarkGray}
    }
    Write-Host 'Hanya value spesifik HKCU yang diizinkan. UserChoice/Hash, HKLM, aplikasi, dan command tidak dihapus.' -ForegroundColor Yellow
    $selection=Read-Host 'Nomor yang akan dihapus (Enter untuk batal)'
    if([string]::IsNullOrWhiteSpace($selection)){Write-Host 'Dibatalkan.' -ForegroundColor Yellow;return}
    $idx=0
    if(-not [int]::TryParse($selection,[ref]$idx) -or $idx -lt 1 -or $idx -gt $choices.Count){throw 'Nomor pilihan tidak valid.'}
    $c=$choices[$idx-1]
    if(-not $c.Deletable -or $c.Hive -ne 'HKCU' -or -not $c.SubPath -or -not $c.ValueName){Write-Host 'Item ini read-only; tidak ada perubahan.' -ForegroundColor Yellow;return}
    Write-Host "Akan menghapus HKCU\$($c.SubPath) -> value '$($c.ValueName)'." -ForegroundColor Yellow
    $confirm=Read-Host 'Ketik HAPUS untuk melanjutkan'
    if($confirm -cne 'HAPUS'){Write-Host 'Dibatalkan.' -ForegroundColor Yellow;return}
    $backup=Backup-RegistryKey 'HKCU' $c.SubPath
    Write-Host "Backup dibuat: $backup" -ForegroundColor Green
    $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($c.SubPath,$true)
    if(-not $key){throw 'Key registry tidak ditemukan; tidak ada penghapusan.'}
    try{
        $key.DeleteValue($c.ValueName,$false)
        if($c.Kind -eq 'OpenWithList'){
            $remaining=@($key.GetValueNames() | Where-Object {$_ -match '^[a-z]$'})
            $mru=[string]$key.GetValue('MRUList','');$newMru=''
            foreach($ch in $mru.ToCharArray()){ $letter=[string]$ch;if(($remaining -contains $letter)-and -not $newMru.Contains($letter)){$newMru+=$letter} }
            foreach($letter in ($remaining | Sort-Object)){if(-not $newMru.Contains([string]$letter)){$newMru+=[string]$letter}}
            if($newMru){$key.SetValue('MRUList',$newMru,[Microsoft.Win32.RegistryValueKind]::String)}else{$key.DeleteValue('MRUList',$false)}
        }
    } finally {$key.Dispose()}
    $verify=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($c.SubPath)
    $still=$false
    if($verify){try{$still=$verify.GetValueNames() -contains $c.ValueName}finally{$verify.Dispose()}}
    if($still){throw 'Verifikasi gagal: value masih ditemukan setelah penghapusan.'}
    Write-Host 'VERIFIKASI PASS: value sudah tidak ada. Backup registry tersedia untuk pemulihan manual.' -ForegroundColor Green
}
function Search-App {
    $query=Read-NonEmpty 'Nama aplikasi, executable, atau kata kunci'
    Write-Title "SEARCH APP: $query"
    $results=New-Object System.Collections.Generic.List[object]
    $roots=@(
        @{Hive='HKCU';Root=[Microsoft.Win32.Registry]::CurrentUser;Path='Software\Classes\Applications';Mode='Subkeys'},
        @{Hive='HKLM';Root=[Microsoft.Win32.Registry]::LocalMachine;Path='Software\Classes\Applications';Mode='Subkeys'},
        @{Hive='HKCU';Root=[Microsoft.Win32.Registry]::CurrentUser;Path='Software\Microsoft\Windows\CurrentVersion\App Paths';Mode='Subkeys'},
        @{Hive='HKLM';Root=[Microsoft.Win32.Registry]::LocalMachine;Path='Software\Microsoft\Windows\CurrentVersion\App Paths';Mode='Subkeys'},
        @{Hive='HKCU';Root=[Microsoft.Win32.Registry]::CurrentUser;Path='Software\RegisteredApplications';Mode='Values'},
        @{Hive='HKLM';Root=[Microsoft.Win32.Registry]::LocalMachine;Path='Software\RegisteredApplications';Mode='Values'},
        @{Hive='HKLM';Root=[Microsoft.Win32.Registry]::LocalMachine;Path='Software\WOW6432Node\RegisteredApplications';Mode='Values'},
        @{Hive='HKCU';Root=[Microsoft.Win32.Registry]::CurrentUser;Path='Software\Microsoft\Windows\CurrentVersion\Uninstall';Mode='Subkeys'},
        @{Hive='HKLM';Root=[Microsoft.Win32.Registry]::LocalMachine;Path='Software\Microsoft\Windows\CurrentVersion\Uninstall';Mode='Subkeys'},
        @{Hive='HKLM';Root=[Microsoft.Win32.Registry]::LocalMachine;Path='Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall';Mode='Subkeys'}
    )
    foreach($r in $roots){
        $key=$r.Root.OpenSubKey($r.Path);if(-not $key){continue}
        try{
            if($r.Mode -eq 'Values'){
                foreach($vn in $key.GetValueNames()){
                    $vv=[string]$key.GetValue($vn,'')
                    if("$vn $vv" -like "*$query*"){$results.Add([pscustomobject]@{Source="$($r.Hive)\$($r.Path)";Name=$vn;Detail=$vv})}
                }
            }else{
                foreach($sn in $key.GetSubKeyNames()){
                    $sub=$key.OpenSubKey($sn);if(-not $sub){continue}
                    try{
                        $details=New-Object System.Collections.Generic.List[string]
                        foreach($vn in @('DisplayName','ApplicationName','InstallLocation','DisplayIcon','UninstallString')){
                            $vv=[string]$sub.GetValue($vn,'')
                            if($vv){$details.Add("$vn=$vv")}
                        }
                        $cmd=$sub.OpenSubKey('shell\open\command')
                        if($cmd){$vv=Read-DefaultValue $cmd;if($vv){$details.Add("OpenCommand=$vv")};$cmd.Dispose()}
                        $joined=$details -join ' | '
                        if("$sn $joined" -like "*$query*"){$results.Add([pscustomobject]@{Source="$($r.Hive)\$($r.Path)\$sn";Name=$sn;Detail=$joined})}
                    }finally{$sub.Dispose()}
                }
            }
        }finally{$key.Dispose()}
    }
    # Search current-user Appx package registrations when the cmdlet is available.
    try{
        if(Get-Command Get-AppxPackage -ErrorAction SilentlyContinue){
            foreach($pkg in @(Get-AppxPackage -ErrorAction SilentlyContinue)){
                $txt="$($pkg.Name) $($pkg.PackageFullName) $($pkg.InstallLocation)"
                if($txt -like "*$query*"){$results.Add([pscustomobject]@{Source='Appx package (current user)';Name=$pkg.Name;Detail="$($pkg.PackageFullName) | $($pkg.InstallLocation)"})}
            }
        }
    }catch{}
    $unique=@($results | Sort-Object Source,Name,Detail -Unique)
    if(-not $unique.Count){Write-Host 'Tidak ada kecocokan pada sumber yang dipindai. Ini bukan bukti mutlak aplikasi tidak terpasang.' -ForegroundColor Yellow;return}
    foreach($r in $unique){Write-Host "[MATCH] $($r.Name)" -ForegroundColor Green;Write-Host "  $($r.Source)" -ForegroundColor DarkGray;if($r.Detail){Write-Host "  $($r.Detail)"}}
    if(-not (Test-Path -LiteralPath $script:BackupDir)){New-Item -ItemType Directory -Path $script:BackupDir -Force|Out-Null}
    $out=Join-Path $script:BackupDir ("AppSearch-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $unique | Export-Csv -LiteralPath $out -NoTypeInformation -Encoding UTF8
    Write-Host "Hasil diekspor: $out" -ForegroundColor Cyan
}
function Show-Menu {
    while($true){
        Write-Title 'OPEN WITH TOOLKIT v7 - UNIVERSAL REGISTRY INSPECTOR'
        Write-Host '1. Scan semua UserChoice + export CSV/TXT (read-only)'
        Write-Host '2. Inspect Extension (UserChoice, ProgID, Open With, command)'
        Write-Host '3. Manage Open With (hapus value HKCU tertentu + backup + verifikasi)'
        Write-Host '4. Search App (Applications, App Paths, RegisteredApplications, Uninstall, Appx)'
        Write-Host '5. Keluar'
        $pick=Read-Host 'Pilih menu'
        try{
            switch($pick){
                '1' { $null=Export-UserChoiceReport; Read-Host 'Tekan Enter untuk kembali'|Out-Null }
                '2' { Inspect-Extension; Read-Host 'Tekan Enter untuk kembali'|Out-Null }
                '3' { Manage-OpenWith; Read-Host 'Tekan Enter untuk kembali'|Out-Null }
                '4' { Search-App; Read-Host 'Tekan Enter untuk kembali'|Out-Null }
                '5' { return }
                default { Write-Host 'Pilihan tidak valid.' -ForegroundColor Yellow }
            }
        }catch{Write-Host "GAGAL: $($_.Exception.Message)" -ForegroundColor Red;Write-Host 'Jika operasi mengubah registry, hasil harus lolos verifikasi sebelum dinyatakan berhasil.' -ForegroundColor Yellow;Read-Host 'Tekan Enter untuk kembali'|Out-Null}
    }
}
Write-Host 'Mode aman: UserChoice/Hash tidak pernah diubah; pencarian bersifat read-only.' -ForegroundColor Yellow
Show-Menu
