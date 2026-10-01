# WorkLock Tasks: add today's work, tick it off, and see whether games are unlocked.
# If a PIN is set (by a parent or friend), ticking tasks off, removing unfinished
# tasks and "No work today" all need the PIN.
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $Here 'common.ps1')
$PinFile = Join-Path (Get-WLDataDir $Here) 'pin.txt'

# ---- Theme: follow the Windows light/dark app setting ----
$dark = $false
try { $dark = (Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' AppsUseLightTheme) -eq 0 } catch {}
$palette = if ($dark) {
    @{ Bg='#15181E'; Card='#1E232B'; Line='#2C333D'; Hover='#262C35'; Ink='#E9EDF3'; Muted='#98A2B3'
       Accent='#7C9BFF'; AccentInk='#10142A'; AccentSoft='#252D4A'; Lock='#FF8A80'; LockBg='#3A1F1E'; Open='#6FD6A0'; OpenBg='#16301F'; Track='#2C333D' }
} else {
    @{ Bg='#F3F5F9'; Card='#FFFFFF'; Line='#E3E7EE'; Hover='#EEF1F6'; Ink='#18202B'; Muted='#667085'
       Accent='#3B5BDB'; AccentInk='#FFFFFF'; AccentSoft='#E7ECFD'; Lock='#B42318'; LockBg='#FEECEB'; Open='#067647'; OpenBg='#E3F5EA'; Track='#E3E7EE' }
}

$resources = @'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <SolidColorBrush x:Key="Bg" Color="{{Bg}}"/>
  <SolidColorBrush x:Key="Card" Color="{{Card}}"/>
  <SolidColorBrush x:Key="Line" Color="{{Line}}"/>
  <SolidColorBrush x:Key="Hover" Color="{{Hover}}"/>
  <SolidColorBrush x:Key="Ink" Color="{{Ink}}"/>
  <SolidColorBrush x:Key="Muted" Color="{{Muted}}"/>
  <SolidColorBrush x:Key="Accent" Color="{{Accent}}"/>
  <SolidColorBrush x:Key="AccentInk" Color="{{AccentInk}}"/>
  <SolidColorBrush x:Key="AccentSoft" Color="{{AccentSoft}}"/>
  <SolidColorBrush x:Key="Lock" Color="{{Lock}}"/>
  <SolidColorBrush x:Key="LockBg" Color="{{LockBg}}"/>
  <SolidColorBrush x:Key="Open" Color="{{Open}}"/>
  <SolidColorBrush x:Key="OpenBg" Color="{{OpenBg}}"/>
  <SolidColorBrush x:Key="Track" Color="{{Track}}"/>
  <FontFamily x:Key="Ui">Segoe UI Variable Text, Segoe UI</FontFamily>
  <FontFamily x:Key="Display">Segoe UI Variable Display, Segoe UI</FontFamily>
  <FontFamily x:Key="Icons">Segoe Fluent Icons, Segoe MDL2 Assets</FontFamily>

  <Style x:Key="TaskCheck" TargetType="CheckBox">
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Focusable" Value="True"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="CheckBox">
          <Border x:Name="box" Width="22" Height="22" CornerRadius="11" BorderThickness="2"
                  BorderBrush="{StaticResource Muted}" Background="Transparent">
            <TextBlock x:Name="tick" Text="&#xE73E;" FontFamily="{StaticResource Icons}" FontSize="11"
                       Foreground="{StaticResource Card}" HorizontalAlignment="Center" VerticalAlignment="Center" Visibility="Hidden"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
              <Setter TargetName="box" Property="BorderBrush" Value="{StaticResource Accent}"/>
            </Trigger>
            <Trigger Property="IsKeyboardFocused" Value="True">
              <Setter TargetName="box" Property="BorderBrush" Value="{StaticResource Accent}"/>
            </Trigger>
            <Trigger Property="IsChecked" Value="True">
              <Setter TargetName="box" Property="Background" Value="{StaticResource Open}"/>
              <Setter TargetName="box" Property="BorderBrush" Value="{StaticResource Open}"/>
              <Setter TargetName="tick" Property="Visibility" Value="Visible"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key="BaseButton" TargetType="Button">
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="FontFamily" Value="{StaticResource Ui}"/>
    <Setter Property="FontSize" Value="14"/>
    <Setter Property="Padding" Value="14,8"/>
    <Setter Property="Foreground" Value="{StaticResource Ink}"/>
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="bd" CornerRadius="10" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Opacity" Value="0.88"/></Trigger>
            <Trigger Property="IsPressed" Value="True"><Setter TargetName="bd" Property="Opacity" Value="0.75"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="AccentButton" TargetType="Button" BasedOn="{StaticResource BaseButton}">
    <Setter Property="Background" Value="{StaticResource Accent}"/>
    <Setter Property="Foreground" Value="{StaticResource AccentInk}"/>
    <Setter Property="FontWeight" Value="SemiBold"/>
  </Style>
  <Style x:Key="GhostButton" TargetType="Button" BasedOn="{StaticResource BaseButton}">
    <Setter Property="Foreground" Value="{StaticResource Muted}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="bd" CornerRadius="10" Background="Transparent" Padding="{TemplateBinding Padding}">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="{StaticResource Hover}"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="IconButton" TargetType="Button" BasedOn="{StaticResource GhostButton}">
    <Setter Property="Padding" Value="0"/>
    <Setter Property="Width" Value="30"/>
    <Setter Property="Height" Value="30"/>
    <Setter Property="FontFamily" Value="{StaticResource Icons}"/>
    <Setter Property="FontSize" Value="11"/>
    <Setter Property="ToolTip" Value="Remove"/>
  </Style>

  <Style x:Key="Pill" TargetType="ToggleButton">
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="FontFamily" Value="{StaticResource Ui}"/>
    <Setter Property="FontSize" Value="13"/>
    <Setter Property="Foreground" Value="{StaticResource Muted}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ToggleButton">
          <Border x:Name="bd" CornerRadius="16" BorderThickness="1" BorderBrush="{StaticResource Line}" Background="{StaticResource Card}" Padding="12,6">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="BorderBrush" Value="{StaticResource Accent}"/></Trigger>
            <Trigger Property="IsChecked" Value="True">
              <Setter TargetName="bd" Property="Background" Value="{StaticResource AccentSoft}"/>
              <Setter TargetName="bd" Property="BorderBrush" Value="{StaticResource Accent}"/>
              <Setter Property="Foreground" Value="{StaticResource Accent}"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key="Field" TargetType="TextBox">
    <Setter Property="FontFamily" Value="{StaticResource Ui}"/>
    <Setter Property="FontSize" Value="14"/>
    <Setter Property="Foreground" Value="{StaticResource Ink}"/>
    <Setter Property="CaretBrush" Value="{StaticResource Ink}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="TextBox">
          <Border x:Name="bd" CornerRadius="10" BorderThickness="1" BorderBrush="{StaticResource Line}" Background="{StaticResource Card}" Padding="10,7">
            <ScrollViewer x:Name="PART_ContentHost" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="bd" Property="BorderBrush" Value="{StaticResource Accent}"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key="SectionLabel" TargetType="TextBlock">
    <Setter Property="FontFamily" Value="{StaticResource Ui}"/>
    <Setter Property="FontSize" Value="12"/>
    <Setter Property="FontWeight" Value="SemiBold"/>
    <Setter Property="Foreground" Value="{StaticResource Muted}"/>
  </Style>
  <Style x:Key="CardBox" TargetType="Border">
    <Setter Property="Background" Value="{StaticResource Card}"/>
    <Setter Property="BorderBrush" Value="{StaticResource Line}"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="CornerRadius" Value="14"/>
  </Style>
</ResourceDictionary>
'@
foreach ($k in $palette.Keys) { $resources = $resources.Replace("{{$k}}", $palette[$k]) }
# Each window gets the shared styles inlined, since StaticResource lookups happen while parsing.
$resInner = [regex]::Match($resources, '(?s)<ResourceDictionary[^>]*>(.*)</ResourceDictionary>').Groups[1].Value
function New-Window($xaml) {
    $re = New-Object regex '<Window[^>]*>'
    [Windows.Markup.XamlReader]::Parse($re.Replace($xaml, { param($m) $m.Value + "<Window.Resources>$resInner</Window.Resources>" }, 1))
}

$windowXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WorkLock Tasks" Width="480" Height="720" MinWidth="400" MinHeight="560"
        WindowStartupLocation="CenterScreen" UseLayoutRounding="True">
  <Grid x:Name="Root" Background="{StaticResource Bg}">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Status -->
    <StackPanel Grid.Row="0" Margin="20,18,20,8">
      <TextBlock Text="WORKLOCK" Style="{StaticResource SectionLabel}" Margin="2,0,0,10"/>
      <Border x:Name="StatusCard" CornerRadius="16" Padding="16,14">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>
          <Border x:Name="StatusIconBg" Width="44" Height="44" CornerRadius="22" Background="{StaticResource Card}" Opacity="0.9">
            <TextBlock x:Name="StatusIcon" FontFamily="{StaticResource Icons}" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <StackPanel Grid.Column="1" Margin="14,0,0,0" VerticalAlignment="Center">
            <TextBlock x:Name="StatusTitle" FontFamily="{StaticResource Display}" FontSize="20" FontWeight="SemiBold"/>
            <TextBlock x:Name="StatusSub" FontFamily="{StaticResource Ui}" FontSize="13" Foreground="{StaticResource Ink}" Opacity="0.75" Margin="0,2,0,0" TextWrapping="Wrap"/>
          </StackPanel>
        </Grid>
      </Border>
      <Grid x:Name="Progress" Height="6" Margin="2,12,2,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition x:Name="ProgDone" Width="0*"/>
          <ColumnDefinition x:Name="ProgLeft" Width="1*"/>
        </Grid.ColumnDefinitions>
        <Border Grid.ColumnSpan="2" CornerRadius="3" Background="{StaticResource Track}"/>
        <Border Grid.Column="0" CornerRadius="3" Background="{StaticResource Open}"/>
      </Grid>
    </StackPanel>

    <!-- Lists -->
    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Padding="20,4,20,8">
      <StackPanel>
        <DockPanel Margin="2,8,2,8">
          <TextBlock x:Name="DailyCount" DockPanel.Dock="Right" Style="{StaticResource SectionLabel}"/>
          <TextBlock Text="TODAY" Style="{StaticResource SectionLabel}"/>
        </DockPanel>
        <Border Style="{StaticResource CardBox}"><StackPanel x:Name="DailyList"/></Border>
        <DockPanel Margin="2,20,2,8">
          <TextBlock x:Name="WeeklyCount" DockPanel.Dock="Right" Style="{StaticResource SectionLabel}"/>
          <TextBlock Text="THIS WEEK" Style="{StaticResource SectionLabel}"/>
        </DockPanel>
        <Border Style="{StaticResource CardBox}"><StackPanel x:Name="WeeklyList"/></Border>
      </StackPanel>
    </ScrollViewer>

    <!-- Add + footer -->
    <Border Grid.Row="2" BorderBrush="{StaticResource Line}" BorderThickness="0,1,0,0" Background="{StaticResource Card}" Padding="20,14,20,12">
      <StackPanel>
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <Grid>
            <TextBox x:Name="NewTask" Style="{StaticResource Field}"/>
            <TextBlock x:Name="Placeholder" Text="Add a task..." IsHitTestVisible="False" Margin="12,0,0,0" VerticalAlignment="Center"
                       FontFamily="{StaticResource Ui}" FontSize="14" Foreground="{StaticResource Muted}"/>
          </Grid>
          <ToggleButton x:Name="WeeklyToggle" Grid.Column="1" Style="{StaticResource Pill}" Content="Weekly" Margin="8,0,0,0" ToolTip="Comes back every Monday"/>
          <Button x:Name="AddBtn" Grid.Column="2" Style="{StaticResource AccentButton}" Margin="8,0,0,0" IsDefault="True">
            <StackPanel Orientation="Horizontal">
              <TextBlock Text="&#xE710;" FontFamily="{StaticResource Icons}" FontSize="12" VerticalAlignment="Center" Margin="0,0,6,0"/>
              <TextBlock Text="Add"/>
            </StackPanel>
          </Button>
        </Grid>
        <DockPanel Margin="0,10,0,0">
          <Button x:Name="PinBtn" DockPanel.Dock="Right" Style="{StaticResource GhostButton}" Padding="10,6">
            <StackPanel Orientation="Horizontal">
              <TextBlock Text="&#xE8D7;" FontFamily="{StaticResource Icons}" FontSize="13" VerticalAlignment="Center" Margin="0,0,6,0"/>
              <TextBlock x:Name="PinLabel" Text="Set PIN"/>
            </StackPanel>
          </Button>
          <Button x:Name="NoWorkBtn" DockPanel.Dock="Left" Style="{StaticResource GhostButton}" Padding="10,6" Content="No work today"/>
          <TextBlock x:Name="Note" FontFamily="{StaticResource Ui}" FontSize="12" Foreground="{StaticResource Muted}" TextWrapping="Wrap" VerticalAlignment="Center" Margin="8,0"/>
        </DockPanel>
      </StackPanel>
    </Border>
  </Grid>
</Window>
'@
$win = New-Window $windowXaml
$Res = $win.Resources
$win.Background = $Res['Bg']
$win.FontFamily = $Res['Ui']
$win.Foreground = $Res['Ink']
$ui = @{}
foreach ($n in 'StatusCard','StatusIcon','StatusTitle','StatusSub','ProgDone','ProgLeft','DailyList','WeeklyList','DailyCount','WeeklyCount',
               'NewTask','Placeholder','WeeklyToggle','AddBtn','PinBtn','PinLabel','NoWorkBtn','Note') { $ui[$n] = $win.FindName($n) }

# Dark title bar to match the dark theme (Windows 10 20H1+ / 11).
if ($dark) {
    Add-Type -Namespace WL -Name Dwm -MemberDefinition '[DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr h, int a, ref int v, int s);'
    $win.add_SourceInitialized({
        $h = (New-Object Windows.Interop.WindowInteropHelper($win)).Handle
        $on = 1; [void][WL.Dwm]::DwmSetWindowAttribute($h, 20, [ref]$on, 4)
    })
}

# ---- PIN ----
function Get-Pin { if (Test-Path $PinFile) { (Get-Content $PinFile -Raw).Trim() } else { '' } }

# Shows a PIN box. With $check, keeps the box open until the PIN matches or the user cancels.
function Ask-Pin($prompt, $check) {
    $x = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WorkLock" Width="340" SizeToContent="Height" ResizeMode="NoResize" WindowStartupLocation="CenterOwner" ShowInTaskbar="False">
  <StackPanel Margin="20">
    <TextBlock x:Name="Prompt" FontFamily="{StaticResource Display}" FontSize="16" FontWeight="SemiBold" TextWrapping="Wrap"/>
    <Border CornerRadius="10" BorderThickness="1" BorderBrush="{StaticResource Line}" Background="{StaticResource Card}" Padding="10,7" Margin="0,12,0,0">
      <PasswordBox x:Name="Box" BorderThickness="0" Background="Transparent" FontSize="16" Foreground="{StaticResource Ink}" CaretBrush="{StaticResource Ink}"/>
    </Border>
    <TextBlock x:Name="Err" Text="Wrong PIN. Try again." Foreground="{StaticResource Lock}" FontSize="12" Margin="2,6,0,0" Visibility="Collapsed"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,16,0,0">
      <Button x:Name="Cancel" Style="{StaticResource GhostButton}" Content="Cancel" IsCancel="True"/>
      <Button x:Name="Ok" Style="{StaticResource AccentButton}" Content="OK" IsDefault="True" Margin="8,0,0,0"/>
    </StackPanel>
  </StackPanel>
</Window>
'@
    $d = New-Window $x
    $d.Background = $Res['Bg']; $d.Foreground = $Res['Ink']; $d.FontFamily = $Res['Ui']
    if ($win.IsLoaded) { $d.Owner = $win }
    $d.FindName('Prompt').Text = $prompt
    $box = $d.FindName('Box'); $err = $d.FindName('Err')
    $script:pinResult = $null
    $d.FindName('Ok').add_Click({
        if ($check -and -not (& $check $box.Password)) { $err.Visibility = 'Visible'; $box.Clear(); $box.Focus() | Out-Null; return }
        $script:pinResult = $box.Password; $d.DialogResult = $true
    })
    $d.add_ContentRendered({ $box.Focus() | Out-Null })
    [void]$d.ShowDialog()
    $script:pinResult
}

# True when no PIN is set, or the right PIN is typed.
function Confirm-Pin($why) {
    $pin = Get-Pin
    if (-not $pin) { return $true }
    $null -ne (Ask-Pin "Enter the PIN to $why" { param($p) (Get-WLHash $p) -eq $pin })
}

# ---- Rendering ----
function Show-Note($text, [switch]$Error) {
    $ui.Note.Text = $text
    $ui.Note.Foreground = if ($Error) { $Res['Lock'] } else { $Res['Muted'] }
}

function New-Row($text, $done, $kind, $index, $last) {
    $row = New-Object Windows.Controls.Border
    $row.Padding = '14,10,8,10'
    if (-not $last) { $row.BorderBrush = $Res['Line']; $row.BorderThickness = '0,0,0,1' }
    $g = New-Object Windows.Controls.Grid
    foreach ($w in 'Auto', '*', 'Auto') { $c = New-Object Windows.Controls.ColumnDefinition; $c.Width = $w; $g.ColumnDefinitions.Add($c) }

    $cb = New-Object Windows.Controls.CheckBox
    $cb.Style = $Res['TaskCheck']; $cb.IsChecked = [bool]$done; $cb.VerticalAlignment = 'Center'
    $cb.Tag = "$kind|$index"
    $cb.add_Click({ Toggle-Task $this })

    $tb = New-Object Windows.Controls.TextBlock
    $tb.Text = $text; $tb.TextWrapping = 'Wrap'; $tb.FontSize = 14; $tb.VerticalAlignment = 'Center'; $tb.Margin = '12,0,8,0'
    $tb.Foreground = if ($done) { $Res['Muted'] } else { $Res['Ink'] }
    if ($done) { $tb.TextDecorations = [Windows.TextDecorations]::Strikethrough }
    [Windows.Controls.Grid]::SetColumn($tb, 1)

    $rm = New-Object Windows.Controls.Button
    $rm.Style = $Res['IconButton']; $rm.Content = [string][char]0xE711; $rm.Tag = "$kind|$index"
    $rm.add_Click({ Remove-Task $this })
    [Windows.Controls.Grid]::SetColumn($rm, 2)

    [void]$g.Children.Add($cb); [void]$g.Children.Add($tb); [void]$g.Children.Add($rm)
    $row.Child = $g
    $row
}

function New-Empty($text) {
    $t = New-Object Windows.Controls.TextBlock
    $t.Text = $text; $t.Margin = '16,14'; $t.FontSize = 13; $t.Foreground = $Res['Muted']; $t.TextWrapping = 'Wrap'
    $t
}

function Refresh-View {
    $script:s = Get-WLState $Here
    $s = $script:s
    $tasks = @($s.Today.tasks); $weekly = @($s.Weekly)

    $ui.DailyList.Children.Clear()
    for ($i = 0; $i -lt $tasks.Count; $i++) { [void]$ui.DailyList.Children.Add((New-Row $tasks[$i].text $tasks[$i].done 'd' $i ($i -eq $tasks.Count - 1))) }
    if ($s.Today.noWork) { [void]$ui.DailyList.Children.Add((New-Empty 'No work today. Enjoy your day off.')) }
    elseif (-not $tasks.Count) { [void]$ui.DailyList.Children.Add((New-Empty 'Nothing here yet. Add what you need to get done today.')) }

    $ui.WeeklyList.Children.Clear()
    for ($i = 0; $i -lt $weekly.Count; $i++) { [void]$ui.WeeklyList.Children.Add((New-Row $weekly[$i].text ($weekly[$i].doneWeek -eq $s.Week) 'w' $i ($i -eq $weekly.Count - 1))) }
    if (-not $weekly.Count) { [void]$ui.WeeklyList.Children.Add((New-Empty 'Tasks marked Weekly show up here and come back every Monday.')) }

    $dDone = @($tasks | Where-Object { $_.done }).Count
    $wDone = @($weekly | Where-Object { $_.doneWeek -eq $s.Week }).Count
    $ui.DailyCount.Text = if ($tasks.Count) { "$dDone of $($tasks.Count) done" } else { '' }
    $ui.WeeklyCount.Text = if ($weekly.Count) { "$wDone of $($weekly.Count) done" } else { '' }
    $total = $tasks.Count + $weekly.Count; $doneAll = $dDone + $wDone
    $leftCount = [math]::Max(0, $total - $doneAll)
    if (-not $total) { $leftCount = 1 }   # empty list: show an empty bar
    $ui.ProgDone.Width = [Windows.GridLength]::new($doneAll, 'Star')
    $ui.ProgLeft.Width = [Windows.GridLength]::new($leftCount, 'Star')

    if (-not $s.Locked) {
        $ui.StatusCard.Background = $Res['OpenBg']; $ui.StatusTitle.Foreground = $Res['Open']; $ui.StatusIcon.Foreground = $Res['Open']
        $ui.StatusIcon.Text = [string][char]0xE785
        $ui.StatusTitle.Text = 'Games unlocked'
        $ui.StatusSub.Text = if ($s.Today.noWork -and -not $total) { 'No work today.' } else { 'Everything is done. Nice work.' }
    } else {
        $ui.StatusCard.Background = $Res['LockBg']; $ui.StatusTitle.Foreground = $Res['Lock']; $ui.StatusIcon.Foreground = $Res['Lock']
        $ui.StatusIcon.Text = [string][char]0xE72E
        $ui.StatusTitle.Text = 'Games locked'
        $n = $s.Left.Count
        $ui.StatusSub.Text = if (-not $s.HasToday) { "Add today's work to get started." } else { "$n task$(if ($n -ne 1) { 's' }) left. Tick them off as you go." }
    }
    $ui.PinLabel.Text = if (Get-Pin) { 'Change PIN' } else { 'Set PIN' }
}

function Save-And-Refresh {
    Save-WLState $Here $script:s.Today $script:s.Weekly
    Refresh-View
}

function Get-Item($tag) {
    $kind, $i = $tag -split '\|'
    if ($kind -eq 'd') { @($script:s.Today.tasks)[[int]$i] } else { @($script:s.Weekly)[[int]$i] }
}

function Toggle-Task($cb) {
    $item = Get-Item $cb.Tag
    $on = [bool]$cb.IsChecked
    if ($on -and -not (Confirm-Pin 'tick this off')) { $cb.IsChecked = $false; return }
    if ($cb.Tag.StartsWith('d')) { $item.done = $on } else { $item.doneWeek = $(if ($on) { $script:s.Week } else { '' }) }
    Show-Note ''
    [void]$win.Dispatcher.BeginInvoke([Action]{ Save-And-Refresh })
}

function Remove-Task($btn) {
    $item = Get-Item $btn.Tag
    $daily = $btn.Tag.StartsWith('d')
    $finished = if ($daily) { $item.done } else { $item.doneWeek -eq $script:s.Week }
    if (-not $finished -and -not (Confirm-Pin 'remove an unfinished task')) { return }
    if ($daily) { $script:s.Today.tasks = @($script:s.Today.tasks | Where-Object { $_ -ne $item }) }
    else { $script:s.Weekly = @($script:s.Weekly | Where-Object { $_ -ne $item }) }
    [void]$win.Dispatcher.BeginInvoke([Action]{ Save-And-Refresh })
}

# ---- Events ----
$ui.NewTask.add_TextChanged({ $ui.Placeholder.Visibility = if ($ui.NewTask.Text) { 'Collapsed' } else { 'Visible' } })

$ui.AddBtn.add_Click({
    $text = $ui.NewTask.Text.Trim()
    if (-not $text) { $ui.NewTask.Focus() | Out-Null; return }
    if ($ui.WeeklyToggle.IsChecked) {
        $script:s.Weekly = @($script:s.Weekly) + [pscustomobject]@{ text = $text; doneWeek = '' }
    } else {
        $script:s.Today.tasks = @($script:s.Today.tasks) + [pscustomobject]@{ text = $text; done = $false }
        $script:s.Today.noWork = $false
    }
    $ui.NewTask.Clear(); $ui.NewTask.Focus() | Out-Null
    Show-Note ''
    Save-And-Refresh
})

$ui.NoWorkBtn.add_Click({
    if (@($script:s.Today.tasks | Where-Object { -not $_.done }).Count -gt 0) {
        Show-Note 'Finish or remove today''s tasks first.' -Error
        return
    }
    if (-not (Confirm-Pin 'mark today as no work')) { return }
    $script:s.Today.noWork = $true
    Save-And-Refresh
})

$ui.PinBtn.add_Click({
    $pin = Get-Pin
    if ($pin -and $null -eq (Ask-Pin 'Enter the current PIN' { param($p) (Get-WLHash $p) -eq $pin })) { return }
    $new = Ask-Pin 'Choose a new PIN (leave it empty to remove the PIN)'
    if ($null -eq $new) { return }
    if ($new) { Set-Content $PinFile (Get-WLHash $new); Show-Note 'PIN set. Ticking tasks off now needs it.' }
    else { Remove-Item $PinFile -ErrorAction SilentlyContinue; Show-Note 'PIN removed.' }
    Refresh-View
})

$win.add_ContentRendered({ $ui.NewTask.Focus() | Out-Null })
Refresh-View
[void]$win.ShowDialog()
