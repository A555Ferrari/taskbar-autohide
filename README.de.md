# TaskbarAutoHide

![Windows 10/11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows&logoColor=white)
![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)
![Version 1.0.3](https://img.shields.io/badge/Version-1.0.3-blue)
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
- [Testen und Status](#testen-und-status)
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

Neu dabei? Die ausführliche Schritt-für-Schritt-Anleitung für Einsteiger steht in [INSTALL.de.md](INSTALL.de.md).

**Am schnellsten: installieren und aktualisieren mit einem Befehl.** PowerShell öffnen, einfügen, Enter:

```powershell
irm https://raw.githubusercontent.com/A555Ferrari/taskbar-autohide/main/Update.ps1 | iex
```

Das lädt die neueste Version von GitHub, installiert sie und räumt wieder auf. Deine `config.json` bleibt erhalten. Später aktualisierst du genauso oder über den Startmenü-Eintrag **TaskbarAutoHide aktualisieren**. Es läuft nur, wenn du es selbst startest, nie automatisch. Du kannst [Update.ps1](Update.ps1) vorher lesen. Blockiert eine Firmenrichtlinie den Befehl, nimm die ZIP-Variante:

1. Repo als ZIP herunterladen und **in einen eigenen Ordner entpacken**. Achtung: Beim Entpacken entsteht oft ein Ordner im Ordner. Du musst in den inneren wechseln, in dem `Install.ps1` direkt liegt.
2. PowerShell öffnen und dorthin wechseln:

   ```powershell
   cd "C:\Users\DEIN_NAME\Downloads\taskbar-autohide\taskbar-autohide"
   ```

3. Installieren:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Install.ps1
   ```

Fertig. Die Installation startet das Script sofort und danach bei jeder Anmeldung automatisch. Ein Neustart ist nicht nötig. Am Ende der Installation wird der aktuelle Status angezeigt, bei angeschlossenen externen Monitoren sollte dort `Auto-Hide aktuell: True` stehen.

Was `Install.ps1` genau macht:

- Dateien nach `%LOCALAPPDATA%\TaskbarAutoHide` kopieren (eine vorhandene `config.json` bleibt erhalten)
- Dateien entsperren (`Unblock-File`), weil Windows heruntergeladene Scripts sonst blockieren kann
- geplante Aufgabe `TaskbarAutoHide` mit zwei Auslösern anlegen (bei der Anmeldung und alle 5 Minuten als Wächter, der das Script neu startet, falls es nicht mehr läuft) und starten
- zusätzlich einen Autostart-Eintrag im Run-Key des Benutzers setzen, der die Aufgabe startet (doppelter Start ist harmlos, es läuft immer nur eine Instanz)
- einen Startmenü-Eintrag **TaskbarAutoHide aktualisieren** anlegen
- falls geplante Aufgaben nicht erlaubt sind: Verknüpfung im Autostart-Ordner als Fallback

Den Modus kannst du direkt bei der Installation setzen:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install.ps1 -Mode either
```

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

## Testen und Status

```powershell
$s = "$env:LOCALAPPDATA\TaskbarAutoHide\TaskbarAutoHide.ps1"

& $s -Status        # Modus, erkannte Monitore, Dock, aktueller Zustand
& $s -Force Hide    # Auto-Hide einmalig erzwingen
& $s -Force Show    # Taskleiste einmalig wieder dauerhaft anzeigen
& $s -Once          # einmal prüfen und setzen, dann beenden
```

Prozess manuell (neu) starten:

```powershell
Start-ScheduledTask -TaskName TaskbarAutoHide
```

Log: `%LOCALAPPDATA%\TaskbarAutoHide\TaskbarAutoHide.log` (wird bei Zustandswechseln geschrieben und bei 200 KB automatisch gekürzt).

## Deinstallation

```powershell
powershell -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

Das entfernt die geplante Aufgabe bzw. die Autostart-Verknüpfung, beendet den Prozess und stellt die Taskleiste wieder auf "immer sichtbar". Optionen:

- `-KeepAutoHide`: Taskleiste nicht zurück auf "immer sichtbar" stellen
- `-RemoveFiles`: auch `%LOCALAPPDATA%\TaskbarAutoHide` löschen (aus dem Repo-Ordner starten)

## Fehlersuche

**`Install.ps1` wird nicht gefunden.**
Du bist im falschen Ordner. Nach dem Entpacken liegt die Datei oft eine Ebene tiefer. Mit `Get-ChildItem -Path $env:USERPROFILE -Recurse -Filter Install.ps1 -ErrorAction SilentlyContinue | Select-Object FullName` findest du sie.

**Nach Abmelden oder Neustart funktioniert es nicht mehr.**
Seit Version 1.0.2 prüft die geplante Aufgabe alle 5 Minuten, ob das Script läuft, und startet es sonst neu (zusätzlich zum Start bei der Anmeldung und dem Run-Key). Nach Abmelden, Ruhezustand oder Neustart kann es also bis zu 5 Minuten dauern, bis es wieder läuft. Mit einer älteren Version `Install.ps1` einfach erneut ausführen. Prüfen kannst du es mit `Get-ScheduledTask -TaskName TaskbarAutoHide | Get-ScheduledTaskInfo` (`LastRunTime` sollte der letzte Login sein) und `Start-ScheduledTask -TaskName TaskbarAutoHide` startet es von Hand.

**Nach der Installation bleibt die Taskleiste sichtbar.**
`-Status` ausführen. Steht dort `Gilt als angedockt: True`, aber `Auto-Hide aktuell: False`, läuft der Hintergrundprozess nicht. Dann `Start-ScheduledTask -TaskName TaskbarAutoHide` und ins Log schauen.

**Es werden 0 externe Monitore erkannt, obwohl einer dran ist.**
Prüfen, ob `Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorConnectionParams` Werte liefert. Wenn nicht, greift der Fallback (Bildschirmanzahl minus 1).

**Taskleiste verschwindet auch ohne externen Monitor.**
Im Modus `monitors` prüfen, ob Windows einen "virtuellen" Bildschirm meldet (z.B. Remote-Sitzung, virtuelle Display-Treiber). `-Status` zeigt die Anzahl.

**Dock wird nicht erkannt.**
`Find-Dock.ps1` nochmal durchlaufen und ein spezifischeres Muster wählen. Wildcards (`*`) davor und danach nicht vergessen.

**Fehlermeldung wegen ExecutionPolicy.**
Immer mit `-ExecutionPolicy Bypass` aufrufen, wie oben gezeigt. Erzwingt eine Gruppenrichtlinie (AppLocker, Constrained Language Mode) etwas anderes, funktioniert das Script dort nicht.

**Kurzes Fenster-Aufblitzen beim Anmelden.**
Normal beim Start des versteckten PowerShell-Prozesses. Es verschwindet sofort.

## Was verändert das Script auf dem System?

Transparent und überschaubar, alles im Benutzerkontext:

- schaltet die Taskleisten-Einstellung "automatisch ausblenden" um (über die Windows-API, wie die Einstellungen selbst)
- legt Dateien in `%LOCALAPPDATA%\TaskbarAutoHide` ab (Script, `config.json`, Log)
- legt eine geplante Aufgabe `TaskbarAutoHide` einen Run-Key-Eintrag `TaskbarAutoHide` unter `HKCU` und einen Startmenü-Eintrag zum Aktualisieren an
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
| `config.json` | Standardkonfiguration |
| `README.md` | English documentation |
| `INSTALL.de.md` | Schritt-für-Schritt-Anleitung für Einsteiger |
| `CHANGELOG.md` | Änderungen pro Version |
| `LICENSE` | MIT-Lizenz |

## Lizenz

MIT, siehe [LICENSE](LICENSE).
