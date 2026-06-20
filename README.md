# ts6-installer

> **📌 Mirror-Hinweis:** Dieses Repository ist ein automatischer Spiegel.
> Die primäre Entwicklung findet auf **[git.uliana.de/DasAoD/ts6-installer](https://git.uliana.de/DasAoD/ts6-installer)** statt.
> Issues und Pull Requests bitte dort öffnen.

Bash-Skript (`ts6ctl`) zur Installation, Aktualisierung und Überwachung des **TeamSpeak 6 Server Beta** (native Binary) unter Linux.

## Features

- **Interaktive Installation** mit Abfragen (Ports, Pfade, Benutzer, E-Mail)
- Automatische Erstellung des **systemd-Service** inkl. Autostart
- **Update-Befehl** zum manuellen Upgrade auf neue Versionen
- **Täglicher Update-Check** via Cron-Job mit optionaler E-Mail-Benachrichtigung
- **Status-Anzeige** (installierte Version, Service-Status)

## Installation & Nutzung

```bash
curl -Lo /usr/local/bin/ts6ctl \
    https://raw.githubusercontent.com/DasAoD/ts6-installer/main/ts6ctl.sh
chmod +x /usr/local/bin/ts6ctl
ts6ctl install
```

## Mitwirkende

Dieses Projekt wurde in Zusammenarbeit mit [Claude](https://claude.ai) (Sonnet 4.6) von [Anthropic](https://anthropic.com) entwickelt und iterativ ausgebaut.  
Der überwiegende Teil des Codes, der Architektur und der Dokumentation wurde durch KI generiert und gemeinsam verfeinert.

| Rolle | Person / Tool |
|---|---|
| Projektidee, Anforderungen & Tests | [DasAoD](https://git.uliana.de/DasAoD) |
| Code, Architektur, Dokumentation | [Claude](https://git.uliana.de/Claude) (Anthropic) |

## License

[MIT](LICENSE)
