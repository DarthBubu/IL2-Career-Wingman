param([int]$Port = 4321)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:udp = $null
$script:writer = $null
$script:stopwatch = $null
$script:captureDir = $null
$script:packetCount = 0L
$script:byteCount = 0L
$script:lastUiPacketCount = 0L

function Add-LogLine([string]$Text) {
    $stamp = (Get-Date).ToString('HH:mm:ss.fff')
    $logBox.AppendText("$stamp  $Text" + [Environment]::NewLine)
    $logBox.SelectionStart = $logBox.TextLength
    $logBox.ScrollToCaret()
}

function Write-Record([hashtable]$Record) {
    if (-not $script:writer) { return }
    $script:writer.WriteLine(($Record | ConvertTo-Json -Compress))
    $script:writer.Flush()
}

function Write-Mark([string]$Kind, [string]$Detail) {
    Write-Record ([ordered]@{
        utc = (Get-Date).ToUniversalTime().ToString('o')
        local = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff zzz')
        elapsed_ms = if ($script:stopwatch) { $script:stopwatch.ElapsedMilliseconds } else { 0 }
        kind = $Kind
        detail = $Detail
        packet_count = $script:packetCount
        byte_count = $script:byteCount
    })
    Add-LogLine "$Kind  $Detail  packets=$($script:packetCount)"
}

function Stop-Capture([string]$Reason) {
    $timer.Stop()
    if ($script:writer) { Write-Mark 'SESSION_END' $Reason }
    if ($script:udp) { $script:udp.Close(); $script:udp.Dispose(); $script:udp = $null }
    if ($script:writer) { $script:writer.Dispose(); $script:writer = $null }
    if ($script:stopwatch) { $script:stopwatch.Stop() }
    $start.Enabled = $true
    $stop.Enabled = $false
    $mark.Enabled = $false
    $portBox.Enabled = $true
    $status.Text = if ($script:captureDir) { "Stopped. Capture saved in $script:captureDir" } else { 'Stopped.' }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'IL-2 Career Wingman - CW 0.1 UDP Probe'
$form.Size = New-Object System.Drawing.Size(900,620)
$form.MinimumSize = New-Object System.Drawing.Size(720,500)
$form.StartPosition = 'CenterScreen'

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Read-only UDP capture probe for IL-2 telemetry/motion output'
$title.Location = New-Object System.Drawing.Point(14,14)
$title.AutoSize = $true
$title.Font = New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold)
$form.Controls.Add($title)

$portLabel = New-Object System.Windows.Forms.Label
$portLabel.Text = 'UDP port:'
$portLabel.Location = New-Object System.Drawing.Point(14,53)
$portLabel.AutoSize = $true
$form.Controls.Add($portLabel)

$portBox = New-Object System.Windows.Forms.NumericUpDown
$portBox.Location = New-Object System.Drawing.Point(82,49)
$portBox.Size = New-Object System.Drawing.Size(92,24)
$portBox.Minimum = 1
$portBox.Maximum = 65535
$portBox.Value = $Port
$form.Controls.Add($portBox)

$start = New-Object System.Windows.Forms.Button
$start.Text = 'Start capture'
$start.Location = New-Object System.Drawing.Point(190,46)
$start.Size = New-Object System.Drawing.Size(120,30)
$form.Controls.Add($start)

$stop = New-Object System.Windows.Forms.Button
$stop.Text = 'Stop capture'
$stop.Location = New-Object System.Drawing.Point(318,46)
$stop.Size = New-Object System.Drawing.Size(120,30)
$stop.Enabled = $false
$form.Controls.Add($stop)

$markText = New-Object System.Windows.Forms.TextBox
$markText.Location = New-Object System.Drawing.Point(14,91)
$markText.Size = New-Object System.Drawing.Size(680,24)
$markText.Anchor = 'Top,Left,Right'
$markText.Text = 'Describe what just happened in IL-2'
$form.Controls.Add($markText)

$mark = New-Object System.Windows.Forms.Button
$mark.Text = 'Mark event'
$mark.Location = New-Object System.Drawing.Point(704,88)
$mark.Size = New-Object System.Drawing.Size(164,30)
$mark.Anchor = 'Top,Right'
$mark.Enabled = $false
$form.Controls.Add($mark)

$status = New-Object System.Windows.Forms.Label
$status.Text = 'Stopped. Close other telemetry/radio tools before capturing.'
$status.Location = New-Object System.Drawing.Point(14,130)
$status.AutoSize = $true
$form.Controls.Add($status)

$stats = New-Object System.Windows.Forms.Label
$stats.Text = 'Packets: 0    Bytes: 0'
$stats.Location = New-Object System.Drawing.Point(14,155)
$stats.AutoSize = $true
$stats.Font = New-Object System.Drawing.Font('Consolas',10,[System.Drawing.FontStyle]::Bold)
$form.Controls.Add($stats)

$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.Location = New-Object System.Drawing.Point(14,184)
$logBox.Size = New-Object System.Drawing.Size(854,374)
$logBox.Anchor = 'Top,Bottom,Left,Right'
$logBox.ReadOnly = $true
$logBox.Font = New-Object System.Drawing.Font('Consolas',9)
$logBox.BackColor = [System.Drawing.Color]::FromArgb(24,27,32)
$logBox.ForeColor = [System.Drawing.Color]::Gainsboro
$form.Controls.Add($logBox)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 50
$timer.Add_Tick({
    if (-not $script:udp) { return }
    try {
        $drained = 0
        while ($script:udp.Available -gt 0 -and $drained -lt 1000) {
            $remote = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any,0)
            $bytes = $script:udp.Receive([ref]$remote)
            $script:packetCount++
            $script:byteCount += $bytes.Length
            $drained++
            Write-Record ([ordered]@{
                utc = (Get-Date).ToUniversalTime().ToString('o')
                elapsed_ms = $script:stopwatch.ElapsedMilliseconds
                kind = 'UDP_PACKET'
                sequence = $script:packetCount
                source = $remote.ToString()
                length = $bytes.Length
                data_base64 = [Convert]::ToBase64String($bytes)
            })
        }
        if ($script:packetCount -ne $script:lastUiPacketCount) {
            $stats.Text = "Packets: $($script:packetCount)    Bytes: $($script:byteCount)"
            $script:lastUiPacketCount = $script:packetCount
        }
    } catch {
        Add-LogLine ('RECEIVE ERROR  ' + $_.Exception.Message)
        Stop-Capture 'receive error'
    }
})

$start.Add_Click({
    $listenPort = [int]$portBox.Value
    try {
        $script:udp = New-Object System.Net.Sockets.UdpClient($listenPort)
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Could not listen on UDP port $listenPort.`r`n`r`nClose IL-2 radio, telemetry, motion or Tacview tools and try again.`r`n`r`n$($_.Exception.Message)",
            'CW UDP Probe - port unavailable') | Out-Null
        return
    }

    $base = Join-Path $PSScriptRoot 'UDP_Captures'
    [System.IO.Directory]::CreateDirectory($base) | Out-Null
    $script:captureDir = Join-Path $base (Get-Date -Format 'yyyyMMdd_HHmmss')
    [System.IO.Directory]::CreateDirectory($script:captureDir) | Out-Null
    $logPath = Join-Path $script:captureDir 'udp_events.jsonl'
    $script:writer = New-Object System.IO.StreamWriter($logPath,$false,(New-Object System.Text.UTF8Encoding($false)))
    $script:packetCount = 0L
    $script:byteCount = 0L
    $script:lastUiPacketCount = 0L
    $script:stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $start.Enabled = $false
    $stop.Enabled = $true
    $mark.Enabled = $true
    $portBox.Enabled = $false
    $status.Text = "Listening on 127.0.0.1:$listenPort - $script:captureDir"
    Write-Mark 'SESSION' "udp_port=$listenPort"
    $timer.Start()
})

$stop.Add_Click({ Stop-Capture 'user stopped' })

$mark.Add_Click({
    $note = $markText.Text.Trim()
    if ($note) { Write-Mark 'USER_MARK' $note; $markText.SelectAll() }
})

$form.Add_FormClosing({
    if ($script:udp -or $script:writer) { Stop-Capture 'window closed' }
})

[void]$form.ShowDialog()
