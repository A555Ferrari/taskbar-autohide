# TaskbarAutoHide

![Windows 10/11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows&logoColor=white)
![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)
![Version 1.0.6](https://img.shields.io/badge/Version-1.0.6-blue)
![License MIT](https://img.shields.io/badge/License-MIT-green)

**English** | [Deutsch](README.de.md)

Automatically hides the Windows taskbar when external monitors (or a docking station) are connected. On the laptop display alone, the taskbar stays visible.

No extra software, no admin rights, just PowerShell. No network access while running (only `Update.ps1` connects to GitHub when you start it), no telemetry.

## Why?

The Windows setting **"Automatically hide the taskbar"** (Settings → Personalization → Taskbar → Taskbar behaviors) is global. Windows has no rule like "only with an external monitor". This script flips the setting for you:

| Situation | Taskbar |
|---|---|
| Built-in display only | always visible |
| External monitor connected | auto-hidden |
| Docking station detected (optional) | auto-hidden |

Why PowerShell instead of AutoHotkey? It runs on any Windows 10/11 without installing anything, needs no admin rights, and is usually allowed on managed PCs where AutoHotkey often is not.

## Quick start

**One command to install and to update.** Open PowerShell (Start → type "PowerShell" → Enter), paste, press Enter:

```powershell
irm https://raw.githubusercontent.com/A555Ferrari/taskbar-autohide/main/Update.ps1 | iex
```

That's it. The command downloads the latest version from GitHub, installs it to a **fixed location** (nothing to choose, download or extract), starts the script and sets up autostart. No reboot and no admin rights needed. At the end it prints the status; with external monitors connected it shows `Auto-Hide aktuell: True` (the status output is in German).

It only runs when you start it, never automatically. You can read [Update.ps1](Update.ps1) first. If a company policy blocks the command, [INSTALL.de.md](INSTALL.de.md) has a ZIP alternative (German).

### Where is what?

| What | Where |
|---|---|
| Program, configuration, log | `%LOCALAPPDATA%\TaskbarAutoHide` (i.e. `C:\Users\<name>\AppData\Local\TaskbarAutoHide`) |
| Configuration | `config.json` in that folder, open with `tah config` |
| Log | `TaskbarAutoHide.log` in that folder, show with `tah log` |
| Autostart | Task Scheduler task `TaskbarAutoHide` and Run key `TaskbarAutoHide` |
| Update | Start menu → **TaskbarAutoHide aktualisieren** or `tah update` |

### What does the installation do?

- copies the files to `%LOCALAPPDATA%\TaskbarAutoHide` (an existing `config.json` is kept)
- unblocks the files (`Unblock-File`), because Windows may block downloaded scripts
- creates a scheduled task `TaskbarAutoHide`, a Run-key entry `TaskbarAutoHide` under `HKCU` and a Start menu entry for updating, and adds the install folder to your user PATH (for the `tah` command)
- sets an autostart entry in the user's Run key that starts the task (starting twice is harmless, only one instance ever runs)
- creates a Start menu entry **TaskbarAutoHide aktualisieren** ("update")
- sets up the `tah` command (install folder added to your user PATH, available in new terminals)
- if scheduled tasks are not allowed: falls back to a shortcut in the Startup folder

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
| `pauseWhileRunning` | Process names (without `.exe`). While one of them is running, the script leaves the taskbar alone. Default: the Safe Exam Browser (`SafeExamBrowser`, `SafeExamBrowser.Client`, `SafeExamBrowser.Runtime`, `SebWindowsClient`). |

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

## Commands

After installing there is the `tah` command. It works in a **new** terminal (close and reopen a window that was already open).

| Command | What it does |
|---|---|
| `tah status` | version, is the script running?, detected monitors, current state |
| `tah update` | install the latest version from GitHub |
| `tah log` | last lines of the log |
| `tah config` | open `config.json` in an editor |
| `tah start` / `tah restart` | start / restart the script |
| `tah stop` | stop the script (the watchdog restarts it within 5 minutes; to remove it for good use `tah uninstall`) |
| `tah pause` / `tah resume` | switch the script and its autostart off completely (e.g. before an exam) and back on |
| `tah version` | show the installed version |
| `tah uninstall` | remove everything |
| `tah help` | command overview |

The log is written on state changes and trimmed automatically at 200 KB. To test hiding you can also run `& "$env:LOCALAPPDATA\TaskbarAutoHide\TaskbarAutoHide.ps1" -Force Hide` or `-Force Show`.

## Exams (Safe Exam Browser)

While the Safe Exam Browser (SEB) is running, the script pauses on its own: it does not touch the taskbar and does not query monitors. When SEB ends, it continues and re-applies the state. `tah status` shows `Pausiert (Pruefung): JA`.

If your exam setup also forbids or kills other processes (e.g. PowerShell) or checks for background programs, switch the tool off completely beforehand with `tah pause`, and back on afterwards with `tah resume`. Another exam program can be added to `pauseWhileRunning` in `config.json` (find the process name with `Get-Process`).

## Uninstall

```powershell
tah uninstall
```

After a confirmation prompt this removes the scheduled task, the Run-key entry, the Start menu entry, the PATH entry and the install folder, stops the process and sets the taskbar back to "always visible".

## Troubleshooting

Always start with `tah status` and `tah log`. The output helps with any question.

**The taskbar no longer switches.**
If `Script laeuft` says **NEIN**, the background process is not running. `tah start` starts it. Since version 1.0.2 the scheduled task checks every 5 minutes and restarts it on its own. On an older version, run the one-liner from the quick start again.

**`tah` is not found.**
Open a new terminal; the PATH entry only applies to windows started after the installation. It always works with `& "$env:LOCALAPPDATA\TaskbarAutoHide\tah.cmd" status`.

**The one-liner is blocked or fails with an error.**
Usually a company policy or proxy. Use the ZIP variant in [INSTALL.de.md](INSTALL.de.md) (German).

**The taskbar slides out by itself.**
Usually an app is flashing (e.g. Teams on a new message), which Windows signals this way. In Windows Settings under Personalization → Taskbar → Taskbar behaviors you can turn off flashing for taskbar apps.

**0 external monitors detected although one is connected.**
Check whether `Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorConnectionParams` returns values. If not, the fallback (screen count minus one) applies.

**The taskbar hides even without an external monitor.**
In `monitors` mode, check whether Windows reports a "virtual" display (e.g. remote session, virtual display drivers). `tah status` shows the count.

**The dock is not detected.**
Run `Find-Dock.ps1` again and choose a more specific pattern. Don't forget wildcards (`*`) before and after.

**A window flashes briefly at sign-in.**
Normal when the hidden PowerShell process starts. It disappears immediately.

## What does the script change on the system?

Transparent and small, all in user context:

- toggles the taskbar "auto-hide" setting (through the Windows API, like Settings itself)
- stores files in `%LOCALAPPDATA%\TaskbarAutoHide` (script, `config.json`, log)
- creates a scheduled task `TaskbarAutoHide`, a Run-key entry `TaskbarAutoHide` under `HKCU` and a Start menu entry for updating, and adds the install folder to your user PATH (for the `tah` command)
- reads monitor and device information via WMI / `Get-PnpDevice`
- **no** network connections while running (only `Update.ps1` connects to github.com when you start it), **no** admin rights, **no** changes to system settings or policies

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
| `Update.ps1` | Downloads the latest version from GitHub and installs it |
| `Manage.ps1`, `tah.cmd` | The `tah` command (status, update, log, ...) |
| `config.json` | Default configuration |
| `README.de.md` | German documentation |
| `INSTALL.de.md` | Step-by-step install guide for beginners (German) |
| `CHANGELOG.md` | Changes per version |
| `LICENSE` | MIT license |

## License

MIT, see [LICENSE](LICENSE).
