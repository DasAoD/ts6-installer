# ts6-installer

Bash-Skript (`ts6ctl`) zur Installation, Aktualisierung und Überwachung des **TeamSpeak 6 Server Beta** (native Binary) unter Linux.

## Features

- **Interaktive Installation** mit Abfragen (Ports, Pfade, Benutzer, E-Mail)
- Automatische Erstellung des **systemd-Service** inkl. Autostart
- **Update-Befehl** zum manuellen Upgrade auf neue Versionen
- **Täglicher Update-Check** via Cron-Job mit optionaler **E-Mail-Benachrichtigung**
- **Status-Anzeige** (installierte Version, Service-Status)

## Voraussetzungen

- Linux (Debian/Ubuntu empfohlen)
- Root-Zugriff
- Pakete: `curl`, `jq`, `tar`, `bzip2` (werden bei Bedarf automatisch installiert)
- Für E-Mail-Benachrichtigungen: `mailutils` / Postfix konfiguriert

## Installation & Nutzung

```bash
# Skript herunterladen
curl -Lo /usr/local/bin/ts6ctl \
    https://raw.githubusercontent.com/DasAoD/ts6-installer/main/ts6ctl.sh
chmod +x /usr/local/bin/ts6ctl

# TS6-Server interaktiv installieren
ts6ctl install

# Status anzeigen
ts6ctl status

# Manuelles Update
ts6ctl update

# Update-Check manuell testen (läuft sonst täglich per Cron)
ts6ctl check-update
```

## Was `install` macht

1. Fragt interaktiv nach: Installationspfad, Ports, Benutzer, E-Mail
2. Legt System-User `teamspeak6` an
3. Lädt neueste Binary von GitHub herunter und entpackt sie
4. Schreibt `tsserver.yaml` (Ports + Lizenzzustimmung)
5. Erstellt und aktiviert systemd-Service
6. Richtet täglichen Cron-Job für Update-Check ein
7. Zeigt den Admin-Token aus dem Service-Journal

## Konfigurationsdatei

Nach der Installation: `/etc/ts6ctl.conf`

```bash
TS6_INSTALL_DIR="/opt/teamspeak6"
TS6_USER="teamspeak6"
TS6_SERVICE="teamspeak6"
TS6_VOICE_PORT="9987"
TS6_FILETRANSFER_PORT="30033"
TS6_QUERY_HTTP_PORT="10080"
TS6_MAIL_TO="admin@example.com"
TS6_MAIL_FROM="ts6ctl@example.com"
TS6_INSTALLED_VERSION="v6.0.0-beta8"
```

## Cron-Job

Täglich um 08:00 Uhr prüft das Skript auf neue Versionen:

```
0 8 * * * root ts6ctl check-update >> /var/log/ts6ctl.log 2>&1
```

Bei einer neuen Version wird — wenn konfiguriert — eine E-Mail gesendet. Das Update muss danach manuell mit `ts6ctl update` eingespielt werden.

## Nützliche Befehle

```bash
systemctl status teamspeak6
journalctl -fu teamspeak6
tail -f /var/log/ts6ctl.log
```

## Wichtige Hinweise (Beta)

- **TS3-Lizenzen** sind nicht kompatibel mit TS6
- Die mitgelieferte **Beta-Lizenz** (32 Slots) wird von TeamSpeak regelmäßig erneuert
- **ServerQuery** ist in der Beta noch nicht vollständig verfügbar
- Für Parallelbetrieb mit TS3: andere Ports wählen (z. B. `9988/UDP`, `30034/TCP`)

## Lizenz

MIT
