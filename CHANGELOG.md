# Changelog

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
