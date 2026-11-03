# TaskbarAutoHide

Blendet die Windows-Taskleiste automatisch aus, sobald externe Bildschirme (oder eine Dockingstation) angeschlossen sind. Nur am Laptop-Display bleibt sie dauerhaft sichtbar.

## Warum das Ganze?

Die Windows-Einstellung **"Taskleiste automatisch ausblenden"** (Einstellungen → Personalisierung → Taskleiste → Verhalten der Taskleiste) gilt global. Windows kennt keine Regel wie "nur mit externem Monitor". Dieses Script schaltet die Einstellung automatisch um, je nach Situation:

| Situation | Taskleiste |
|---|---|
| Nur internes Display | immer sichtbar |
| Externer Monitor angeschlossen | automatisch ausgeblendet |
| Dockingstation erkannt (optional) | automatisch ausgeblendet |

## Warum PowerShell und nicht AutoHotkey?

- Läuft auf jedem Windows 10/11 ohne Zusatzsoftware.
- Keine Admin-Rechte nötig, alles läuft im Benutzerkontext.
- Auf Firmen-PCs ist PowerShell meist erlaubt, AutoHotkey oft nicht.

## Wie funktioniert es?

1. Ein Hintergrundprozess prüft alle paar Sekunden (Standard: 5), ob "angedockt" ist.
2. Bei einem Zustandswechsel wird Auto-Hide über die Windows-API `SHAppBarMessage` mit `ABM_SETSTATE` umgeschaltet. Das ist derselbe Mechanismus wie in den Einstellungen, nur ohne Explorer-Neustart.
3. Externe Monitore werden über WMI (`WmiMonitorConnectionParams`) erkannt. Das interne Laptop-Display wird dabei nicht mitgezählt.
4. Dockingstationen erkennt Windows nicht direkt. Optional wird deshalb nach einem Gerät gesucht, das nur mit Dock vorhanden ist (z.B. USB-Hub oder Netzwerkadapter der Dock).
5. Startet der Explorer neu (Absturz, Neustart), setzt das Script den Zustand von selbst wieder.

Die Konfiguration wird bei jedem Durchlauf neu gelesen, Änderungen an `config.json` wirken also ohne Neustart.

## Installation

Repo klonen oder als ZIP laden, dann in PowerShell im Repo-Ordner:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install.ps1
```

Das macht:

- Dateien nach `%LOCALAPPDATA%\TaskbarAutoHide` kopieren (eine vorhandene `config.json` bleibt erhalten)
- geplante Aufgabe `TaskbarAutoHide` anlegen (Start bei jeder Anmeldung)
- Script sofort starten und den Status ausgeben

Ist eine geplante Aufgabe nicht erlaubt, wird automatisch eine Verknüpfung im Autostart-Ordner angelegt.

Modus direkt bei der Installation setzen:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install.ps1 -Mode either
```

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

### Dockingstation einrichten

Das passende Muster findest du mit dem Vorher/Nachher-Vergleich:

```powershell
# 1. Dock abgesteckt:
.\Find-Dock.ps1 -Save

# 2. Dock anschliessen, dann:
.\Find-Dock.ps1 -Compare
```

Die Ausgabe zeigt alle Geräte, die erst mit Dock aufgetaucht sind. Nimm einen eindeutigen Namen (z.B. den Netzwerkadapter oder Hub der Dock), trag ihn als Muster in `dockMatch` ein und stell `mode` auf `dock` oder `either`.

Beispiel:

```json
{
  "mode": "either",
  "minExternalMonitors": 1,
  "dockMatch": ["*USB GbE*"],
  "pollSeconds": 10
}
```

Tipp: In der Praxis hängt an der Dock fast immer ein Monitor. Dann reicht `mode: monitors` völlig aus.

## Testen und Status

```powershell
.\TaskbarAutoHide.ps1 -Status        # Modus, erkannte Monitore, Dock, aktueller Zustand
.\TaskbarAutoHide.ps1 -Force Hide    # Auto-Hide einmalig erzwingen
.\TaskbarAutoHide.ps1 -Force Show    # Taskleiste einmalig wieder dauerhaft anzeigen
.\TaskbarAutoHide.ps1 -Once          # einmal prüfen und setzen, dann beenden
```

Log: `%LOCALAPPDATA%\TaskbarAutoHide\TaskbarAutoHide.log` (wird bei Zustandswechseln geschrieben und bei 200 KB automatisch gekürzt).

## Deinstallation

```powershell
powershell -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

Optionen:

- `-KeepAutoHide`: Taskleiste nicht zurück auf "immer sichtbar" stellen
- `-RemoveFiles`: auch `%LOCALAPPDATA%\TaskbarAutoHide` löschen (aus dem Repo-Ordner starten)

## Fehlersuche

**Nichts passiert nach der Installation.**
`.\TaskbarAutoHide.ps1 -Status` ausführen. Zeigt es 0 externe Monitore, obwohl einer dran ist, greift der Fallback (Bildschirmanzahl minus 1) möglicherweise nicht. Dann ins Log schauen und prüfen, ob `Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorConnectionParams` Werte liefert.

**Taskleiste verschwindet auch ohne externen Monitor.**
Im Modus `monitors` prüfen, ob Windows einen "virtuellen" Bildschirm meldet (z.B. Remote-Sitzung, virtuelle Display-Treiber). `-Status` zeigt die Anzahl.

**Dock wird nicht erkannt.**
`Find-Dock.ps1` nochmal durchlaufen und ein spezifischeres Muster wählen. Namen mit Leerzeichen funktionieren, Wildcards (`*`) davor und danach nicht vergessen.

**Fehlermeldung wegen ExecutionPolicy.**
Immer mit `-ExecutionPolicy Bypass` aufrufen, wie oben gezeigt. Erzwingt eine Gruppenrichtlinie (AppLocker, Constrained Language Mode) etwas anderes, funktioniert das Script dort nicht.

**Kurzes Fenster-Aufblitzen beim Anmelden.**
Normal beim Start des versteckten PowerShell-Prozesses. Es verschwindet sofort.

## Hinweise und Grenzen

- Auto-Hide gilt für alle Taskleisten. Pro Bildschirm getrennt geht es in Windows nicht.
- Läuft nur, solange du angemeldet bist (Benutzerkontext).
- Auf Firmen-PCs vorher prüfen, ob Scripts und geplante Aufgaben erlaubt sind und ob die Taskleisten-Einstellung per Richtlinie gesperrt ist.
- Status: Das Script wurde ohne Zugriff auf einen Windows-Rechner geschrieben und noch nicht auf echter Hardware getestet. Funktioniert etwas nicht, bitte `-Status` und das Log prüfen und das Problem hier im Repo festhalten.

## Dateien

| Datei | Zweck |
|---|---|
| `TaskbarAutoHide.ps1` | Hauptscript (Dauerbetrieb, `-Status`, `-Force`, `-Once`) |
| `Install.ps1` | Installation inkl. Autostart |
| `Uninstall.ps1` | Entfernt alles wieder |
| `Find-Dock.ps1` | Findet ein Erkennungsmuster für die Dockingstation |
| `config.json` | Standardkonfiguration |
