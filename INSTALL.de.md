# Installationsanleitung

Dauert etwa 2 Minuten, Admin-Rechte brauchst du nicht.

Das Tool blendet die Taskleiste automatisch aus, sobald ein externer Monitor oder die Dockingstation dran ist. Nur am Laptop-Display bleibt sie immer sichtbar.

## Installieren (und Aktualisieren)

1. **PowerShell öffnen:** Start → "PowerShell" tippen → Enter.
2. **Diesen Befehl einfügen** (Rechtsklick fügt ein) und Enter drücken:

   ```powershell
   irm https://raw.githubusercontent.com/A555Ferrari/taskbar-autohide/main/Update.ps1 | iex
   ```

3. **Prüfen:** Am Ende kommt der Status. Es sollte `Version: ...` und `Script laeuft: Ja` dort stehen, mit externem Monitor außerdem `Auto-Hide aktuell: True`.

Fertig. Du musst nichts herunterladen, entpacken oder auswählen. Alles landet an einem festen Ort: `%LOCALAPPDATA%\TaskbarAutoHide` (also `C:\Users\<Name>\AppData\Local\TaskbarAutoHide`). Ein Neustart ist nicht nötig, es startet ab jetzt bei jeder Anmeldung von selbst.

## Testen

Steck den externen Monitor oder die Dockingstation ab und wieder an. Nach höchstens 5 Sekunden schaltet die Taskleiste um:

- mit externem Monitor: ausgeblendet (fährt aus, wenn du die Maus an den unteren Rand bewegst)
- nur am Laptop: immer sichtbar

## Befehle

In einem **neuen** Terminal (ein schon offenes Fenster einmal schließen und neu öffnen):

| Befehl | Was er macht |
|---|---|
| `tah status` | Version, läuft das Script?, Monitore, Zustand |
| `tah update` | Neueste Version installieren |
| `tah log` | Letzte Zeilen des Logs |
| `tah config` | Einstellungen öffnen |
| `tah start` / `tah restart` | Script starten / neu starten |
| `tah stop` | Script beenden (startet nach spätestens 5 Minuten wieder, dauerhaft: `tah uninstall`) |
| `tah uninstall` | Alles entfernen |
| `tah help` | Übersicht |

## Aktualisieren

Eine von drei Möglichkeiten, alle machen dasselbe:

- Startmenü → **TaskbarAutoHide aktualisieren** anklicken
- `tah update`
- den Befehl aus "Installieren" nochmal ausführen

Deine Einstellungen (`config.json`) bleiben erhalten.

## Wenn der Befehl blockiert wird (Alternative mit ZIP)

Manche Firmen sperren `irm ... | iex`. Dann so:

1. [ZIP herunterladen](https://github.com/A555Ferrari/taskbar-autohide/archive/refs/heads/main.zip) (ohne GitHub-Konto).
2. Im Downloads-Ordner Rechtsklick auf die ZIP-Datei → **Alle extrahieren** → **Extrahieren**.
3. In den Ordner gehen, in dem `Install.ps1` direkt liegt (Windows legt oft einen Ordner im Ordner an).
4. Rechtsklick auf eine leere Stelle im Ordner → **In Terminal öffnen** (bei Windows 10: Shift gedrückt halten + Rechtsklick → "PowerShell-Fenster hier öffnen").
5. Eingeben:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Install.ps1
   ```

Installiert wird trotzdem am festen Ort. Den entpackten Ordner kannst du danach löschen.

## Wenn etwas nicht klappt

Führ `tah status` und `tah log` aus und schick die Ausgabe mit. Häufige Fälle (Taskleiste schaltet nicht um, `tah` nicht gefunden, Taskleiste fährt aus, wenn Teams blinkt) stehen in der [Fehlersuche](README.de.md#fehlersuche).

## Deinstallieren

```powershell
tah uninstall
```

Nach einer Rückfrage wird alles entfernt, und die Taskleiste ist wieder immer sichtbar.
