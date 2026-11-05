# TaskbarAutoHide

![Windows 10/11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows&logoColor=white)
![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)
![Version 1.0.2](https://img.shields.io/badge/Version-1.0.2-blue)
![License MIT](https://img.shields.io/badge/License-MIT-green)

**English** | [Deutsch](README.de.md)

Automatically hides the Windows taskbar when external monitors (or a docking station) are connected. On the laptop display alone, the taskbar stays visible.

No extra software, no admin rights, just PowerShell. No network access, no telemetry.

## Why?

The Windows setting **"Automatically hide the taskbar"** (Settings → Personalization → Taskbar → Taskbar behaviors) is global. Windows has no rule like "only with an external monitor". This script flips the setting for you:

| Situation | Taskbar |
|---|---|
| Built-in display only | always visible |
| External monitor connected | auto-hidden |
| Docking station detected (optional) | auto-hidden |

Why PowerShell instead of AutoHotkey? It runs on any Windows 10/11 without installing anything, needs no admin rights, and is usually allowed on managed PCs where AutoHotkey often is not.

## Quick start

1. Download the repo as a ZIP and **extract it into its own folder**. Note: extracting often creates a folder inside a folder. Change into the inner one, where `Install.ps1` sits directly.
2. Open PowerShell and go there:

   ```powershell
   cd "C:\Users\YOUR_NAME\Downloads\taskbar-autohide\taskbar-autohide"
   ```

3. Install:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Install.ps1
   ```

That's it. The installer starts the script immediately and again at every sign-in. No reboot needed. At the end it prints the current status; with external monitors connected it should show `Auto-Hide aktuell: True` (the status output is in German).

What `Install.ps1` does:

- copies the files to `%LOCALAPPDATA%\TaskbarAutoHide` (an existing `config.json` is kept)
- unblocks the files (`Unblock-File`), because Windows may block downloaded scripts
- creates a scheduled task `TaskbarAutoHide` with two triggers (at sign-in, and every 5 minutes as a watchdog that restarts the script if it is no longer running) and starts it
- additionally sets an autostart entry in the user's Run key that starts the task (starting twice is harmless, only one instance ever runs)
- if scheduled tasks are not allowed: falls back to a shortcut in the Startup folder

Set the mode right at install time:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install.ps1 -Mode either
```

## How it works

1. A background process checks every few seconds (default: 5) whether the PC is "docked".
2. On a state change, auto-hide is toggled through the Windows API `SHAppBarMessage` with `ABM_SETSTATE`. This is the same mechanism the Settings app uses, just without restarting Explorer.
3. External monitors are detected via WMI (`WmiMonitorConnectionParams`). The built-in laptop display is not counted. If WMI returns nothing, the fallback is "screen count minus one".
4. Windows does not expose docking stations directly. Optionally, the script looks for a device that is only present with the dock (e.g. its USB hub or network adapter).
5. If Explorer restarts (crash, restart), the script re-applies the state on its own.
6. A manually changed setting is not constantly overridden. The script only acts when the state flips between "docked" and "not docked".

The configuration is re-read on every cycle, so changes to `config.json` take effect without a restart.

## Configuration

File: `%LOCALAPPDATA%\TaskbarAutoHide\config.json`

```json
{
  "mode": "monitors",
  "minExternalMonitors": 1,
  "dockMatch": [],
  "pollSeconds": 5
}
```

| Field | Meaning |
|---|---|
| `mode` | `monitors`: hide when external monitors are present. `dock`: hide when the dock is detected. `either`: either one is enough. |
| `minExternalMonitors` | How many external monitors count as "docked" (default 1). |
| `dockMatch` | List of wildcard patterns, e.g. `["*Dell Dock*"]`, matched against device name and instance ID. Only relevant for `dock` and `either`. |
| `pollSeconds` | Check interval in seconds (minimum 2). Use about 10 in dock mode, the device query is a bit slower. |

## Setting up a docking station

In practice a monitor is almost always attached to the dock, so `mode: monitors` is enough. To detect the dock even without a monitor, find the right pattern with a before/after comparison:

```powershell
# 1. With the dock unplugged:
.\Find-Dock.ps1 -Save

# 2. Plug in the dock, then:
.\Find-Dock.ps1 -Compare
```

The output lists all devices that only appeared with the dock. Pick a unique name (e.g. the dock's network adapter or hub), put it into `dockMatch`, and set `mode` to `dock` or `either`.

```json
{
  "mode": "either",
  "minExternalMonitors": 1,
  "dockMatch": ["*USB GbE*"],
  "pollSeconds": 10
}
```

## Testing and status

```powershell
$s = "$env:LOCALAPPDATA\TaskbarAutoHide\TaskbarAutoHide.ps1"

& $s -Status        # mode, detected monitors, dock, current state
& $s -Force Hide    # force auto-hide once
& $s -Force Show    # show the taskbar permanently once
& $s -Once          # check and apply once, then exit
```

Start the process manually:

```powershell
Start-ScheduledTask -TaskName TaskbarAutoHide
```

Log: `%LOCALAPPDATA%\TaskbarAutoHide\TaskbarAutoHide.log` (written on state changes, trimmed automatically at 200 KB).

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

This removes the scheduled task, the Run-key entry and the Startup shortcut, stops the process and sets the taskbar back to "always visible". Options:

- `-KeepAutoHide`: do not set the taskbar back to "always visible"
- `-RemoveFiles`: also delete `%LOCALAPPDATA%\TaskbarAutoHide` (run it from the repo folder)

## Troubleshooting

**`Install.ps1` is not found.**
You are in the wrong folder. After extracting, the file is often one level deeper. `Get-ChildItem -Path $env:USERPROFILE -Recurse -Filter Install.ps1 -ErrorAction SilentlyContinue | Select-Object FullName` finds it.

**It stops working after sign-out or reboot.**
Since version 1.0.2 the scheduled task checks every 5 minutes whether the script is running and restarts it if not (on top of the sign-in trigger and the Run key), so after a sign-out, hibernation or reboot it can take up to 5 minutes until it is back. On an older version, just run `Install.ps1` again. Check with `Get-ScheduledTask -TaskName TaskbarAutoHide | Get-ScheduledTaskInfo` (`LastRunTime` should be your last sign-in); `Start-ScheduledTask -TaskName TaskbarAutoHide` starts it by hand.

**The taskbar stays visible after installing.**
Run `-Status`. If it says `Gilt als angedockt: True` but `Auto-Hide aktuell: False`, the background process is not running. Run `Start-ScheduledTask -TaskName TaskbarAutoHide` and check the log.

**0 external monitors detected although one is connected.**
Check whether `Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorConnectionParams` returns values. If not, the fallback (screen count minus one) applies.

**The taskbar hides even without an external monitor.**
In `monitors` mode, check whether Windows reports a "virtual" display (e.g. remote session, virtual display drivers). `-Status` shows the count.

**The dock is not detected.**
Run `Find-Dock.ps1` again and choose a more specific pattern. Don't forget wildcards (`*`) before and after.

**ExecutionPolicy error.**
Always call with `-ExecutionPolicy Bypass` as shown above. If a group policy (AppLocker, Constrained Language Mode) enforces otherwise, the script will not work there.

**A window flashes briefly at sign-in.**
Normal when the hidden PowerShell process starts. It disappears immediately.

## What does the script change on the system?

Transparent and small, all in user context:

- toggles the taskbar "auto-hide" setting (through the Windows API, like Settings itself)
- stores files in `%LOCALAPPDATA%\TaskbarAutoHide` (script, `config.json`, log)
- creates a scheduled task `TaskbarAutoHide` and a Run-key entry `TaskbarAutoHide` under `HKCU`
- reads monitor and device information via WMI / `Get-PnpDevice`
- **no** network connections, **no** admin rights, **no** changes to system settings or policies

`Uninstall.ps1` removes everything again. The source is short enough to read before installing.

## Notes and limits

- Auto-hide applies to all taskbars. Per-monitor behavior is not possible in Windows.
- Runs only while you are signed in (user context).
- On managed PCs, check beforehand whether scripts and scheduled tasks are allowed and whether the taskbar setting is locked by policy.
- Tested: `monitors` mode on Windows 11 with two external monitors (hiding confirmed). Dock mode (`dock`, `either`) has not been verified on real hardware yet.

## Files

| File | Purpose |
|---|---|
| `TaskbarAutoHide.ps1` | Main script (continuous mode, `-Status`, `-Force`, `-Once`) |
| `Install.ps1` | Installation incl. autostart |
| `Uninstall.ps1` | Removes everything |
| `Find-Dock.ps1` | Finds a detection pattern for the docking station |
| `config.json` | Default configuration |
| `README.de.md` | German documentation |
| `CHANGELOG.md` | Changes per version |
| `LICENSE` | MIT license |

## License

MIT, see [LICENSE](LICENSE).
