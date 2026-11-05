# Installationsanleitung (Schritt für Schritt)

Für alle, die TaskbarAutoHide zum ersten Mal installieren. Dauert etwa 2 Minuten, Admin-Rechte brauchst du nicht.

Das Tool blendet die Taskleiste automatisch aus, sobald ein externer Monitor oder die Dockingstation dran ist. Nur am Laptop-Display bleibt sie immer sichtbar.

## Installieren

1. **ZIP herunterladen:** [taskbar-autohide-main.zip](https://github.com/A555Ferrari/taskbar-autohide/archive/refs/heads/main.zip). Dafür brauchst du kein GitHub-Konto.
2. **Entpacken:** Im Downloads-Ordner Rechtsklick auf die ZIP-Datei → **Alle extrahieren** → **Extrahieren**.
3. **In den inneren Ordner gehen:** Windows legt oft einen Ordner im Ordner an. Öffne die Ordner, bis du die Datei `Install.ps1` siehst.
4. **PowerShell dort öffnen:** Rechtsklick auf eine leere Stelle im Ordner → **In Terminal öffnen** (bei Windows 10: Shift gedrückt halten + Rechtsklick → "PowerShell-Fenster hier öffnen").
5. **Diesen Befehl eingeben** und mit Enter bestätigen:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Install.ps1
   ```

6. **Prüfen:** Am Ende steht "Geplante Aufgabe 'TaskbarAutoHide' angelegt und gestartet" und danach eine Statusliste. Mit externem Monitor sollte dort `Auto-Hide aktuell: True` stehen, nur am Laptop `False`.

Ein Neustart ist nicht nötig, es läuft sofort und startet ab jetzt bei jeder Anmeldung von selbst.

## Testen

Steck den externen Monitor oder die Dockingstation ab und wieder an. Nach höchstens 5 Sekunden schaltet die Taskleiste um:

- mit externem Monitor: ausgeblendet (fährt aus, wenn du die Maus an den unteren Rand bewegst)
- nur am Laptop: immer sichtbar

## Aktualisieren

Neue ZIP herunterladen und die Schritte 2 bis 5 wiederholen. Deine Einstellungen bleiben erhalten.

## Wenn etwas nicht klappt

**"Install.ps1 wird nicht gefunden"**
Du bist im falschen Ordner. Zurück zu Schritt 3: Das Terminal muss in dem Ordner geöffnet werden, in dem `Install.ps1` direkt liegt.

**Die Taskleiste schaltet nicht mehr um (zum Beispiel nach Neustart oder Ruhezustand)**
Das Script läuft dann nicht mehr. Starte es von Hand:

```powershell
Start-ScheduledTask -TaskName TaskbarAutoHide
```

Ab Version 1.0.2 prüft Windows alle 5 Minuten, ob es noch läuft, und startet es selbst neu. Hilft das alles nichts, führ `Install.ps1` einfach nochmal aus (Schritt 5).

**Die Taskleiste fährt von selbst aus, obwohl ich nichts gemacht habe**
Meistens blinkt eine App (zum Beispiel Teams bei einer neuen Nachricht). Das zeigt Windows so an, das Script ist daran nicht schuld. Du kannst es in den Windows-Einstellungen unter Personalisierung → Taskleiste → Verhalten der Taskleiste abstellen (Option zum Blinken von Taskleisten-Apps).

**Ich will sehen, was das Script gerade denkt**

```powershell
& "$env:LOCALAPPDATA\TaskbarAutoHide\TaskbarAutoHide.ps1" -Status
Get-Content "$env:LOCALAPPDATA\TaskbarAutoHide\TaskbarAutoHide.log" -Tail 10
```

Schick diese Ausgabe mit, wenn du Hilfe brauchst.

**Dockingstation ohne Monitor soll auch zählen**
Das geht über `dockMatch` in der `config.json`, siehe [README.de.md](README.de.md#dockingstation-einrichten).

## Deinstallieren

Im Repo-Ordner (wie bei der Installation) ausführen:

```powershell
powershell -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

Das entfernt alles und stellt die Taskleiste wieder auf "immer sichtbar".
