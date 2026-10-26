#Requires -Version 5.1
<#
UnoRouter Free Monitor — трей-индикатор расходования квоты UnoRouter.
API: https://api.unorouter.com
  GET /v1/dashboard/billing/subscription  -> лимиты (hard_limit_usd, soft_limit_usd)
  GET /v1/dashboard/billing/usage?start_date&end_date -> расход (total_usage, в центах)
Ключ передаётся как Authorization: Bearer <ключ>.
#>
[CmdletBinding()]
param([switch]$Once)
$ErrorActionPreference='Stop'

$AppName    = 'UnoRouter Free Monitor'
$BaseUrl    = 'https://api.unorouter.com'
$LogFile    = Join-Path $PSScriptRoot 'unorouter-usage.log'
$MutexName  = 'Global\UnoRouterFreeMonitorTray'

function Log-Str($msg){
    try {
        Add-Content -LiteralPath $LogFile -Value ("[{0}] {1}" -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss'), $msg) -Encoding UTF8
        if ((Get-Item -LiteralPath $LogFile).Length -gt 200KB) {
            $tail = Get-Content -LiteralPath $LogFile -Tail 200
            Set-Content -LiteralPath $LogFile -Value $tail -Encoding UTF8
        }
    } catch {}
}

function Read-Config {
    $path = Join-Path $PSScriptRoot 'config.json'
    if (-not (Test-Path -LiteralPath $path)) { throw "Не найден config.json рядом со скриптом: $path" }
    $cfg = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace([string]$cfg.api_key)) {
        throw 'В config.json не заполнен api_key. Вставьте ключ UnoRouter (sk-...).'
    }
    $interval = 300
    if ($null -ne $cfg.update_interval) { try { $interval = [int]$cfg.update_interval } catch {} }
    if ($interval -lt 60 -or $interval -gt 3600) { $interval = 300 }
    return [pscustomobject]@{ api_key = ([string]$cfg.api_key).Trim(); update_interval = $interval }
}

function Invoke-Api($path, $cfg) {
    $headers = @{ 'Authorization' = 'Bearer ' + $cfg.api_key; 'Accept' = 'application/json' }
    $r = Invoke-WebRequest -Uri ($BaseUrl + $path) -Headers $headers -UseBasicParsing -TimeoutSec 20
    return ($r.Content | ConvertFrom-Json)
}

function Get-Usage($cfg) {
    $sub = Invoke-Api '/v1/dashboard/billing/subscription' $cfg
    $hard = 0.0; $soft = 0.0
    try { $hard = [double]$sub.hard_limit_usd } catch {}
    try { $soft = [double]$sub.soft_limit_usd } catch {}

    $today = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
    $tomorrow = (Get-Date).ToUniversalTime().AddDays(1).ToString('yyyy-MM-dd')
    $monthStart = (Get-Date).ToUniversalTime().ToString('yyyy-MM-01')

    $uToday = Invoke-Api ("/v1/dashboard/billing/usage?start_date={0}&end_date={1}" -f $today, $tomorrow) $cfg
    $uMonth = Invoke-Api ("/v1/dashboard/billing/usage?start_date={0}&end_date={1}" -f $monthStart, $tomorrow) $cfg

    # total_usage в центах
    $todayUsd = 0.0; $monthUsd = 0.0
    try { $todayUsd = [double]$uToday.total_usage / 100.0 } catch {}
    try { $monthUsd = [double]$uMonth.total_usage / 100.0 } catch {}

    $limit = if ($soft -gt 0 -and $soft -lt $hard) { $soft } else { $hard }
    $unlimited = ($limit -le 0 -or $limit -ge 1000000)

    $pct = 0
    if (-not $unlimited -and $limit -gt 0) {
        $pct = [int][math]::Round(($monthUsd / $limit) * 100, 0, [System.MidpointRounding]::AwayFromZero)
        if ($pct -lt 0) { $pct = 0 }
    }

    return [pscustomobject]@{
        todayUsd = $todayUsd
        monthUsd = $monthUsd
        limit    = $limit
        unlimited = $unlimited
        pct      = $pct
    }
}

if ($Once) {
    try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
    try {
        $cfg = Read-Config
        $u = Get-Usage $cfg
        $lim = if ($u.unlimited) { 'без лимита' } else { ('{0:N2} USD' -f $u.limit) }
        Write-Host ('UnoRouter: сегодня {0:N2} USD · месяц {1:N2} USD · лимит {2} · использовано {3}%' -f $u.todayUsd, $u.monthUsd, $lim, $u.pct)
        exit 0
    } catch {
        Write-Host ('ОШИБКА: ' + $_.Exception.Message) -ForegroundColor Red
        exit 1
    }
}

# ======================= трей =======================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function New-TrayIcon([int]$pct, [bool]$unlimited) {
    $bmp = New-Object System.Drawing.Bitmap(16,16)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    if ($pct -ge 90) { $c = [System.Drawing.Color]::FromArgb(220,50,50) }
    elseif ($pct -ge 70) { $c = [System.Drawing.Color]::FromArgb(230,150,40) }
    else { $c = [System.Drawing.Color]::FromArgb(0,140,220) }

    $g.FillEllipse((New-Object System.Drawing.SolidBrush $c), 1,1,14,14)

    $label = if ($unlimited) { 'U' } elseif ($pct -ge 100) { '!' } else { [string]$pct }
    $f = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString($label, $f, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(0,0,16,16)), $sf)
    $g.Dispose()

    $ico = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    $bmp.Dispose()
    return $ico
}

# один экземпляр
$created = $false
$mutex = New-Object System.Threading.Mutex($true, $MutexName, [ref]$created)
if (-not $created) { return }

$cfg = $null
$cfgError = $null
try { $cfg = Read-Config } catch { $cfgError = $_.Exception.Message }

$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = New-TrayIcon 0 $false
$tray.Text = 'UnoRouter: загрузка...'
$tray.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miRefresh = $menu.Items.Add('Обновить сейчас')
$miRefresh.Add_Click({ Refresh-Usage })
$menu.Items.Add('-') | Out-Null
$miLogin = $menu.Items.Add('Открыть кабинет UnoRouter')
$miLogin.Add_Click({ Start-Process 'https://unorouter.com/en/token' })
$menu.Items.Add('-') | Out-Null
$miExit = $menu.Items.Add('Выход')
$miExit.Add_Click({ $tray.Visible = $false; [System.Windows.Forms.Application]::Exit() })
$tray.ContextMenuStrip = $menu

$script:lastPct = -1

function Refresh-Usage {
    if (-not $script:cfg) {
        $tray.Text = ('UnoRouter: ' + ($script:cfgError -replace '\s+',' ')).Substring(0, [Math]::Min(63, ('UnoRouter: ' + $script:cfgError).Length))
        return
    }
    try {
        $u = Get-Usage $script:cfg
        $tray.Icon = New-TrayIcon $u.pct $u.unlimited
        $lim = if ($u.unlimited) { 'без лимита' } else { ('{0:N2} USD' -f $u.limit) }
        $tray.Text = ('UnoRouter: сегодня {0:N2}$ · месяц {1:N2}$ · {2}' -f $u.todayUsd, $u.monthUsd, $lim)
        if ($tray.Text.Length -gt 63) { $tray.Text = $tray.Text.Substring(0,60) + '...' }

        if (-not $u.unlimited -and $u.pct -ge 90 -and $script:lastPct -lt 90) {
            $tray.ShowBalloonTip(6000, 'UnoRouter: израсходовано 90% лимита',
                ('Месяц: {0:N2} из {1:N2} USD' -f $u.monthUsd, $u.limit),
                [System.Windows.Forms.ToolTipIcon]::Warning)
        }
        if (-not $u.unlimited -and $u.pct -lt 90) { }
        $script:lastPct = $u.pct
        Log-Str ('today={0:N2} month={1:N2} limit={2} pct={3}%' -f $u.todayUsd, $u.monthUsd, $lim, $u.pct)
    } catch {
        $tray.Text = 'UnoRouter: ошибка запроса'
        Log-Str ('ERROR: ' + $_.Exception.Message)
    }
}

$script:cfg = $cfg
$script:cfgError = $cfgError

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = if ($cfg) { $cfg.update_interval * 1000 } else { 300000 }
$timer.Add_Tick({ Refresh-Usage })
$timer.Start()

Refresh-Usage
[System.Windows.Forms.Application]::Run()

$tray.Visible = $false
$tray.Dispose()
