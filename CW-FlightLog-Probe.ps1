param([string]$Il2DataPath = "")

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:watching = $false
$script:known = @{}
$script:sessionDir = $null
$script:writer = $null
$script:pollMs = 500
$script:initializing = $false
$script:maxBaselineMlg = 5

function Add-LogLine([string]$text) {
    $stamp = (Get-Date).ToString('HH:mm:ss.fff')
    $line = "$stamp  $text"
    $logBox.AppendText($line + [Environment]::NewLine)
    $logBox.SelectionStart = $logBox.TextLength
    $logBox.ScrollToCaret()
}

function Write-Event([string]$kind, [string]$path, [long]$size, [long]$delta, [string]$detail) {
    $record = [ordered]@{
        utc = (Get-Date).ToUniversalTime().ToString('o')
        local = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff zzz')
        elapsed_ms = if ($script:stopwatch) { $script:stopwatch.ElapsedMilliseconds } else { 0 }
        kind = $kind
        path = $path
        size_bytes = $size
        delta_bytes = $delta
        detail = $detail
    }
    if ($script:writer) {
        $script:writer.WriteLine(($record | ConvertTo-Json -Compress))
        $script:writer.Flush()
    }
    $short = if ($path) { Split-Path $path -Leaf } else { '' }
    Add-LogLine ("{0,-10} {1} size={2} delta={3} {4}" -f $kind,$short,$size,$delta,$detail)
}

function Get-Targets([string]$root) {
    $result = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { return $result }

    @((Join-Path $root 'FlightLogs'), (Join-Path $root 'data\FlightLogs')) |
        Select-Object -Unique | ForEach-Object {
            if (Test-Path -LiteralPath $_ -PathType Container) {
                Get-ChildItem -LiteralPath $_ -Filter '*.mlg' -File -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTimeUtc -Descending |
                    Select-Object -First $script:maxBaselineMlg |
                    ForEach-Object { $result.Add($_.FullName) }
            }
        }

    @(
        (Join-Path $root '_gen.Mission'),
        (Join-Path $root 'Missions\_gen.Mission'),
        (Join-Path $root 'data\Missions\_gen.Mission'),
        (Join-Path $root 'swf\il2\usersave\cp.db'),
        (Join-Path $root 'data\swf\il2\usersave\cp.db')
    ) | Select-Object -Unique | ForEach-Object {
        if (Test-Path -LiteralPath $_ -PathType Leaf) { $result.Add($_) }
    }
    return $result
}

function Test-ReadOpen([string]$path) {
    try {
        $stream = [System.IO.File]::Open($path, [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete)
        $stream.Dispose()
        return 'read-open=OK'
    } catch {
        return ('read-open=BLOCKED:' + $_.Exception.GetType().Name)
    }
}

function Poll-Targets {
    if (-not $script:watching) { return }
    $root = $pathBox.Text.Trim()
    $targets = Get-Targets $root
    $seen = @{}
    foreach ($path in $targets) {
        try {
            $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
            $key = $item.FullName.ToLowerInvariant()
            $seen[$key] = $true
            $state = @{ Size = [long]$item.Length; Write = $item.LastWriteTimeUtc.Ticks }
            if (-not $script:known.ContainsKey($key)) {
                $script:known[$key] = $state
                $initialKind = if ($script:initializing) { 'BASELINE' } else { 'CREATED' }
                $initialDelta = if ($script:initializing) { 0 } else { $state.Size }
                Write-Event $initialKind $item.FullName $state.Size $initialDelta (Test-ReadOpen $item.FullName)
            } else {
                $old = $script:known[$key]
                if ($old.Size -ne $state.Size -or $old.Write -ne $state.Write) {
                    $delta = $state.Size - $old.Size
                    $script:known[$key] = $state
                    Write-Event 'CHANGED' $item.FullName $state.Size $delta (Test-ReadOpen $item.FullName)
                }
            }
        } catch {
            Write-Event 'ERROR' $path 0 0 $_.Exception.Message
        }
    }
    foreach ($key in @($script:known.Keys)) {
        if (-not $seen.ContainsKey($key)) {
            $old = $script:known[$key]
            $script:known.Remove($key)
            Write-Event 'REMOVED' $key $old.Size 0 ''
        }
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'IL-2 Career Wingman — CW 0.1 FlightLog Probe'
$form.Size = New-Object System.Drawing.Size(940,650)
$form.MinimumSize = New-Object System.Drawing.Size(760,520)
$form.StartPosition = 'CenterScreen'

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Read-only probe: FlightLogs (*.mlg), _gen.Mission and cp.db'
$title.Location = New-Object System.Drawing.Point(14,14)
$title.AutoSize = $true
$title.Font = New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold)
$form.Controls.Add($title)

$pathBox = New-Object System.Windows.Forms.TextBox
$pathBox.Location = New-Object System.Drawing.Point(14,48)
$pathBox.Size = New-Object System.Drawing.Size(720,24)
$pathBox.Anchor = 'Top,Left,Right'
$pathBox.Text = $Il2DataPath
$form.Controls.Add($pathBox)

$browse = New-Object System.Windows.Forms.Button
$browse.Text = 'Choose IL-2 data folder'
$browse.Location = New-Object System.Drawing.Point(744,46)
$browse.Size = New-Object System.Drawing.Size(172,28)
$browse.Anchor = 'Top,Right'
$browse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Choose the IL-2 data folder that contains FlightLogs (or its parent game folder).'
    if ($dialog.ShowDialog() -eq 'OK') { $pathBox.Text = $dialog.SelectedPath }
})
$form.Controls.Add($browse)

$start = New-Object System.Windows.Forms.Button
$start.Text = 'Start capture'
$start.Location = New-Object System.Drawing.Point(14,86)
$start.Size = New-Object System.Drawing.Size(120,30)
$form.Controls.Add($start)

$stop = New-Object System.Windows.Forms.Button
$stop.Text = 'Stop capture'
$stop.Location = New-Object System.Drawing.Point(142,86)
$stop.Size = New-Object System.Drawing.Size(120,30)
$stop.Enabled = $false
$form.Controls.Add($stop)

$markText = New-Object System.Windows.Forms.TextBox
$markText.Location = New-Object System.Drawing.Point(276,89)
$markText.Size = New-Object System.Drawing.Size(470,24)
$markText.Anchor = 'Top,Left,Right'
$markText.Text = 'Describe what just happened in IL-2'
$form.Controls.Add($markText)

$mark = New-Object System.Windows.Forms.Button
$mark.Text = 'Mark event'
$mark.Location = New-Object System.Drawing.Point(756,86)
$mark.Size = New-Object System.Drawing.Size(160,30)
$mark.Anchor = 'Top,Right'
$mark.Enabled = $false
$form.Controls.Add($mark)

$status = New-Object System.Windows.Forms.Label
$status.Text = 'Stopped. No IL-2 files are modified by this probe.'
$status.Location = New-Object System.Drawing.Point(14,126)
$status.AutoSize = $true
$form.Controls.Add($status)

$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.Location = New-Object System.Drawing.Point(14,154)
$logBox.Size = New-Object System.Drawing.Size(902,440)
$logBox.Anchor = 'Top,Bottom,Left,Right'
$logBox.ReadOnly = $true
$logBox.Font = New-Object System.Drawing.Font('Consolas',9)
$logBox.BackColor = [System.Drawing.Color]::FromArgb(24,27,32)
$logBox.ForeColor = [System.Drawing.Color]::Gainsboro
$form.Controls.Add($logBox)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $script:pollMs
$timer.Add_Tick({ Poll-Targets })

$start.Add_Click({
    $root = $pathBox.Text.Trim()
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        [System.Windows.Forms.MessageBox]::Show('Choose a valid IL-2 folder first.','CW 0.1') | Out-Null
        return
    }
    $base = Join-Path $PSScriptRoot 'Captures'
    [System.IO.Directory]::CreateDirectory($base) | Out-Null
    $script:sessionDir = Join-Path $base (Get-Date -Format 'yyyyMMdd_HHmmss')
    [System.IO.Directory]::CreateDirectory($script:sessionDir) | Out-Null
    $logPath = Join-Path $script:sessionDir 'events.jsonl'
    $script:writer = New-Object System.IO.StreamWriter($logPath,$false,(New-Object System.Text.UTF8Encoding($false)))
    $script:known = @{}
    $script:stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $script:watching = $true
    $pathBox.Enabled = $false; $browse.Enabled = $false; $start.Enabled = $false
    $stop.Enabled = $true; $mark.Enabled = $true
    $status.Text = "Capturing every $($script:pollMs) ms → $script:sessionDir"
    Write-Event 'SESSION' '' 0 0 ("root=" + $root)
    $script:initializing = $true
    Poll-Targets
    $script:initializing = $false
    $timer.Start()
})

$stop.Add_Click({
    $timer.Stop(); $script:watching = $false
    Write-Event 'SESSION_END' '' 0 0 ''
    if ($script:writer) { $script:writer.Dispose(); $script:writer = $null }
    if ($script:stopwatch) { $script:stopwatch.Stop() }
    $pathBox.Enabled = $true; $browse.Enabled = $true; $start.Enabled = $true
    $stop.Enabled = $false; $mark.Enabled = $false
    $status.Text = "Stopped. Capture saved in $script:sessionDir"
})

$mark.Add_Click({
    $note = $markText.Text.Trim()
    if ($note) { Write-Event 'USER_MARK' '' 0 0 $note; $markText.SelectAll() }
})

$form.Add_FormClosing({
    $timer.Stop()
    if ($script:writer) {
        Write-Event 'SESSION_END' '' 0 0 'window closed'
        $script:writer.Dispose()
    }
})

[void]$form.ShowDialog()
