<#
.SYNOPSIS
    Blendet die Windows-Taskleiste automatisch aus, sobald externe Bildschirme
    (oder eine Dockingstation) angeschlossen sind, und zeigt sie wieder dauerhaft
    an, sobald man nur noch am internen Display arbeitet.

.DESCRIPTION
    Laeuft als Hintergrundschleife. Alle pollSeconds Sekunden wird geprueft, ob
    "angedockt" ist (siehe config.json, mode). Aendert sich der Zustand, wird
    "Taskleiste automatisch ausblenden" umgeschaltet - ohne Explorer-Neustart,
    ueber SHAppBarMessage (ABM_SETSTATE).

.PARAMETER Once
    Einmal pruefen, Zustand setzen, beenden.

.PARAMETER Status
    Zeigt Modus, erkannte Monitore, Dock-Status und aktuellen Auto-Hide-Zustand.

.PARAMETER Force
    Erzwingt Hide oder Show (einmalig), unabhaengig von der Erkennung. Zum Testen.

.PARAMETER ConfigPath
    Pfad zur config.json (Standard: neben dem Script).

.EXAMPLE
    .\TaskbarAutoHide.ps1 -Status

.EXAMPLE
    .\TaskbarAutoHide.ps1 -Force Hide
#>
[CmdletBinding()]
param(
    [switch]$Once,
    [switch]$Status,
    [ValidateSet('Hide', 'Show')][string]$Force,
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot ist im param()-Block nicht zuverlaessig gesetzt, daher hier ermitteln.
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $ConfigPath) { $ConfigPath = Join-Path $ScriptDir 'config.json' }
$LogPath = Join-Path $ScriptDir 'TaskbarAutoHide.log'

# --- Native Aufrufe ----------------------------------------------------------
if (-not ('TaskbarNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class TaskbarNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int left, top, right, bottom; }

    [StructLayout(LayoutKind.Sequential)]
    public struct APPBARDATA
    {
        public uint cbSize;
        public IntPtr hWnd;
        public uint uCallbackMessage;
        public uint uEdge;
        public RECT rc;
        public IntPtr lParam;
    }

    [DllImport("shell32.dll")]
    static extern UIntPtr SHAppBarMessage(uint dwMessage, ref APPBARDATA pData);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    const uint ABM_GETSTATE = 4;
    const uint ABM_SETSTATE = 10;
    const long ABS_AUTOHIDE = 1;

    static APPBARDATA NewData()
    {
        APPBARDATA d = new APPBARDATA();
        d.cbSize = (uint)Marshal.SizeOf(typeof(APPBARDATA));
        d.hWnd = FindWindow("Shell_TrayWnd", null);
        return d;
    }

    public static long TrayHandle()
    {
        return FindWindow("Shell_TrayWnd", null).ToInt64();
    }

    public static bool GetAutoHide()
    {
        APPBARDATA d = NewData();
        long state = (long)SHAppBarMessage(ABM_GETSTATE, ref d).ToUInt64();
        return (state & ABS_AUTOHIDE) != 0;
    }

    public static void SetAutoHide(bool on)
    {
        APPBARDATA d = NewData();
        long state = (long)SHAppBarMessage(ABM_GETSTATE, ref d).ToUInt64();
        // Andere Flags (z.B. "immer im Vordergrund") unveraendert lassen
        state = on ? (state | ABS_AUTOHIDE) : (state & ~ABS_AUTOHIDE);
        d.lParam = (IntPtr)state;
        SHAppBarMessage(ABM_SETSTATE, ref d);
    }
}
'@
}

# --- Hilfsfunktionen ---------------------------------------------------------
function Write-Log([string]$Message) {
    $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Message
    try {
        if ((Test-Path $LogPath) -and ((Get-Item $LogPath).Length -gt 200KB)) {
            Get-Content $LogPath -Tail 100 | Set-Content $LogPath
        }
        Add-Content -Path $LogPath -Value $line
    } catch { }
    Write-Host $line
}

function Get-Config {
    $cfg = [ordered]@{
        mode               = 'monitors'
        minExternalMonitors = 1
        dockMatch          = @()
        pollSeconds        = 5
    }
    if (Test-Path $ConfigPath) {
        try {
            $json = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            foreach ($k in @($cfg.Keys)) {
                if ($null -ne $json.$k) { $cfg[$k] = $json.$k }
            }
        } catch {
            Write-Log "config.json nicht lesbar, nutze Standardwerte: $($_.Exception.Message)"
        }
    }
    $cfg.dockMatch = @($cfg.dockMatch)
    if ($cfg.mode -notin 'monitors', 'dock', 'either') { $cfg.mode = 'monitors' }
    $cfg.minExternalMonitors = [Math]::Max(1, [int]$cfg.minExternalMonitors)
    $cfg.pollSeconds = [Math]::Max(2, [int]$cfg.pollSeconds)
    $cfg
}

# Anzahl aktiver Bildschirme, die NICHT das interne Laptop-Display sind.
function Get-ExternalMonitorCount {
    try {
        # VideoOutputTechnology: 0x80000000 = intern, 11 = eDP (intern), 13 = UDI intern
        $internal = @(2147483648, 11, 13)
        $active = @(Get-CimInstance -Namespace 'root\wmi' -ClassName WmiMonitorConnectionParams |
            Where-Object { $_.Active })
        $count = 0
        foreach ($m in $active) {
            $t = [int64]$m.VideoOutputTechnology
            if ($t -lt 0) { $t += 4294967296 }
            if ($internal -notcontains $t) { $count++ }
        }
        return $count
    } catch {
        # Fallback: Anzahl Bildschirme minus 1 (Annahme: ein internes Display)
        Add-Type -AssemblyName System.Windows.Forms
        return [Math]::Max(0, [System.Windows.Forms.Screen]::AllScreens.Count - 1)
    }
}

# Prueft, ob ein angeschlossenes Geraet zu einem der Muster passt (Wildcards, z.B. "*Dock*").
function Test-DockPresent([string[]]$Patterns) {
    $devices = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue
    foreach ($d in $devices) {
        foreach ($p in $Patterns) {
            if ($d.FriendlyName -like $p -or $d.InstanceId -like $p) { return $true }
        }
    }
    return $false
}

function Get-DockState($cfg) {
    $ext = Get-ExternalMonitorCount
    $dock = $false
    if ($cfg.mode -ne 'monitors' -and $cfg.dockMatch.Count -gt 0) {
        $dock = Test-DockPresent $cfg.dockMatch
    }
    $docked = switch ($cfg.mode) {
        'monitors' { $ext -ge $cfg.minExternalMonitors }
        'dock'     { $dock }
        'either'   { ($ext -ge $cfg.minExternalMonitors) -or $dock }
    }
    [pscustomobject]@{
        ExternalMonitors = $ext
        DockPresent      = $dock
        Docked           = [bool]$docked
    }
}

function Set-AutoHide([bool]$On) {
    if ([TaskbarNative]::GetAutoHide() -ne $On) {
        [TaskbarNative]::SetAutoHide($On)
        return $true
    }
    return $false
}

# --- Einmalige Aktionen ------------------------------------------------------
if ($Force) {
    [void](Set-AutoHide ($Force -eq 'Hide'))
    Write-Log "Erzwungen: Taskleiste $(if ($Force -eq 'Hide') { 'ausgeblendet' } else { 'immer sichtbar' })"
    return
}

if ($Status) {
    $cfg = Get-Config
    $state = Get-DockState $cfg
    $verFile = Join-Path $ScriptDir 'VERSION'
    $version = if (Test-Path $verFile) { (Get-Content $verFile -Raw).Trim() } else { 'unbekannt' }
    $mtx = $null
    $running = [System.Threading.Mutex]::TryOpenExisting('Local\TaskbarAutoHide', [ref]$mtx)
    if ($mtx) { $mtx.Dispose() }
    "Version:                $version"
    "Script laeuft:          $(if ($running) { 'Ja' } else { 'NEIN (starten: Start-ScheduledTask -TaskName TaskbarAutoHide)' })"
    "Modus:                  $($cfg.mode)"
    "Externe Monitore:       $($state.ExternalMonitors) (Schwelle: $($cfg.minExternalMonitors))"
    "Dock-Muster:            $(if ($cfg.dockMatch.Count) { $cfg.dockMatch -join ', ' } else { '(keine)' })"
    "Dock erkannt:           $($state.DockPresent)"
    "Gilt als angedockt:     $($state.Docked)"
    "Auto-Hide aktuell:      $([TaskbarNative]::GetAutoHide())"
    return
}

if ($Once) {
    $cfg = Get-Config
    $state = Get-DockState $cfg
    if (Set-AutoHide $state.Docked) {
        Write-Log "Einmalig gesetzt: Auto-Hide = $($state.Docked)"
    }
    return
}

# --- Dauerbetrieb ------------------------------------------------------------
$mutex = New-Object System.Threading.Mutex($false, 'Local\TaskbarAutoHide')
if (-not $mutex.WaitOne(0)) {
    Write-Host 'TaskbarAutoHide laeuft bereits.'
    return
}

Write-Log 'Gestartet'
$lastDocked = $null
$lastTray = 0L

try {
    while ($true) {
        try {
            $cfg = Get-Config          # jedes Mal neu lesen: Aenderungen wirken ohne Neustart
            $state = Get-DockState $cfg
            $tray = [TaskbarNative]::TrayHandle()

            # Anwenden bei Zustandswechsel oder wenn der Explorer neu gestartet wurde
            if ($state.Docked -ne $lastDocked -or $tray -ne $lastTray) {
                [void](Set-AutoHide $state.Docked)
                Write-Log ("Monitore extern: {0}, Dock: {1} -> Taskleiste {2}" -f `
                        $state.ExternalMonitors, $state.DockPresent,
                    $(if ($state.Docked) { 'ausgeblendet' } else { 'immer sichtbar' }))
                $lastDocked = $state.Docked
                $lastTray = $tray
            }
        } catch {
            Write-Log "Fehler: $($_.Exception.Message)"
        }
        Start-Sleep -Seconds $cfg.pollSeconds
    }
} finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
