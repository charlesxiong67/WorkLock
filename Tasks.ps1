# WorkLock Tasks: add today's work, tick it off, and see whether games are unlocked.
# If a PIN is set (by a parent or friend), ticking tasks off, removing unfinished
# tasks and "No work today" all need the PIN.
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $Here 'common.ps1')
$PinFile = Join-Path (Get-WLDataDir $Here) 'pin.txt'

function Get-Pin { if (Test-Path $PinFile) { (Get-Content $PinFile -Raw).Trim() } else { '' } }

function Ask-Pin($prompt) {
    $f = New-Object Windows.Forms.Form -Property @{ Text = 'WorkLock'; Width = 300; Height = 160; FormBorderStyle = 'FixedDialog'; StartPosition = 'CenterParent'; MaximizeBox = $false; MinimizeBox = $false }
    $l = New-Object Windows.Forms.Label -Property @{ Text = $prompt; Left = 12; Top = 12; Width = 260; Height = 20 }
    $t = New-Object Windows.Forms.TextBox -Property @{ Left = 12; Top = 36; Width = 260; PasswordChar = '*' }
    $ok = New-Object Windows.Forms.Button -Property @{ Text = 'OK'; Left = 116; Top = 72; Width = 75; DialogResult = 'OK' }
    $no = New-Object Windows.Forms.Button -Property @{ Text = 'Cancel'; Left = 197; Top = 72; Width = 75; DialogResult = 'Cancel' }
    $f.Controls.AddRange(@($l, $t, $ok, $no)); $f.AcceptButton = $ok; $f.CancelButton = $no
    if ($f.ShowDialog($form) -eq 'OK') { $t.Text } else { $null }
}

# True when no PIN is set, or the right PIN is typed.
function Confirm-Pin($why) {
    $pin = Get-Pin
    if (-not $pin) { return $true }
    $typed = Ask-Pin "PIN needed to $why"
    if ($null -eq $typed) { return $false }
    if ((Get-WLHash $typed) -eq $pin) { return $true }
    [void][Windows.Forms.MessageBox]::Show('Wrong PIN.', 'WorkLock')
    $false
}

$red = [Drawing.Color]::FromArgb(179, 54, 47);  $redBg = [Drawing.Color]::FromArgb(251, 231, 229)
$green = [Drawing.Color]::FromArgb(31, 122, 77); $greenBg = [Drawing.Color]::FromArgb(226, 244, 234)

$form = New-Object Windows.Forms.Form -Property @{ Text = 'WorkLock Tasks'; Width = 440; Height = 600; StartPosition = 'CenterScreen'; Font = New-Object Drawing.Font('Segoe UI', 10); MinimumSize = New-Object Drawing.Size(400, 600) }
$status   = New-Object Windows.Forms.Label -Property @{ Left = 12; Top = 10; Width = 400; Height = 44; Font = New-Object Drawing.Font('Segoe UI Semibold', 13); TextAlign = 'MiddleLeft'; Anchor = 'Top,Left,Right' }
$dayLbl   = New-Object Windows.Forms.Label -Property @{ Text = 'Today'; Left = 12; Top = 64; Width = 300 }
$daily    = New-Object Windows.Forms.CheckedListBox -Property @{ Left = 12; Top = 86; Width = 400; Height = 220; CheckOnClick = $true; IntegralHeight = $false; Anchor = 'Top,Left,Right' }
$wkLbl    = New-Object Windows.Forms.Label -Property @{ Text = 'Weekly (comes back every Monday)'; Left = 12; Top = 314; Width = 300 }
$weeklyBox = New-Object Windows.Forms.CheckedListBox -Property @{ Left = 12; Top = 336; Width = 400; Height = 90; CheckOnClick = $true; IntegralHeight = $false; Anchor = 'Top,Left,Right' }
$newTask  = New-Object Windows.Forms.TextBox -Property @{ Left = 12; Top = 438; Width = 230; Anchor = 'Top,Left,Right' }
$isWeekly = New-Object Windows.Forms.CheckBox -Property @{ Text = 'Weekly'; Left = 250; Top = 438; Width = 80; Anchor = 'Top,Right' }
$add      = New-Object Windows.Forms.Button -Property @{ Text = 'Add'; Left = 334; Top = 436; Width = 78; Anchor = 'Top,Right' }
$remove   = New-Object Windows.Forms.Button -Property @{ Text = 'Remove'; Left = 12; Top = 480; Width = 100 }
$noWork   = New-Object Windows.Forms.Button -Property @{ Text = 'No work today'; Left = 118; Top = 480; Width = 130 }
$pinBtn   = New-Object Windows.Forms.Button -Property @{ Text = 'PIN...'; Left = 254; Top = 480; Width = 80 }
$hint     = New-Object Windows.Forms.Label -Property @{ Left = 12; Top = 518; Width = 400; Height = 40; ForeColor = [Drawing.Color]::DimGray; Anchor = 'Top,Left,Right' }
$form.Controls.AddRange(@($status, $dayLbl, $daily, $wkLbl, $weeklyBox, $newTask, $isWeekly, $add, $remove, $noWork, $pinBtn, $hint))
$form.AcceptButton = $add

$script:loading = $false
$script:s = $null

function Refresh-View {
    $script:loading = $true
    $script:s = Get-WLState $Here
    $s = $script:s
    $daily.Items.Clear(); $weeklyBox.Items.Clear()
    foreach ($x in $s.Today.tasks) { [void]$daily.Items.Add($x.text, [bool]$x.done) }
    if ($s.Today.noWork) { [void]$daily.Items.Add('(no work today)', $true) }
    foreach ($x in $s.Weekly) { [void]$weeklyBox.Items.Add($x.text, ($x.doneWeek -eq $s.Week)) }
    if (-not $s.Locked) {
        $status.Text = '  Games unlocked'; $status.BackColor = $greenBg; $status.ForeColor = $green
    } elseif (-not $s.HasToday) {
        $status.Text = '  Games locked: add today''s work'; $status.BackColor = $redBg; $status.ForeColor = $red
    } else {
        $status.Text = "  Games locked: $($s.Left.Count) left"; $status.BackColor = $redBg; $status.ForeColor = $red
    }
    $hint.Text = if (Get-Pin) { 'A PIN is set, so ticking tasks off needs the PIN.' } else { 'Tick tasks off as you finish them. Unfinished tasks carry over to tomorrow.' }
    $script:loading = $false
}

function Save-And-Refresh {
    Save-WLState $Here $script:s.Today $script:s.Weekly
    Refresh-View
}

$daily.add_ItemCheck({
    param($sender, $e)
    if ($script:loading) { return }
    $tasks = @($script:s.Today.tasks)
    if ($e.Index -ge $tasks.Count) { $e.NewValue = $e.CurrentValue; return }   # the "(no work today)" line
    $on = $e.NewValue -eq [Windows.Forms.CheckState]::Checked
    if ($on -and -not (Confirm-Pin 'tick this off')) { $e.NewValue = $e.CurrentValue; return }
    $tasks[$e.Index].done = $on
    # The list can't be rebuilt inside its own ItemCheck event, so save once it finishes.
    [void]$form.BeginInvoke([Action]{ Save-And-Refresh })
})
$weeklyBox.add_ItemCheck({
    param($sender, $e)
    if ($script:loading) { return }
    $on = $e.NewValue -eq [Windows.Forms.CheckState]::Checked
    if ($on -and -not (Confirm-Pin 'tick this off')) { $e.NewValue = $e.CurrentValue; return }
    @($script:s.Weekly)[$e.Index].doneWeek = $(if ($on) { $script:s.Week } else { '' })
    [void]$form.BeginInvoke([Action]{ Save-And-Refresh })
})

$add.add_Click({
    $text = $newTask.Text.Trim()
    if (-not $text) { return }
    if ($isWeekly.Checked) {
        $script:s.Weekly = @($script:s.Weekly) + [pscustomobject]@{ text = $text; doneWeek = '' }
    } else {
        $script:s.Today.tasks = @($script:s.Today.tasks) + [pscustomobject]@{ text = $text; done = $false }
        $script:s.Today.noWork = $false
    }
    $newTask.Clear()
    Save-And-Refresh
})

$remove.add_Click({
    $i = $daily.SelectedIndex; $w = $weeklyBox.SelectedIndex
    if ($i -ge 0 -and $i -lt @($script:s.Today.tasks).Count) {
        $x = @($script:s.Today.tasks)[$i]
        if (-not $x.done -and -not (Confirm-Pin 'remove an unfinished task')) { return }
        $script:s.Today.tasks = @($script:s.Today.tasks | Where-Object { $_ -ne $x })
    } elseif ($w -ge 0) {
        if (-not (Confirm-Pin 'remove a weekly task')) { return }
        $x = @($script:s.Weekly)[$w]
        $script:s.Weekly = @($script:s.Weekly | Where-Object { $_ -ne $x })
    } else { return }
    Save-And-Refresh
})

$noWork.add_Click({
    if (@($script:s.Today.tasks | Where-Object { -not $_.done }).Count -gt 0) {
        [void][Windows.Forms.MessageBox]::Show('You still have unfinished tasks today. Finish or remove them first.', 'WorkLock')
        return
    }
    if (-not (Confirm-Pin 'mark today as no work')) { return }
    $script:s.Today.noWork = $true
    Save-And-Refresh
})

$pinBtn.add_Click({
    if ((Get-Pin) -and -not (Confirm-Pin 'change the PIN')) { return }
    $new = Ask-Pin 'New PIN (leave empty to remove it)'
    if ($null -eq $new) { return }
    if ($new) { Set-Content $PinFile (Get-WLHash $new) } else { Remove-Item $PinFile -ErrorAction SilentlyContinue }
    Refresh-View
})

Refresh-View
[void]$form.ShowDialog()
