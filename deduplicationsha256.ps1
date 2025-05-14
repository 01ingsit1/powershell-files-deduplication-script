$hashtable = @{}

do {
    $inputpath = Read-Host "Input path"
    $inputpath = $inputpath.Trim('"''')
} until ($inputpath -and (Test-Path -LiteralPath $inputpath))

$systemdirs = @(
    'windows'
    'program files'
    'program files (x86)'
    'programdata'
)

$normalizedpath = (Resolve-Path $inputpath).Path.ToLower()
$normalizedpath = $normalizedpath.Replace('\', '\\')

# check for system directories to prevent accidental deletion of system files
if ($systemdirs | Where-Object { $normalizedpath -match "\\$_\\?" }) {
    $soundplayer = New-Object System.Media.SoundPlayer "C:\Windows\Media\ringout.wav"
    $soundplayer.Play()

    Write-Host "CRITICAL WARNING!!! SYSTEM DIRECTORY DETECTED!!!" -ForegroundColor Red
    $confirmation = Read-Host "Type 'YES' to continue"
    if ($confirmation -ne 'YES') { exit }
}

Write-Host "WARNING!!! DUPLICATE FILES WILL BE DELETED!!! PRESS ANY KEY TO CONFIRM..." -ForegroundColor Red
Read-Host | Out-Null

$logpath = Join-Path -Path $inputpath -ChildPath 'deduplicationlog.txt'

$logheader = @(
    'Deduplication script based on sha256'
    "Working path: $inputpath"
    '-----------------------------------'
)

$logheader | Out-File -LiteralPath $logpath -Encoding utf8 -Append

$files = Get-ChildItem -R -File -LiteralPath $inputpath

$amountoffiles = $files.Count
$fileinwork = 0
$errorcount = 0
$removeerrors = [System.Collections.Generic.List[string]]::new()
$hashingerrors = [System.Collections.Generic.List[string]]::new()

foreach ($file in $files) {
    $fileinwork++

    Write-Progress -Activity "Processing files" -Status "$fileinwork of $amountoffiles" -PercentComplete ($fileinwork/$amountoffiles*100)

    try {
        $sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName -ErrorAction Stop).Hash
    } catch {
        Write-Warning "Error hashing file $($file.FullName): $_"
        $errorscount++
        $hashingerrors.Add($file.FullName)
        continue
    }

    if ($hashtable.ContainsKey($sha256)) {
        try {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            $action = "Duplicate was successfully removed"
        } catch {
            $action = "ERROR DELETING FILE!!!"
            $errorcount++
            $removeerrors.Add($file.FullName)
        }

        $log = @(
            "Duplicate found: $($file.FullName)"
            "Original   file: $($hashtable[$sha256])"
            $action
            '-----------------------------------'
        )

        $log # console output
        $log | Out-File -LiteralPath $logpath -Encoding utf8 -Append
    } else {
        $hashtable.Add($sha256, $file.FullName)
    }
}

"Deduplication was finished"
$soundplayer = New-Object System.Media.SoundPlayer "C:\Windows\Media\notify.wav"
$soundplayer.Play()

if ($errorcount -gt 0) {
    $errorsoutput = @(
        '-----------------------------------'
        Write-Host "WARNING!!! THERE ARE SOME ERRORS!!!" -ForegroundColor Red
        'Error deleting the following files:'
        $removeerrors
        'Error calculate hash of the following files:'
        $hashingerrors
    )
    $errorsoutput # console output
    $errorsoutput | Out-File -LiteralPath $logpath -Encoding utf8 -Append
}