# ts6-installer – Projektkontext für Claude Code

Bash-Skript (`ts6ctl`) zur Installation, Aktualisierung und Überwachung des **TeamSpeak 6 Server Beta** (native Binary) unter Linux.

## Tech-Stack
- Reines Bash-Skript, kein Framework
- systemd für Service-Management/Autostart
- Cron-Job für täglichen Update-Check

## Features
- Interaktive Installation mit Abfragen (Ports, Pfade, Benutzer, E-Mail)
- Automatische Erstellung des systemd-Service inkl. Autostart
- Update-Befehl zum manuellen Upgrade auf neue Versionen
- Täglicher Update-Check via Cron-Job mit optionaler E-Mail-Benachrichtigung
- Status-Anzeige (installierte Version, Service-Status)

## Installation/Nutzung
```bash
curl -Lo /usr/local/bin/ts6ctl \
    https://raw.githubusercontent.com/DasAoD/ts6-installer/main/ts6ctl.sh
chmod +x /usr/local/bin/ts6ctl
ts6ctl install
```

## Zusammenspiel mit TS6-Admin-Panel
Dieses Skript liefert das CLI-Tool `ts6ctl`, das vom Web-Panel [TS6-Admin-Panel](https://git.uliana.de/DasAoD/TS6-Admin-Panel) für Server-Aktionen aufgerufen wird. Bei Änderungen an Befehlen, Parametern oder Ausgabeformat von `ts6ctl` immer gegenchecken, ob das Admin-Panel davon betroffen ist (Parsing der Ausgabe, erwartete Exit-Codes etc.).
