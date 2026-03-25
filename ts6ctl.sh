#!/usr/bin/env bash
# =============================================================
#  ts6ctl — TeamSpeak 6 Server Control
#  Befehle: install | update | check-update | status | help
# =============================================================

set -euo pipefail

# ── Konstanten ────────────────────────────────────────────────
SCRIPT_VERSION="1.0.0"
GITHUB_API="https://api.github.com/repos/teamspeak/teamspeak6-server/releases/latest"
CONF_FILE="/etc/ts6ctl.conf"
CRON_FILE="/etc/cron.d/ts6ctl"
LOG_FILE="/var/log/ts6ctl.log"
SCRIPT_PATH="$(realpath "$0")"

# ── Farben ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Logging ───────────────────────────────────────────────────
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
section() { echo -e "\n${BLUE}${BOLD}=== $* ===${NC}"; }
die()     { error "$*"; exit 1; }

# ── Konfiguration laden / speichern ───────────────────────────
load_config() {
    if [[ -f "$CONF_FILE" ]]; then
        source "$CONF_FILE"
    fi
}

save_config() {
    cat > "$CONF_FILE" <<EOF
# ts6ctl Konfiguration — generiert am $(date '+%Y-%m-%d %H:%M')
TS6_INSTALL_DIR="${TS6_INSTALL_DIR:-}"
TS6_USER="${TS6_USER:-}"
TS6_SERVICE="${TS6_SERVICE:-}"
TS6_VOICE_PORT="${TS6_VOICE_PORT:-}"
TS6_FILETRANSFER_PORT="${TS6_FILETRANSFER_PORT:-}"
TS6_QUERY_HTTP_PORT="${TS6_QUERY_HTTP_PORT:-}"
TS6_MAIL_TO="${TS6_MAIL_TO:-}"
TS6_MAIL_FROM="${TS6_MAIL_FROM:-}"
TS6_INSTALLED_VERSION="${TS6_INSTALLED_VERSION:-}"
EOF
    chmod 600 "$CONF_FILE"
    info "Konfiguration gespeichert: $CONF_FILE"
}

# ── Abhängigkeiten prüfen ─────────────────────────────────────
check_deps() {
    local missing=()
    for cmd in curl jq tar bzip2; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Fehlende Pakete: ${missing[*]}"
        read -rp "Per apt-get installieren? [j/N]: " yn
        [[ "$yn" =~ ^[jJyY]$ ]] || die "Abhängigkeiten fehlen — Abbruch."
        apt-get update -qq && apt-get install -y -qq "${missing[@]}"
        info "Pakete installiert."
    fi
}

# ── GitHub API ────────────────────────────────────────────────
get_latest_release_json() {
    curl -sSf "$GITHUB_API" || die "GitHub API nicht erreichbar. Netzwerk prüfen."
}

get_latest_version() {
    get_latest_release_json | jq -r '.tag_name'
}

get_download_url() {
    local json="$1"
    echo "$json" | jq -r \
        '.assets | map(select(
            (.name | contains("linux_amd64")) and
            (.name | endswith(".tar.bz2"))
        ))[0].browser_download_url'
}

# ── Admin-Token aus Journal lesen ─────────────────────────────
show_admin_token() {
    local service="$1"
    info "Suche Admin-Token im Service-Journal..."
    sleep 3  # kurz warten, bis der Server gestartet ist
    local token_line
    token_line=$(journalctl -u "$service" --no-pager -n 100 2>/dev/null \
        | grep -iE "token|privilege key" | tail -5 || true)
    if [[ -n "$token_line" ]]; then
        echo ""
        echo -e "${YELLOW}${BOLD}┌─────────────────────────────────────────────────┐${NC}"
        echo -e "${YELLOW}${BOLD}│  ADMIN-TOKEN — JETZT SICHERN!                   │${NC}"
        echo -e "${YELLOW}${BOLD}└─────────────────────────────────────────────────┘${NC}"
        echo "$token_line"
        echo ""
    else
        warn "Token nicht gefunden. Manuell prüfen:"
        echo "  journalctl -u ${service} | grep -i token"
    fi
}

# ── INSTALL ───────────────────────────────────────────────────
cmd_install() {
    [[ $EUID -eq 0 ]] || die "install muss als root ausgeführt werden."
    check_deps

    section "TeamSpeak 6 Server — Interaktive Installation (ts6ctl v${SCRIPT_VERSION})"
    echo ""

    # Defaults (ggf. aus bestehender Config)
    load_config
    TS6_INSTALL_DIR="${TS6_INSTALL_DIR:-/opt/teamspeak6}"
    TS6_USER="${TS6_USER:-teamspeak6}"
    TS6_SERVICE="${TS6_SERVICE:-teamspeak6}"
    TS6_VOICE_PORT="${TS6_VOICE_PORT:-9987}"
    TS6_FILETRANSFER_PORT="${TS6_FILETRANSFER_PORT:-30033}"
    TS6_QUERY_HTTP_PORT="${TS6_QUERY_HTTP_PORT:-10080}"
    TS6_MAIL_TO="${TS6_MAIL_TO:-}"

    # ── Interaktive Abfragen ──
    read -rp "  Installationsverzeichnis       [${TS6_INSTALL_DIR}]: " i
    TS6_INSTALL_DIR="${i:-$TS6_INSTALL_DIR}"

    read -rp "  Service-Benutzer (System-User) [${TS6_USER}]: " i
    TS6_USER="${i:-$TS6_USER}"

    read -rp "  Systemd-Service-Name           [${TS6_SERVICE}]: " i
    TS6_SERVICE="${i:-$TS6_SERVICE}"

    read -rp "  Voice-Port (UDP)               [${TS6_VOICE_PORT}]: " i
    TS6_VOICE_PORT="${i:-$TS6_VOICE_PORT}"

    read -rp "  File-Transfer-Port (TCP)       [${TS6_FILETRANSFER_PORT}]: " i
    TS6_FILETRANSFER_PORT="${i:-$TS6_FILETRANSFER_PORT}"

    read -rp "  HTTP-Query-Port (0=deaktiviert)[${TS6_QUERY_HTTP_PORT}]: " i
    TS6_QUERY_HTTP_PORT="${i:-$TS6_QUERY_HTTP_PORT}"

    read -rp "  E-Mail für Update-Benachrichtigung (leer=deaktiviert): " i
    TS6_MAIL_TO="${i:-$TS6_MAIL_TO}"

    read -rp "  Absender-E-Mail                [${TS6_MAIL_FROM:-ts6ctl@$(hostname -f)}]: " i
    TS6_MAIL_FROM="${i:-${TS6_MAIL_FROM:-ts6ctl@$(hostname -f)}}"

    # ── Zusammenfassung ──
    section "Zusammenfassung"
    echo -e "  ${CYAN}Installationsverzeichnis${NC} : $TS6_INSTALL_DIR"
    echo -e "  ${CYAN}Service-Benutzer${NC}         : $TS6_USER"
    echo -e "  ${CYAN}Systemd-Service${NC}          : $TS6_SERVICE"
    echo -e "  ${CYAN}Voice-Port (UDP)${NC}         : $TS6_VOICE_PORT"
    echo -e "  ${CYAN}File-Transfer-Port (TCP)${NC} : $TS6_FILETRANSFER_PORT"
    echo -e "  ${CYAN}HTTP-Query-Port (TCP)${NC}    : ${TS6_QUERY_HTTP_PORT} $([ "$TS6_QUERY_HTTP_PORT" = "0" ] && echo "(deaktiviert)" || true)"
    echo -e "  ${CYAN}Update-Mail an${NC}           : ${TS6_MAIL_TO:-deaktiviert}"
    echo ""
    read -rp "Installation jetzt starten? [j/N]: " yn
    [[ "$yn" =~ ^[jJyY]$ ]] || die "Installation abgebrochen."

    # ── Neueste Version ermitteln ──
    section "Neueste Version ermitteln"
    local json download_url latest_version
    json=$(get_latest_release_json)
    latest_version=$(echo "$json" | jq -r '.tag_name')
    download_url=$(get_download_url "$json")
    [[ "$download_url" == "null" || -z "$download_url" ]] && die "Kein linux_amd64-Asset gefunden."
    info "Neueste Version : $latest_version"
    info "Download-URL    : $download_url"

    # ── System-User ──
    section "System-User anlegen"
    if id "$TS6_USER" &>/dev/null; then
        info "User '$TS6_USER' existiert bereits."
    else
        useradd --system --no-create-home --shell /usr/sbin/nologin "$TS6_USER"
        info "User '$TS6_USER' angelegt."
    fi

    # ── Verzeichnis ──
    section "Verzeichnis vorbereiten"
    mkdir -p "$TS6_INSTALL_DIR"
    info "Verzeichnis: $TS6_INSTALL_DIR"

    # ── Download & Entpacken ──
    section "Download & Entpacken"
    local tmpfile
    tmpfile=$(mktemp /tmp/ts6-XXXXXX.tar.bz2)
    curl -L --progress-bar -o "$tmpfile" "$download_url"
    tar xjf "$tmpfile" --strip-components=1 -C "$TS6_INSTALL_DIR"
    rm -f "$tmpfile"
    info "Fertig entpackt nach: $TS6_INSTALL_DIR"

    # ── tsserver.yaml ──
    section "Server-Konfiguration schreiben"
    local yaml_file="$TS6_INSTALL_DIR/tsserver.yaml"
    # Nur anlegen wenn noch nicht vorhanden (Neuinstallation)
    if [[ ! -f "$yaml_file" ]]; then
        {
            echo "# TeamSpeak 6 Server Konfiguration"
            echo "# Generiert von ts6ctl v${SCRIPT_VERSION} am $(date '+%Y-%m-%d')"
            echo ""
            echo "license_accepted: true"
            echo ""
            echo "voice:"
            echo "  port: ${TS6_VOICE_PORT}"
            echo ""
            echo "file_transfer:"
            echo "  port: ${TS6_FILETRANSFER_PORT}"
            if [[ "$TS6_QUERY_HTTP_PORT" != "0" ]]; then
                echo ""
                echo "query:"
                echo "  http:"
                echo "    enabled: true"
                echo "    port: ${TS6_QUERY_HTTP_PORT}"
            fi
        } > "$yaml_file"
        info "tsserver.yaml angelegt."
    else
        warn "tsserver.yaml existiert bereits — wird nicht überschrieben."
    fi

    # ── Berechtigungen ──
    chown -R "$TS6_USER":"$TS6_USER" "$TS6_INSTALL_DIR"
    chmod 750 "$TS6_INSTALL_DIR"
    chmod +x "$TS6_INSTALL_DIR/tsserver"

    # ── systemd Service ──
    section "Systemd-Service einrichten"
    cat > "/etc/systemd/system/${TS6_SERVICE}.service" <<SERVICE
[Unit]
Description=TeamSpeak 6 Server
After=network.target

[Service]
Type=simple
User=${TS6_USER}
WorkingDirectory=${TS6_INSTALL_DIR}
ExecStart=${TS6_INSTALL_DIR}/tsserver
Environment=TSSERVER_LICENSE_ACCEPTED=accept
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${TS6_SERVICE}

[Install]
WantedBy=multi-user.target
SERVICE

    systemctl daemon-reload
    systemctl enable "$TS6_SERVICE"
    systemctl start "$TS6_SERVICE"
    info "Service '$TS6_SERVICE' gestartet und für Autostart aktiviert."

    # ── Cron-Job ──
    section "Update-Check (Cron) einrichten"
    echo "0 8 * * * root ${SCRIPT_PATH} check-update >> ${LOG_FILE} 2>&1" > "$CRON_FILE"
    chmod 644 "$CRON_FILE"
    info "Cron-Job: täglich 08:00 Uhr → $CRON_FILE"

    # ── Konfiguration speichern ──
    TS6_INSTALLED_VERSION="$latest_version"
    save_config

    # ── Admin-Token anzeigen ──
    show_admin_token "$TS6_SERVICE"

    section "Installation abgeschlossen!"
    echo -e "  Server läuft auf Port ${CYAN}${TS6_VOICE_PORT}/UDP${NC}"
    echo ""
    echo -e "  ${BOLD}Nützliche Befehle:${NC}"
    echo "    systemctl status $TS6_SERVICE"
    echo "    journalctl -fu $TS6_SERVICE"
    echo "    $(basename "$0") status"
    echo "    $(basename "$0") update"
    echo ""
}

# ── UPDATE ────────────────────────────────────────────────────
cmd_update() {
    [[ $EUID -eq 0 ]] || die "update muss als root ausgeführt werden."
    load_config
    [[ -n "${TS6_INSTALL_DIR:-}" ]] || die "Keine Konfiguration gefunden. Erst 'install' ausführen."
    check_deps

    section "TeamSpeak 6 Server — Update"

    local json download_url latest_version
    info "Prüfe GitHub auf neueste Version..."
    json=$(get_latest_release_json)
    latest_version=$(echo "$json" | jq -r '.tag_name')
    download_url=$(get_download_url "$json")

    info "Installiert : ${TS6_INSTALLED_VERSION:-unbekannt}"
    info "Verfügbar   : $latest_version"

    if [[ "$latest_version" == "${TS6_INSTALLED_VERSION:-}" ]]; then
        info "Bereits auf dem neuesten Stand. Kein Update nötig."
        exit 0
    fi

    [[ "$download_url" == "null" || -z "$download_url" ]] && die "Kein linux_amd64-Asset gefunden."

    echo ""
    read -rp "Update auf $latest_version durchführen? [j/N]: " yn
    [[ "$yn" =~ ^[jJyY]$ ]] || { info "Update abgebrochen."; exit 0; }

    # Backup des bisherigen Binaries
    if cp "$TS6_INSTALL_DIR/tsserver" "$TS6_INSTALL_DIR/tsserver.bak" 2>/dev/null; then
        info "Backup: ${TS6_INSTALL_DIR}/tsserver.bak"
    fi

    # Service stoppen
    info "Stoppe Service '$TS6_SERVICE'..."
    systemctl stop "$TS6_SERVICE"

    # Download & Binary tauschen
    local tmpfile tmpdir
    tmpfile=$(mktemp /tmp/ts6-XXXXXX.tar.bz2)
    tmpdir=$(mktemp -d /tmp/ts6-extract-XXXXXX)

    info "Lade $latest_version herunter..."
    curl -L --progress-bar -o "$tmpfile" "$download_url"
    tar xjf "$tmpfile" --strip-components=1 -C "$tmpdir"

    # Nur Binary ersetzen, Config bleibt erhalten
    cp "$tmpdir/tsserver" "$TS6_INSTALL_DIR/tsserver"
    chmod +x "$TS6_INSTALL_DIR/tsserver"
    chown "$TS6_USER":"$TS6_USER" "$TS6_INSTALL_DIR/tsserver"

    rm -f "$tmpfile"
    rm -rf "$tmpdir"

    # Service starten
    info "Starte Service '$TS6_SERVICE'..."
    systemctl start "$TS6_SERVICE"

    # Konfiguration aktualisieren
    TS6_INSTALLED_VERSION="$latest_version"
    save_config

    info "Update auf $latest_version erfolgreich abgeschlossen!"
    echo ""
    echo "    journalctl -fu $TS6_SERVICE"
}

# ── CHECK-UPDATE (für Cron) ────────────────────────────────────
cmd_check_update() {
    load_config
    check_deps

    local latest_version installed_version timestamp
    timestamp="[$(date '+%Y-%m-%d %H:%M')]"
    installed_version="${TS6_INSTALLED_VERSION:-unbekannt}"

    latest_version=$(get_latest_version) || {
        echo "${timestamp} [ERROR] GitHub API nicht erreichbar."
        exit 1
    }

    if [[ "$latest_version" == "$installed_version" ]]; then
        echo "${timestamp} [INFO] Kein Update — aktuell: $installed_version"
        exit 0
    fi

    echo "${timestamp} [UPDATE] Neue Version verfügbar: $latest_version (installiert: $installed_version)"

    # E-Mail senden
    if [[ -n "${TS6_MAIL_TO:-}" ]]; then
        local subject="[ts6ctl] Update verfügbar: $latest_version"
        local body
        body=$(cat <<MAIL
TeamSpeak 6 Server — Update verfügbar

  Installierte Version : ${installed_version}
  Neue Version         : ${latest_version}

  Server               : $(hostname -f)
  Installationsverz.   : ${TS6_INSTALL_DIR:-unbekannt}
  Service              : ${TS6_SERVICE:-teamspeak6}

Update durchführen:
  ts6ctl update

Release-Notes:
  https://github.com/teamspeak/teamspeak6-server/releases/tag/${latest_version}

---
ts6ctl v${SCRIPT_VERSION}
MAIL
)
        local from_header="ts6ctl <${TS6_MAIL_FROM:-ts6ctl@$(hostname -f)}>"
        if echo "$body" | mail -s "$subject" -a "From: ${from_header}" "$TS6_MAIL_TO"; then
            echo "${timestamp} [INFO] Benachrichtigung gesendet an: $TS6_MAIL_TO"
        else
            echo "${timestamp} [WARN] E-Mail konnte nicht gesendet werden."
        fi
    fi
}

# ── STATUS ────────────────────────────────────────────────────
cmd_status() {
    load_config

    section "TeamSpeak 6 Server — Status"
    echo ""
    echo -e "  ${CYAN}ts6ctl Version${NC}      : $SCRIPT_VERSION"
    echo -e "  ${CYAN}Konfigurationsdatei${NC}      : $CONF_FILE"
    echo -e "  ${CYAN}Installationsverzeichnis${NC} : ${TS6_INSTALL_DIR:-nicht installiert}"
    echo -e "  ${CYAN}Installierte TS6-Version${NC} : ${TS6_INSTALLED_VERSION:-unbekannt}"
    echo -e "  ${CYAN}Systemd-Service${NC}          : ${TS6_SERVICE:-teamspeak6}"
    echo -e "  ${CYAN}Voice-Port (UDP)${NC}         : ${TS6_VOICE_PORT:-?}"
    echo -e "  ${CYAN}File-Transfer-Port (TCP)${NC} : ${TS6_FILETRANSFER_PORT:-?}"
    echo -e "  ${CYAN}HTTP-Query-Port (TCP)${NC}    : ${TS6_QUERY_HTTP_PORT:-?}"
    echo -e "  ${CYAN}Update-Benachrichtigung${NC}  : ${TS6_MAIL_TO:-deaktiviert}"
    echo -e "  ${CYAN}Absender-E-Mail${NC}          : ${TS6_MAIL_FROM:-Standard (Postfix)}"
    echo ""

    if command -v systemctl &>/dev/null && [[ -n "${TS6_SERVICE:-}" ]]; then
        systemctl status "${TS6_SERVICE}" --no-pager -l 2>/dev/null || \
            warn "Service '${TS6_SERVICE}' nicht gefunden oder nicht aktiv." || true
    fi
}

# ── HELP ──────────────────────────────────────────────────────
cmd_help() {
    cat <<HELP

${BOLD}ts6ctl v${SCRIPT_VERSION}${NC} — TeamSpeak 6 Server Control

${BOLD}Verwendung:${NC}
  $(basename "$0") <befehl>

${BOLD}Befehle:${NC}
  ${GREEN}install${NC}       Interaktive Erstinstallation des TS6-Servers
  ${GREEN}update${NC}        Server auf neueste Version aktualisieren
  ${GREEN}check-update${NC}  Version prüfen, ggf. E-Mail senden (für Cron)
  ${GREEN}status${NC}        Installations- und Service-Status anzeigen
  ${GREEN}help${NC}          Diese Hilfe

${BOLD}Dateien:${NC}
  Konfiguration : $CONF_FILE
  Cron-Job      : $CRON_FILE
  Log-Datei     : $LOG_FILE

${BOLD}Beispiele:${NC}
  $(basename "$0") install
  $(basename "$0") status
  $(basename "$0") update
  $(basename "$0") check-update    # manuell testen
  journalctl -fu teamspeak6        # Live-Log

HELP
}

# ── Einstiegspunkt ────────────────────────────────────────────
case "${1:-help}" in
    install)        cmd_install ;;
    update)         cmd_update ;;
    check-update)   cmd_check_update ;;
    status)         cmd_status ;;
    help|--help|-h) cmd_help ;;
    *) error "Unbekannter Befehl: ${1}"; cmd_help; exit 1 ;;
esac
