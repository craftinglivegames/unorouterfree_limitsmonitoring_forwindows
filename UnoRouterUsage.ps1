#Requires -Version 5.1
<#
UnoRouter Free Monitor — трей-индикатор бесплатной квоты UnoRouter.
Опрос: GET https://openrouter.ai/api/v1/key (т.к. UnoRouter использует тот же endpoint).
#>
param([switch]$Once)
$ErrorActionPreference='Stop'
$script:AppName='UnoRouter Free Monitor'
$script:ApiUrl='https://openrouter.ai/api/v1/key'
$script:LogFile=Join-Path $PSScriptRoot 'unorouter-usage.log'
function Read-Config{
  $c=Get-Content (Join-Path $PSScriptRoot 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if([string]::IsNullOrWhiteSpace($c.api_key)) { throw 'В config.json не заполнен api_key. Вставьте ключ из UnoRouter (sk-...).' }
  return $c
}
function Get-Usage($cfg){
  $h=@{'Authorization'='Bearer '+$cfg.api_key;'Accept'='application/json'}
  $r=Invoke-WebRequest -Uri $script:ApiUrl -Headers $h -UseBasicParsing -TimeoutSec 20
  $d=$r.Content|ConvertFrom-Json
  $m=$d.data.free_model_daily_requests
  $used=[int][string]$m.used; $limit=[int][string]$m.limit
  $pct=[int][math]::Round(($used/$limit)*100,0,[System.MidpointRounding]::AwayFromZero)
  $rem=[int][string]$m.remaining
  return [pscustomobject]@{used=$used;limit=$limit;pct=$pct;remaining=$rem}
}
if($Once){
  try{[Console]::OutputEncoding=[Text.Encoding]::UTF8}catch{}
  try{$cfg=Read-Config;$r=Get-Usage $cfg;Write-Host ("UnoRouter: {0}% использовано ({1}/{2}), осталось {3}" -f $r.pct,$r.used,$r.limit,$r.remaining);exit 0}catch{Write-Host ("ОШИБКА: "+$_);exit 1}
}
# --- трей режим (основной) ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$tray=New-Object System.Windows.Forms.NotifyIcon
function Icon($p){
  $b=New-Object System.Drawing.Bitmap(16,16); $g=[System.Drawing.Graphics]::FromImage($b); $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias; $g.Clear([System.Drawing.Color]::Transparent)
  $col=if($p -ge 100){[System.Drawing.Color]::FromArgb(200,30,30)}elseif($p -ge 90){[System.Drawing.Color]::FromArgb(220,50,50)}elseif($p -ge 70){[System.Drawing.Color]::FromArgb(230,150,40)}else{[System.Drawing.Color]::FromArgb(40,150,90)}
  $g.FillEllipse((New-Object System.Drawing.SolidBrush $col),1,1,14,14)
  $label=if($p -ge 100){'!'}else{[string]$p}
  $f=New-Object System.Drawing.Font('Segoe UI',8,[System.Drawing.FontStyle]::Bold); $sf=New-Object System.Drawing.StringFormat; $sf.Alignment=[System.Drawing.StringAlignment]::Center; $sf.LineAlignment=[System.Drawing.StringAlignment]::Center
  $g.DrawString($label,$f,[System.Drawing.Brushes]::White,(New-Object System.Drawing.RectangleF(0,0,16,16)),$sf); $g.Dispose()
  $i=[System.Drawing.Icon]::FromHandle($b.GetHicon()); $b.Dispose(); return $i
}
$tray.Icon=Icon -p 0; $tray.Visible=$true; $tray.Text='UnoRouter: загрузка...'
$menu=New-Object System.Windows.Forms.ContextMenuStrip
$miR=$menu.Items.Add('Обновить'); $miR.Add_Click({Refresh})
$menu.Items.Add('-')|Out-Null; $miO=$menu.Items.Add('Ключи UnoRouter'); $miO.Add_Click({Start-Process 'https://openrouter.ai/keys'})
$menu.Items.Add('-')|Out-Null; $miX=$menu.Items.Add('Выход'); $miX.Add_Click({$tray.Visible=$false;[System.Windows.Forms.Application]::Exit()})
$tray.ContextMenuStrip=$menu
$cfg=Read-Config
function Refresh{
  try{$r=Get-Usage $cfg; $tray.Icon=Icon -p $r.pct; $tray.Text="UnoRouter: {0}% ({1}/{2}) | Осталось {3}" -f $r.pct,$r.used,$r.limit,$r.remaining; if($r.pct -ge 90 -and $script:last -ne 100){$tray.ShowBalloonTip(5000,'UnoRouter: лимит почти исчерпан',("Осталось {0}" -f $r.remaining),[System.Windows.Forms.ToolTipIcon]::Warning)}; if($r.pct -ge 100 -and $script:last -lt 100){$tray.ShowBalloonTip(5000,'UnoRouter: лимит исчерпан','Бесплатные запросы на сегодня закончились',[System.Windows.Forms.ToolTipIcon]::Error)}; $script:last=$r.pct; Add-Content $script:LogFile ("[{0}] {1}% {2}/{3}" -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss'),$r.pct,$r.used,$r.limit)-Encoding UTF8}catch{Add-Content $script:LogFile ("ERROR: "+$_)-Encoding UTF8}\ntry{[IO.File]::WriteAllText($script:LogFile, (Get-Content $script:LogFile -Raw | Select-String -Pattern 'ERROR' -NotMatch | Out-String).Trim(), [Text.Encoding]::UTF8)}catch{}\n}\n$script:last=-1\nRefresh\n$timer=New-Object System.Windows.Forms.Timer; $timer.Interval=$cfg.update_interval*1000; $timer.Add_Tick({Refresh}); $timer.Start()\n[System.Windows.Forms.Application]::Run(); $tray.Visible=$false; $tray.Dispose()\n