# TaskbarAutoHide

![Windows 10/11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows&logoColor=white)
![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)
![Version 1.0.4](https://img.shields.io/badge/Version-1.0.4-blue)
![Lizenz MIT](https://img.shields.io/badge/Lizenz-MIT-green)

[English](README.md) | **Deutsch**

Blendet die Windows-Taskleiste automatisch aus, sobald externe Bildschirme (oder eine Dockingstation) angeschlossen sind. Nur am Laptop-Display bleibt sie dauerhaft sichtbar.

Ohne Zusatzsoftware, ohne Admin-Rechte, nur PowerShell. Kein Netzwerkzugriff im Betrieb (nur `Update.ps1` lädt auf deinen Befehl die neueste Version von GitHub), keine Telemetrie.

## Inhalt

- [Warum?](#warum)
- [Schnellstart](#schnellstart)
- [Wie funktioniert es?](#wie-funktioniert-es)
- [Konfiguration](#konfiguration)
- [Dockingstation einrichten](#dockingstation-einrichten)
- [Befehle](#befehle)
- [Deinstallation](#deinstallation)
- [Fehlersuche](#fehlersuche)
- [Hinweise und Grenzen](#hinweise-und-grenzen)
- [Dateien](#dateien)

## Warum?

Die Windows-Einstellung **"Taskleiste automatisch ausblenden"** (Einstellungen → Personalisierung → Taskleiste → Verhalten der Taskleiste) gilt global. Windows kennt keine Regel wie "nur mit externem Monitor". Dieses Script schaltet die Einstellung automatisch um:

| Situation | Taskleiste |
|---|---|
| Nur internes Display | immer sichtbar |
| Externer Monitor angeschlossen | automatisch ausgeblendet |
| Dockingstation erkannt (optional) | automatisch ausgeblendet |

Warum PowerShell statt AutoHotkey? Es läuft auf jedem Windows 10/11 ohne Installation, braucht keine Admin-Rechte und ist auf Firmen-PCs meist erlaubt, wo AutoHotkey oft gesperrt ist.

## Schnellstart

**Ein Befehl für Installieren und Aktualisieren.** PowerShell öffnen (Start → "PowerShell" tippen → Enter), einfügen, Enter:

```powershell
irm https://raw.githubusercontent.com/A555Ferrari/taskbar-autohide/main/Update.ps1 | iex
```

Das war's. Der Befehl lädt die neueste Version von GitHub, installiert sie an einen **festen Ort** (du musst nichts auswählen, herunterladen oder entpacken), startet das Script und richtet den Autostart ein. Neustart und Admin-Rechte sind nicht nötig. Am Ende kommt der Status, mit externem Monitor steht dort `Auto-Hide aktuell: True`.

Es läuft nur, wenn du es selbst startest, nie automatisch. Du kannst [Update.ps1](Update.ps1) vorher lesen. Blockiert eine Firmenrichtlinie den Befehl, gibt es in [INSTALL.de.md](INSTALL.de.md) eine Alternative mit ZIP.

### Wo liegt was?

| Was | Wo |
|---|---|
| Programm, Konfiguration, Log | `%LOCALAPPDATA%\TaskbarAutoHide` (also `C:\Users\<Name>\AppData\Local\TaskbarAutoHide`) |
| Konfiguration | `config.json` in diesem Ordner, öffnen mit `tah config` |
| Log | `TaskbarAutoHide.log` in diesem Ordner, anzeigen mit `tah log` |
| Autostart | Aufgabenplanung `TaskbarAutoHide` und Run-Key `TaskbarAutoHide` |
| Aktualisieren | Startmenü → **TaskbarAutoHide aktualisieren** oder `tah update` |

### Was passiert bei der Installation?

- Dateien nach `%LOCALAPPDATA%\TaskbarAutoHide` kopieren (eine vorhandene `config.json` bleibt erhalten)
- Dateien entsperren (`Unblock-File`), weil Windows heruntergeladene Scripts sonst blockieren kann
- geplante Aufgabe `TaskbarAutoHide` mit zwei Auslösern anlegen (bei der Anmeldung und alle 5 Minuten als Wächter, der das Script neu startet, falls es nicht mehr läuft) und starten
- Autostart-Eintrag im Run-Key des Benutzers setzen, der die Aufgabe startet (doppelter Start ist harmlos, es läuft immer nur eine Instanz)
- Startmenü-Eintrag **TaskbarAutoHide aktualisieren** anlegen
- den Befehl `tah` einrichten (Installationsordner im Benutzer-PATH, gilt nur in neuen Terminals)
- falls geplante Aufgaben nicht erlaubt sind: Verknüpfung im Autostart-Ordner als Fallback

## Wie funktioniert es?

1. Ein Hintergrundprozess prüft alle paar Sekunden (Standard: 5), ob "angedockt" ist.
2. Bei einem Zustandswechsel wird Auto-Hide über die Windows-API `SHAppBarMessage` mit `ABM_SETSTATE` umgeschaltet. Das ist derselbe Mechanismus wie in den Einstellungen, nur ohne Explorer-Neustart.
3. Externe Monitore werden über WMI (`WmiMonitorConnectionParams`) erkannt. Das interne Laptop-Display zählt dabei nicht mit. Falls WMI nichts liefert, gilt als Fallback "Bildschirmanzahl minus 1".
4. Dockingstationen erkennt Windows nicht direkt. Optional wird deshalb nach einem Gerät gesucht, das nur mit Dock vorhanden ist (z.B. USB-Hub oder Netzwerkadapter der Dock).
5. Startet der Explorer neu (Absturz, Neustart), setzt das Script den Zustand von selbst wieder.
6. Eine manuell geänderte Einstellung wird nicht ständig überschrieben. Das Script greift nur bei einem Wechsel zwischen "angedockt" und "nicht angedockt" ein.

Die Konfiguration wird bei jedem Durchlauf neu gelesen, Änderungen an `config.json` wirken also ohne Neustart.

## Konfiguration

Datei: `%LOCALAPPDATA%\TaskbarAutoHide\config.json`

```json
{
  "mode": "monitors",
  "minExternalMonitors": 1,
  "dockMatch": [],
  "pollSeconds": 5
}
```

| Feld | Bedeutung |
|---|---|
| `mode` | `monitors`: ausblenden, wenn externe Monitore da sind. `dock`: ausblenden, wenn die Dock erkannt wird. `either`: eines von beiden reicht. |
| `minExternalMonitors` | Ab wie vielen externen Monitoren gilt es als "angedockt" (Standard 1). |
| `dockMatch` | Liste von Mustern (Wildcards), z.B. `["*Dell Dock*"]`. Geprüft wird gegen Gerätename und Instanz-ID. Nur relevant bei `dock` und `either`. |
| `pollSeconds` | Prüfintervall in Sekunden (mindestens 2). Im Dock-Modus eher 10 nehmen, die Geräteabfrage ist etwas träger. |

## Dockingstation einrichten

In der Praxis hängt an der Dock fast immer ein Monitor, dann reicht `mode: monitors` völlig aus. Willst du die Dock auch ohne Monitor erkennen, findest du das passende Muster mit einem Vorher/Nachher-Vergleich:

```powershell
# 1. Dock abgesteckt:
.\Find-Dock.ps1 -Save

# 2. Dock anschliessen, dann:
.\Find-Dock.ps1 -Compare
```

Die Ausgabe zeigt alle Geräte, die erst mit Dock aufgetaucht sind. Nimm einen eindeutigen Namen (z.B. den Netzwerkadapter oder Hub der Dock), trag ihn als Muster in `dockMatch` ein und stell `mode` auf `dock` oder `either`.

```json
{
  "mode": "either",
  "minExternalMonitors": 1,
  "dockMatch": ["*USB GbE*"],
  "pollSeconds": 10
}
```

## Befehle

Nach der Installation gibt es den Befehl `tah`. Er funktioniert in einem **neuen** Terminal (ein schon offenes Fenster einmal schliessen und neu öffnen).

| Befehl | Was er macht |
|---|---|
| `tah status` | Version, läuft das Script?, erkannte Monitore, aktueller Zustand |
| `tah update` | Neueste Version von GitHub installieren |
| `tah log` | Letzte Zeilen des Logs |
| `tah config` | `config.json` im Editor öffnen |
| `tah start` / `tah restart` | Script starten / neu starten |
| `tah stop` | Script beenden (der Wächter startet es nach spätestens 5 Minuten wieder, dauerhaft entfernen geht mit `tah uninstall`) |
| `tah version` | Installierte Version |
| `tah uninstall` | Alles entfernen |
| `tah help` | Befehlsübersicht |

Das Log wird bei Zustandswechseln geschrieben und bei 200 KB automatisch gekürzt. Zum Testen des Ausblendens kannst du außerdem `& "$env:LOCALAPPDATA\TaskbarAutoHide\TaskbarAutoHide.ps1" -Force Hide` bzw. `-Force Show` ausführen.

## Deinstallation

```powershell
tah uninstall
```

Nach einer Rückfrage entfernt das die geplante Aufgabe, den Run-Key-Eintrag, den Startmenü-Eintrag, den PATH-Eintrag und den Installationsordner, beendet den Prozess und stellt die Taskleiste wieder auf "immer sichtbar".

## Fehlersuche

Zuerst immer `tah status` und `tah log`. Die Ausgabe hilft bei jeder Frage.

**Die Taskleiste schaltet nicht mehr um.**
Steht bei `Script laeuft` ein **NEIN**, läuft der Hintergrundprozess nicht. Mit `tah start` startest du ihn. Ab Version 1.0.2 prüft die geplante Aufgabe alle 5 Minuten und startet ihn sonst selbst neu. Mit einer älteren Version einfach den Einzeiler aus dem Schnellstart nochmal ausführen.

**`tah` wird nicht gefunden.**
Ein neues Terminal öffnen, der PATH-Eintrag gilt nur für Fenster, die nach der Installation gestartet wurden. Sonst geht es immer mit `& "$env:LOCALAPPDATA\TaskbarAutoHide\tah.cmd" status`.

**Der Einzeiler wird blockiert oder bringt eine Fehlermeldung.**
Meist Firmenrichtlinie oder Proxy. Dann die ZIP-Variante aus [INSTALL.de.md](INSTALL.de.md) nehmen.

**Die Taskleiste fährt von selbst aus.**
Meistens blinkt eine App (z.B. Teams bei einer neuen Nachricht), das zeigt Windows so an. In den Windows-Einstellungen unter Personalisierung → Taskleiste → Verhalten der Taskleiste lässt sich das Blinken von Taskleisten-Apps abstellen.

**Es werden 0 externe Monitore erkannt, obwohl einer dran ist.**
Prüfen, ob `Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorConnectionParams` Werte liefert. Wenn nicht, greift der Fallback (Bildschirmanzahl minus 1).

**Die Taskleiste verschwindet auch ohne externen Monitor.**
Im Modus `monitors` prüfen, ob Windows einen "virtuellen" Bildschirm meldet (z.B. Remote-Sitzung, virtuelle Display-Treiber). `tah status` zeigt die Anzahl.

**Die Dockingstation wird nicht erkannt.**
`Find-Dock.ps1` nochmal durchlaufen und ein spezifischeres Muster wählen. Wildcards (`*`) davor und danach nicht vergessen.

**Kurzes Fenster-Aufblitzen beim Anmelden.**
Normal beim Start des versteckten PowerShell-Prozesses. Es verschwindet sofort.

## Was verändert das Script auf dem System?

Transparent und überschaubar, alles im Benutzerkontext:

- schaltet die Taskleisten-Einstellung "automatisch ausblenden" um (über die Windows-API, wie die Einstellungen selbst)
- legt Dateien in `%LOCALAPPDATA%\TaskbarAutoHide` ab (Script, `config.json`, Log)
- legt eine geplante Aufgabe `TaskbarAutoHide`, einen Run-Key-Eintrag `TaskbarAutoHide` unter `HKCU` und einen Startmenü-Eintrag zum Aktualisieren an und ergänzt den Installationsordner im Benutzer-PATH (für den Befehl `tah`)
- liest Monitor- und Geräteinformationen über WMI bzw. `Get-PnpDevice`
- **keine** Netzwerkverbindungen im Betrieb (nur `Update.ps1` verbindet sich auf deinen Befehl mit github.com), **keine** Admin-Rechte, **keine** Änderungen an Systemeinstellungen oder Richtlinien

`Uninstall.ps1` entfernt alles wieder. Der Quellcode ist kurz genug, um ihn vor der Installation selbst durchzulesen.

## Hinweise und Grenzen

- Auto-Hide gilt für alle Taskleisten. Pro Bildschirm getrennt geht es in Windows nicht.
- Läuft nur, solange du angemeldet bist (Benutzerkontext).
- Auf Firmen-PCs vorher prüfen, ob Scripts und geplante Aufgaben erlaubt sind und ob die Taskleisten-Einstellung per Richtlinie gesperrt ist.
- Getestet: Modus `monitors` unter Windows 11 mit zwei externen Monitoren (Ausblenden bestätigt). Der Dock-Modus (`dock`, `either`) ist bisher nicht auf echter Hardware geprüft.

## Dateien

| Datei | Zweck |
|---|---|
| `TaskbarAutoHide.ps1` | Hauptscript (Dauerbetrieb, `-Status`, `-Force`, `-Once`) |
| `Install.ps1` | Installation inkl. Autostart |
| `Uninstall.ps1` | Entfernt alles wieder |
| `Find-Dock.ps1` | Findet ein Erkennungsmuster für die Dockingstation |
| `Update.ps1` | Lädt die neueste Version von GitHub und installiert sie |
| `Manage.ps1`, `tah.cmd` | Der Befehl `tah` (status, update, log, ...) |
| `config.json` | Standardkonfiguration |
| `README.md` | English documentation |
| `INSTALL.de.md` | Schritt-für-Schritt-Anleitung für Einsteiger |
| `CHANGELOG.md` | Änderungen pro Version |
| `LICENSE` | MIT-Lizenz |

## Lizenz

MIT, siehe [LICENSE](LICENSE).
