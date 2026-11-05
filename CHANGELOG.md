# Changelog

## [1.0.4] - 2026-11-05

### Hinzugefügt
- Befehl `tah` (`tah status`, `tah update`, `tah log`, `tah config`, `tah start`, `tah restart`, `tah stop`, `tah version`, `tah uninstall`, `tah help`). Die Installation trägt den Ordner im Benutzer-PATH ein, in einem neuen Terminal ist `tah` verfügbar.
- Feste Pfade und eine einzige empfohlene Installationsmethode (der Einzeiler). README und `INSTALL.de.md` überarbeitet, mit Übersicht "Wo liegt was?".

## [1.0.3] - 2026-11-05

### Hinzugefügt
- `Update.ps1`: lädt die neueste Version von GitHub und installiert sie in einem Schritt. Aufruf mit `irm https://raw.githubusercontent.com/A555Ferrari/taskbar-autohide/main/Update.ps1 | iex` oder über den neuen Startmenü-Eintrag "TaskbarAutoHide aktualisieren". Läuft nur auf Befehl, nie automatisch.
- `-Status` zeigt jetzt die installierte Version und ob das Script wirklich läuft (vorher sah man einen toten Prozess nicht).
- Datei `VERSION`.

## [1.0.2] - 2026-11-05

### Behoben
- Das Script lief nach Abmelden, Ruhezustand oder Neustart teils nicht mehr, und weder die Anmeldung noch der Run-Key startete es neu (Taskleiste blieb im alten Zustand). Die geplante Aufgabe hat jetzt zwei Auslöser: bei der Anmeldung und alle 5 Minuten als Wächter. Läuft das Script nicht mehr, wird es spätestens nach 5 Minuten neu gestartet. Der Run-Key startet jetzt die Aufgabe statt das Script direkt, damit nie zwei Instanzen entstehen.

## [1.0.1] - 2026-11-04

### Behoben
- Das Script startete nach Abmelden/Neustart nicht mehr zuverlässig, weil die geplante Aufgabe beim Login nicht anlief. `Install.ps1` trägt jetzt zusätzlich einen Autostart im Run-Key ein (doppelter Start ist durch den Mutex harmlos), `Uninstall.ps1` entfernt ihn wieder.

Alle wichtigen Änderungen an diesem Projekt. Format angelehnt an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

## [1.0.0] - 2026-11-03

### Hinzugefügt
- Automatisches Ein-/Ausblenden der Taskleiste je nach externen Monitoren (`mode: monitors`).
- Optionale Dock-Erkennung über Gerätemuster (`mode: dock` und `either`) inkl. `Find-Dock.ps1`.
- `Install.ps1` mit geplanter Aufgabe (Start bei Anmeldung) und Autostart-Ordner als Fallback.
- `Uninstall.ps1`, das die Taskleiste wieder auf "immer sichtbar" stellt.
- `-Status`, `-Force Hide|Show` und `-Once` zum Testen.
- Konfiguration über `config.json`, wird im Betrieb neu gelesen.

### Behoben
- Absturz beim Start unter Windows PowerShell 5.1: `$PSScriptRoot` war im `param()`-Block leer.
- `Install.ps1` entsperrt die Dateien jetzt selbst (`Unblock-File`).
