#!/usr/bin/env bash
# ==============================================================================
# Installation Pronote Client 2026 - Script universel Linux v4.7
# Support natif : Debian, Ubuntu, Mint, Fedora, Arch, CachyOS, Manjaro,
#                 Omarchy, EndeavourOS, Garuda, openSUSE, NixOS, GLF OS,
#                 Solus, Alpine Linux, Void Linux
# Support expérimental : Slackware
# Ce script n'est pas écrit ni supporté par Index Education.
# Il n'y a pas de support technique lié à son utilisation.
# Support automatique étendu : toute distribution dérivée (via ID_LIKE)
#
# Préfixes Wine :
#   64 bits : ~/.local/share/wineprefixes/pronote-2026
#   32 bits : ~/.local/share/wineprefixes/pronote-2026-32
#
# Changelog v4.7 :
#   - Fix Solus (bug majeur) : le paquet « wine-32bit » n'existe plus.
#     Solus construit désormais Wine 11 en WoW64 intégré
#     (--enable-archs=x86_64,i386) : le paquet « wine » couvre 32 et 64 bits.
#     Les paquets sont installés un par un ; ceux absents du dépôt sont
#     ignorés au lieu de faire échouer toute la transaction eopkg.
#     En session Live, l'option --ignore-safety évite d'engorger la RAM avec
#     la mise à jour forcée de system.base.
#   - Fix Fedora (bug majeur) : les erreurs constatées (error=112,
#     « No space left on device », « wine: could not load kernel32.dll ») sont
#     dues au remplissage de la couche d'écriture du Live CD. Le script mesure
#     désormais l'espace libre avant d'installer Wine, avant le préfixe et
#     avant Pronote, avertit clairement en session Live et s'arrête avec un
#     message explicite au lieu de poursuivre sur un préfixe corrompu.
#     Installation dnf en deux temps (wine obligatoire, outils optionnels
#     séparés) : plus d'arrêt silencieux après « Complete! ».
#   - Fix Fedora GNOME (icône « n » au lieu du papillon) : téléchargements
#     compatibles wget2 (Fedora ≥ 40), busybox (Alpine) et curl, suppression
#     de l'option -L, conversion via magick ou convert, repli rsvg-convert,
#     extraction depuis l'exécutable Pronote (icoutils installé partout),
#     icône de secours SVG sans texte (plus de rendu de police aléatoire).
#   - Fix NixOS (32 bits bloqué sur « Forçage de la version Windows ») :
#     toutes les opérations Wine hors installateur sont bornées par un délai
#     (timeout), le forçage du registre passe par un seul import regedit,
#     wineserver est arrêté proprement en cas de blocage, et le choix
#     « messages Wine » est transmis au nix-shell (plus de double question).
#   - Fix Ubuntu MATE (Pronote absent du menu Éducation) : fichier de menu
#     XDG fusionné (~/.config/menus/applications-merged) qui place Pronote
#     explicitement dans Éducation (MATE, XFCE, Cinnamon, Budgie, KDE, LXQt),
#     winemenubuilder désactivé pendant l'installateur Pronote, nettoyage
#     récursif des entrées Wine résiduelles (.desktop + .menu).
#   - openSUSE / Void / Alpine : installation paquet par paquet (un paquet
#     manquant n'annule plus la transaction), dépôt community Alpine activé
#     si besoin, wget busybox géré.
#   - Aucune modification volontaire du comportement Debian/Ubuntu/Mint et
#     Arch/CachyOS : WineHQ (.asc + .key), ordre WineHQ → winetricks,
#     multilib, préfixes séparés 32/64, désinstallateurs identiques.
#
# Changelog v4.6 :
#   - Fix Kubuntu/Ubuntu 26.04 (resolute) : erreur 127 « wineboot introuvable ».
#     WineHQ 11 place les binaires dans /opt/wine-stable/bin sans toujours
#     créer les liens /usr/bin. Le script découvre wine, wineboot, wineserver
#     et winecfg, les injecte dans le PATH, et n'utilise plus « env wineboot »
#     (qui provoquait exactement le code 127 constaté).
#   - Fix Ubuntu 26.04 : clé WineHQ enregistrée aussi en .asc (APT 3.2 refuse
#     une clé ASCII sous une extension .key).
#   - Fix ordre Debian/Ubuntu : WineHQ est installé AVANT winetricks.
#     Avec WineHQ, winetricks est le script officiel autonome.
#   - Fix 32 bits / Wine 10+ / Wine 11 : « WINEARCH is set to win32 but this
#     is not supported in wow64 mode ». Le script sonde le support win32.
#     S'il est absent, Pronote 32 bits s'installe dans un préfixe WoW64 dédié.
#   - Les versions 32 et 64 bits restent installables en parallèle partout.
#   - Fix NixOS / GLF OS : nix-shell -p sur le nixpkgs système, avec repli
#     wineWow64Packages.stable → wineWowPackages.stable → wine64 → wine,
#     puis « nix shell nixpkgs#... » (flakes) si le canal est absent.
#   - Support Solus, Alpine Linux, Void Linux, openSUSE renforcé, sudo/doas.
#
# Changelog v4.5 :
#   - Fix Debian/Ubuntu/Mint : Windows 10 forcé sur la famille debian.
#   - Préfixes séparés par architecture + désinstallateurs 32/64.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration générale
# ------------------------------------------------------------------------------

readonly SCRIPT_VERSION="4.7"
readonly DEFAULT_YEAR="2026"
readonly DEFAULT_VERSION="2026.2.6"
readonly MIN_WINE_VERSION="9.0"
readonly PRONOTE_DOWNLOAD_PAGE="https://www.index-education.com/fr/telecharger-pronote.php"
readonly PRONOTE_ICON_URL="https://img.icons8.com/doodle/1200/pronote-logo.jpg"
readonly PRONOTE_ICON_URLS=(
    "https://img.icons8.com/doodle/1200/pronote-logo.jpg"
    "https://img.icons8.com/doodle/480/pronote-logo.png"
)
readonly HTTP_USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) PronoteInstaller/4.7"
readonly ICON_SIZES=(16 22 24 32 48 64 128 256)
readonly ICON_BASE_DIR="$HOME/.local/share/icons/hicolor"
readonly ICON_DIR="$ICON_BASE_DIR/scalable/apps"
readonly PIXMAP_DIR="$HOME/.local/share/pixmaps"
readonly BIN_DIR="$HOME/.local/bin"
readonly APP_DIR="$HOME/.local/share/applications"
readonly MENU_MERGE_DIR="$HOME/.config/menus/applications-merged"
readonly LOG_DIR="$HOME/.local/share/pronote-installer"
readonly LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"

# Espace disque (en Mo) : seuils d'avertissement et de blocage
readonly DISK_WARN_SYSTEM_MB=3000     # installation des paquets Wine
readonly DISK_WARN_HOME_MB=2500       # préfixe Wine + Pronote
readonly DISK_MIN_HOME_MB=1200        # en dessous : arrêt (échec certain)
readonly DISK_MIN_TMP_MB=400          # téléchargement de l'installateur

readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# URLs de base (seront potentiellement mises à jour par le scraping)
URL_32="https://tele3.index-education.com/telechargement/pn/v${DEFAULT_YEAR}.0/exe/Install_PRNclient_FR_${DEFAULT_VERSION}_win32.exe"
URL_64="https://tele3.index-education.com/telechargement/pn/v${DEFAULT_YEAR}.0/exe/Install_PRNclient_FR_${DEFAULT_VERSION}_win64.exe"
DEFAULT_URL="$URL_64"

# ------------------------------------------------------------------------------
# Variables globales
# ------------------------------------------------------------------------------

DISTRO_ID="unknown"
DISTRO_NAME="Inconnue"
DISTRO_FAMILY="unknown"

PRONOTE_URL="$DEFAULT_URL"
PRONOTE_YEAR="$DEFAULT_YEAR"
PRONOTE_VERSION="$DEFAULT_VERSION"
PRONOTE_ARCH="64"

PRONOTE_URL_FROM_OPTION=""
PRONOTE_ARCH_FROM_OPTION=""

SHOW_WINE_LOGS="0"
ASSUME_YES="0"
UNINSTALL_ONLY="0"
UNINSTALL_ARCH=""
IN_NIX_SHELL="0"
IS_LIVE_SESSION="0"

WIN_VERSION="win11"

# Mode du préfixe : win64 (Pronote 64 bits), win32 (préfixe 32 bits natif)
# ou wow64 (Pronote 32 bits dans un préfixe 64 bits WoW64 dédié)
PREFIX_MODE="win64"

# Binaires Wine résolus (corrigent l'erreur 127 et wineserver not found)
WINE_BIN=""
WINEBOOT_BIN=""
WINECFG_BIN=""
WINESERVER_BIN=""
WINE_WIN32_PREFIX_OK="unknown"

# Outil timeout détecté (gnu / busybox / none)
TIMEOUT_KIND=""

# Arguments d'origine (reprise NixOS)
ALL_ARGS=("$@")

# Permettre à l'utilisateur de forcer WINEPREFIX
WINEPREFIX_USER="${WINEPREFIX:-}"
WINEPREFIX="${WINEPREFIX_USER:-$HOME/.local/share/wineprefixes/pronote-$DEFAULT_YEAR}"
export WINEPREFIX

TMP_DIR="$(mktemp -d /tmp/pronote-installer-XXXXXX)"
trap 'rm -rf "$TMP_DIR" 2>/dev/null || true' EXIT

RUN_QUIET_ACTIVITY_DIR=""
RUN_QUIET_FINALIZE_MSG=""

# ==============================================================================
# Affichage / journalisation  (toujours sur stderr)
# ==============================================================================

log_info()    { echo -e "${BLUE}ℹ️  $*${NC}" >&2; }
log_success() { echo -e "${GREEN}✅ $*${NC}" >&2; }
log_warning() { echo -e "${YELLOW}⚠️  $*${NC}" >&2; }
log_error()   { echo -e "${RED}❌ $*${NC}" >&2; }

repeat_char() {
    local char="$1"
    local count="$2"
    local out=""
    local i

    for ((i = 0; i < count; i++)); do
        out+="$char"
    done

    printf "%s" "$out"
}

box_title() {
    local title="$1"
    local width="${2:-62}"
    local inner=$((width - 2))

    printf "╔"
    repeat_char "═" "$width"
    printf "╗\n"

    printf "║ %-*s ║\n" "$inner" "$title"

    printf "╚"
    repeat_char "═" "$width"
    printf "╝\n"
}

box_two_lines() {
    local line1="$1"
    local line2="$2"
    local width="${3:-62}"
    local inner=$((width - 2))

    printf "╔"
    repeat_char "═" "$width"
    printf "╗\n"

    printf "║ %-*s ║\n" "$inner" "$line1"
    printf "║ %-*s ║\n" "$inner" "$line2"

    printf "╚"
    repeat_char "═" "$width"
    printf "╝\n"
}

# ==============================================================================
# sudo / doas (Alpine, Void minimal, images live)
# ==============================================================================

ensure_privilege_helper() {
    if [ "$(id -u)" -eq 0 ]; then
        sudo() { "$@"; }
        return 0
    fi

    if command -v sudo >/dev/null 2>&1; then
        return 0
    fi

    if command -v doas >/dev/null 2>&1; then
        sudo() { doas "$@"; }
        log_info "sudo absent : utilisation de doas."
        return 0
    fi

    return 1
}

require_privilege_helper() {
    if ensure_privilege_helper; then
        return 0
    fi
    log_error "Ni sudo ni doas n'est disponible. Installez l'un des deux, ou relancez en root."
    exit 1
}

# ==============================================================================
# Aide
# ==============================================================================

usage() {
    cat << 'EOF'
Usage: pronote.sh [options]

Options:
  --help                 Afficher cette aide
  --yes                  Mode non-interactif (répond oui aux défauts)
  --arch 32|64           Forcer l'architecture de l'installateur
  --url URL              Utiliser une URL personnalisée d'installateur
  --uninstall [32|64]    Lancer le désinstallateur Pronote (32 ou 64 bits)
  --in-nix-shell         Utilisé en interne pour NixOS (ne pas utiliser)

Variables d'environnement facultatives :
  WINEPREFIX=/chemin     Forcer le préfixe Wine utilisé
  PRONOTE_IGNORE_DISK=1  Ignorer les contrôles d'espace disque

Notes :
  • Les versions 32 et 64 bits utilisent des préfixes Wine distincts et
    peuvent être installées en même temps.
  • Désinstallation : pronote-desinstaller-32 ou pronote-desinstaller-64
  • Wine 10+/11 en mode WoW64 : Pronote 32 bits s'installe dans un préfixe
    WoW64 dédié (WINEARCH=win32 n'est plus créé, car non supporté).
EOF
}

# ==============================================================================
# Animation de progression + exécution silencieuse
# ==============================================================================

progress_pulse() {
    local label="$1"
    local pid="$2"
    local activity_dir="${3:-}"
    local finalize_msg="${4:-Finalisation en cours, veuillez patienter quelques secondes...}"

    local width=24
    local block=7
    local pos=0
    local direction=1
    local start_time=$SECONDS

    local check_activity=0
    [ -n "$activity_dir" ] && check_activity=1

    local last_size=-1
    local stable_count=0
    local finalized=0
    local sample_tick=0
    local current_label="$label"

    if [ ! -t 1 ]; then
        while kill -0 "$pid" 2>/dev/null; do
            sleep 1
        done
        return
    fi

    while kill -0 "$pid" 2>/dev/null; do
        local bar=""
        local i
        local elapsed=$((SECONDS - start_time))
        local min=$((elapsed / 60))
        local sec=$((elapsed % 60))

        if [ "$check_activity" -eq 1 ] && [ "$finalized" -eq 0 ]; then
            sample_tick=$((sample_tick + 1))

            if (( sample_tick >= 8 )); then
                sample_tick=0
                local cur_size
                cur_size="$(du -sk "$activity_dir" 2>/dev/null | cut -f1)"
                cur_size="${cur_size:-0}"

                if [ "$cur_size" = "$last_size" ]; then
                    stable_count=$((stable_count + 1))
                else
                    stable_count=0
                fi
                last_size="$cur_size"

                if (( stable_count >= 3 && elapsed >= 5 )); then
                    finalized=1
                    current_label="$finalize_msg"
                fi
            fi
        fi

        for ((i = 0; i < width; i++)); do
            if (( i >= pos && i < pos + block )); then
                bar+="█"
            else
                bar+=" "
            fi
        done

        printf "\r\033[K%s [%s] %02d:%02d" "$current_label" "$bar" "$min" "$sec"

        pos=$((pos + direction))

        if (( pos <= 0 )); then
            pos=0
            direction=1
        elif (( pos + block >= width )); then
            pos=$((width - block))
            direction=-1
        fi

        sleep 0.12
    done

    printf "\r\033[K"
}

# run_quiet n'utilise pas « env COMMANDE » : env renvoyait 127 dès que
# wineboot/wineserver n'étaient pas dans le PATH (cas WineHQ 11 / Ubuntu 26.04).
# Un sous-shell bash exporte WINEDEBUG puis lance la commande, y compris
# lorsqu'il s'agit d'une fonction du script.
run_quiet() {
    local label="$1"
    shift

    if [[ "$SHOW_WINE_LOGS" == "1" ]]; then
        log_info "$label"
        echo "Mode expert actif : les messages Wine sont affichés."
        export WINEDEBUG="${WINEDEBUG:-}"
        "$@"
        return $?
    fi

    mkdir -p "$LOG_DIR"

    (
        export WINEDEBUG="${WINEDEBUG_QUIET:--all}"
        "$@"
    ) >>"$LOG_FILE" 2>&1 &

    local pid=$!
    progress_pulse "$label" "$pid" "$RUN_QUIET_ACTIVITY_DIR" "$RUN_QUIET_FINALIZE_MSG"

    set +e
    wait "$pid"
    local status=$?
    set -e

    if [ "$status" -eq 0 ]; then
        log_success "$label : terminé"
    else
        log_warning "$label : terminé avec un code retour $status"
        echo "Les détails techniques sont enregistrés ici :"
        echo "  $LOG_FILE"
    fi

    return "$status"
}

# ------------------------------------------------------------------------------
# Petit helper pour les questions (support --yes)
# ------------------------------------------------------------------------------

ask_user() {
    local prompt="$1"
    local default="$2"

    if [ "$ASSUME_YES" = "1" ]; then
        echo "$default"
        return 0
    fi

    local answer
    read -rp "$prompt" answer
    echo "${answer:-$default}"
}

ask_wine_output_mode() {
    if [ "$ASSUME_YES" = "1" ]; then
        SHOW_WINE_LOGS="0"
        return 0
    fi

    # NixOS : le choix a déjà été fait avant la relance dans nix-shell.
    if [ "$IN_NIX_SHELL" = "1" ] && [ -n "${PRONOTE_SHOW_WINE_LOGS:-}" ]; then
        SHOW_WINE_LOGS="$PRONOTE_SHOW_WINE_LOGS"
        if [ "$SHOW_WINE_LOGS" = "1" ]; then
            log_warning "Mode expert conservé : les logs Wine seront affichés."
        else
            log_info "Mode silencieux conservé : les logs Wine seront masqués."
        fi
        return 0
    fi

    echo ""
    echo "Par défaut, les messages techniques de Wine seront masqués."
    echo "Ils sont utiles uniquement pour diagnostiquer un problème."
    read -rp "Afficher les messages techniques de Wine ? [o/N] : " answer

    case "$answer" in
        o|O|oui|Oui|OUI|y|Y|yes|YES)
            SHOW_WINE_LOGS="1"
            log_warning "Mode expert activé : les logs Wine seront affichés."
            ;;
        *)
            SHOW_WINE_LOGS="0"
            log_info "Mode silencieux activé : les logs Wine seront masqués."
            ;;
    esac

    return 0
}

# ==============================================================================
# Détection système
# ==============================================================================

detect_distro() {
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release

        DISTRO_ID="${ID:-unknown}"
        DISTRO_NAME="${NAME:-Inconnue}"

        case "$DISTRO_ID" in
            ubuntu|debian|linuxmint|pop|elementary|neon|zorin|kali|kubuntu)
                DISTRO_FAMILY="debian"
                ;;
            fedora|nobara|ultramarine|rhel|centos|almalinux|rocky)
                DISTRO_FAMILY="fedora"
                ;;
            arch|cachyos|manjaro|endeavouros|garuda|omarchy)
                DISTRO_FAMILY="arch"
                ;;
            opensuse*|suse|opensuse-tumbleweed|opensuse-leap|opensuse-slowroll)
                DISTRO_FAMILY="suse"
                ;;
            nixos|glfos|glf-os)
                DISTRO_FAMILY="nixos"
                ;;
            slackware)
                DISTRO_FAMILY="slackware"
                ;;
            solus)
                DISTRO_FAMILY="solus"
                ;;
            alpine)
                DISTRO_FAMILY="alpine"
                ;;
            void)
                DISTRO_FAMILY="void"
                ;;
            *)
                DISTRO_FAMILY="unknown"
                ;;
        esac

        if [ "$DISTRO_FAMILY" = "unknown" ] && [ -n "${ID_LIKE:-}" ]; then
            case " ${ID_LIKE} " in
                *" debian "*|*" ubuntu "*)   DISTRO_FAMILY="debian" ;;
                *" fedora "*|*" rhel "*)     DISTRO_FAMILY="fedora" ;;
                *" arch "*)                  DISTRO_FAMILY="arch" ;;
                *" suse "*|*" opensuse "*)   DISTRO_FAMILY="suse" ;;
                *" nixos "*)                 DISTRO_FAMILY="nixos" ;;
                *" slackware "*)             DISTRO_FAMILY="slackware" ;;
                *" solus "*)                 DISTRO_FAMILY="solus" ;;
                *" alpine "*)                DISTRO_FAMILY="alpine" ;;
                *" void "*)                  DISTRO_FAMILY="void" ;;
            esac

            if [ "$DISTRO_FAMILY" != "unknown" ]; then
                log_info "Distribution dérivée détectée via ID_LIKE (${ID_LIKE}) → famille : $DISTRO_FAMILY"
            fi
        fi
    else
        DISTRO_ID="unknown"
        DISTRO_NAME="Inconnue"
        DISTRO_FAMILY="unknown"
    fi
}

# Session Live (ISO/USB) : la couche d'écriture est limitée (RAM / overlay).
# C'est la cause des échecs « No space left on device » vus sur Fedora Live.
detect_live_session() {
    IS_LIVE_SESSION="0"

    if grep -qE 'rd\.live\.image|boot=live|boot=casper|live-media|rd\.live\.overlay|overlayroot|archisobasedir|root=live:' /proc/cmdline 2>/dev/null; then
        IS_LIVE_SESSION="1"
    fi

    local d
    for d in /run/initramfs/live /run/live /lib/live/mount /run/archiso /run/initramfs/isoscan /iso; do
        if [ -d "$d" ]; then
            IS_LIVE_SESSION="1"
        fi
    done

    case "${USER:-$(id -un 2>/dev/null || true)}" in
        liveuser|live)
            IS_LIVE_SESSION="1"
            ;;
    esac

    if [ "$IS_LIVE_SESSION" = "1" ]; then
        log_info "Environnement Live détecté (système démarré depuis une image ISO/USB)."
    fi

    return 0
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

prepend_path() {
    local dir="$1"
    [ -d "$dir" ] || return 0
    case ":$PATH:" in
        *":$dir:"*) ;;
        *) export PATH="$dir:$PATH" ;;
    esac
}

get_wine_version() {
    local bin="${WINE_BIN:-}"
    if [ -z "$bin" ]; then
        bin="$(command -v wine 2>/dev/null || true)"
    fi
    if [ -n "$bin" ] && [ -x "$bin" ]; then
        "$bin" --version 2>/dev/null | grep -Eo '[0-9]+([.][0-9]+)+' | head -n1 || echo "0"
    else
        echo "0"
    fi
}

version_lt() {
    local v1="$1"
    local v2="$2"

    [ "$v1" != "$v2" ] && [ "$(printf '%s\n%s\n' "$v1" "$v2" | sort -V | head -n1)" = "$v1" ]
}

# ------------------------------------------------------------------------------
# Exécution bornée dans le temps (évite les blocages Wine : NixOS 32 bits)
# ------------------------------------------------------------------------------

detect_timeout_tool() {
    if [ -n "$TIMEOUT_KIND" ]; then
        return 0
    fi

    if check_command timeout; then
        if timeout --version >/dev/null 2>&1; then
            TIMEOUT_KIND="gnu"
        else
            TIMEOUT_KIND="busybox"
        fi
    else
        TIMEOUT_KIND="none"
    fi

    return 0
}

# run_with_timeout SECONDES commande [args...]
# Renvoie 124 (ou 137) si le délai est dépassé.
run_with_timeout() {
    local secs="$1"
    shift

    detect_timeout_tool

    case "$TIMEOUT_KIND" in
        gnu)
            timeout -k 15 "$secs" "$@"
            ;;
        busybox)
            timeout "$secs" "$@"
            ;;
        *)
            "$@"
            ;;
    esac
}

status_is_timeout() {
    local st="$1"
    [ "$st" -eq 124 ] || [ "$st" -eq 137 ]
}

# ------------------------------------------------------------------------------
# Téléchargements : GNU wget, wget2 (Fedora ≥ 40), busybox wget (Alpine), curl
# ------------------------------------------------------------------------------
# wget2 et busybox n'acceptent pas toutes les options de GNU wget (ex. -L).
# Un échec silencieux ici était à l'origine de l'icône « n » sous Fedora.
# ------------------------------------------------------------------------------

wget_flavor() {
    if ! check_command wget; then
        echo "none"
        return 0
    fi

    local v
    v="$(wget --version 2>&1 | head -n1 || true)"

    case "$v" in
        *[Bb]usy[Bb]ox*) echo "busybox" ;;
        *[Ww]get2*)      echo "wget2" ;;
        *)               echo "gnu" ;;
    esac
}

# download_file URL DESTINATION [1 = afficher la progression]
download_file() {
    local url="$1"
    local dest="$2"
    local visible="${3:-0}"
    local flavor
    local ok=1

    flavor="$(wget_flavor)"

    set +e
    case "$flavor" in
        busybox)
            wget -q -T 30 -U "$HTTP_USER_AGENT" -O "$dest" "$url" 2>/dev/null
            ok=$?
            ;;
        gnu|wget2)
            if [ "$visible" = "1" ]; then
                wget --timeout=30 --tries=3 --user-agent="$HTTP_USER_AGENT" -O "$dest" "$url"
                ok=$?
            else
                wget -q --timeout=30 --tries=3 --user-agent="$HTTP_USER_AGENT" -O "$dest" "$url" 2>/dev/null
                ok=$?
            fi
            ;;
        *)
            ok=1
            ;;
    esac

    if [ "$ok" -ne 0 ] && check_command curl; then
        if [ "$visible" = "1" ]; then
            curl -fL --retry 3 --connect-timeout 30 -A "$HTTP_USER_AGENT" -o "$dest" "$url"
            ok=$?
        else
            curl -fsSL --retry 3 --connect-timeout 30 -A "$HTTP_USER_AGENT" -o "$dest" "$url" 2>/dev/null
            ok=$?
        fi
    fi
    set -e

    if [ "$ok" -ne 0 ] || [ ! -s "$dest" ]; then
        rm -f "$dest" 2>/dev/null || true
        return 1
    fi

    return 0
}

# fetch_url_stdout URL  → contenu sur la sortie standard
fetch_url_stdout() {
    local url="$1"
    local flavor
    flavor="$(wget_flavor)"

    case "$flavor" in
        busybox)
            wget -q -T 30 -U "$HTTP_USER_AGENT" -O - "$url" 2>/dev/null && return 0
            ;;
        gnu|wget2)
            wget -q --timeout=30 --tries=2 --user-agent="$HTTP_USER_AGENT" -O - "$url" 2>/dev/null && return 0
            ;;
    esac

    if check_command curl; then
        curl -fsSL --connect-timeout 30 -A "$HTTP_USER_AGENT" "$url" 2>/dev/null && return 0
    fi

    return 1
}

# url_exists URL  → 0 si la ressource répond (HEAD / spider)
url_exists() {
    local url="$1"
    local flavor
    flavor="$(wget_flavor)"

    case "$flavor" in
        busybox)
            wget -q --spider -T 20 -U "$HTTP_USER_AGENT" "$url" >/dev/null 2>&1 && return 0
            ;;
        gnu|wget2)
            wget -q --spider --timeout=20 --tries=2 --user-agent="$HTTP_USER_AGENT" "$url" >/dev/null 2>&1 && return 0
            ;;
    esac

    if check_command curl; then
        curl -fsIL --connect-timeout 20 -A "$HTTP_USER_AGENT" "$url" >/dev/null 2>&1 && return 0
    fi

    return 1
}

# ------------------------------------------------------------------------------
# Espace disque
# ------------------------------------------------------------------------------

# free_mb_at CHEMIN → Mo libres sur le système de fichiers (vide si inconnu)
free_mb_at() {
    local path="$1"

    while [ -n "$path" ] && [ ! -d "$path" ] && [ "$path" != "/" ]; do
        path="$(dirname "$path")"
    done

    local mb
    mb="$(df -Pm "$path" 2>/dev/null | awk 'NR==2 {print $4}' || true)"

    case "$mb" in
        ''|*[!0-9]*) echo "" ;;
        *)           echo "$mb" ;;
    esac
}

fmt_mb() {
    local mb="$1"

    if [ -z "$mb" ]; then
        echo "inconnu"
        return 0
    fi

    if [ "$mb" -ge 1024 ]; then
        awk -v m="$mb" 'BEGIN { printf "%.1f Go", m / 1024 }'
    else
        echo "${mb} Mo"
    fi
}

print_disk_hint_if_low() {
    local mb
    mb="$(free_mb_at "$HOME")"

    if [ -n "$mb" ] && [ "$mb" -lt 500 ]; then
        log_error "Espace disque quasiment nul dans $HOME ($(fmt_mb "$mb")) : c'est très probablement la cause."
        if [ "$IS_LIVE_SESSION" = "1" ]; then
            echo "Session Live : la couche d'écriture (RAM) est pleine. Installez la distribution"
            echo "sur disque, ou démarrez le Live avec plus de RAM / un overlay persistant."
        fi
    fi

    return 0
}

# Avant l'installation de Wine : avertissement (avec confirmation) si l'espace
# est faible. Bloquant uniquement si l'utilisateur refuse de continuer.
check_disk_space_before_wine() {
    local sys_path="/usr"
    if [ -d /nix/store ]; then
        sys_path="/nix/store"
    fi

    local sys_mb home_mb tmp_mb
    sys_mb="$(free_mb_at "$sys_path")"
    home_mb="$(free_mb_at "$HOME")"
    tmp_mb="$(free_mb_at "$TMP_DIR")"

    log_info "Espace disque libre : système $(fmt_mb "$sys_mb") | dossier personnel $(fmt_mb "$home_mb") | /tmp $(fmt_mb "$tmp_mb")"

    if [ "$IS_LIVE_SESSION" = "1" ]; then
        log_warning "Session Live : la couche d'écriture (RAM/overlay) est limitée."
        echo "  Wine et ses dépendances (~1,5 Go), le préfixe Wine (~0,7 Go) et l'installateur"
        echo "  Pronote (~0,3 Go) doivent tenir dans cet espace. Un manque de place provoque"
        echo "  des erreurs « No space left on device » / « error=112 » et un Wine inutilisable."
    fi

    local wine_present=0
    if wine_is_available; then
        wine_present=1
    fi

    local -a problems=()

    if [ -n "$sys_mb" ] && [ "$wine_present" -eq 0 ] && [ "$sys_mb" -lt "$DISK_WARN_SYSTEM_MB" ]; then
        problems+=("système ($sys_path) : $(fmt_mb "$sys_mb") libres, ${DISK_WARN_SYSTEM_MB} Mo recommandés pour installer Wine")
    fi
    if [ -n "$home_mb" ] && [ "$home_mb" -lt "$DISK_WARN_HOME_MB" ]; then
        problems+=("dossier personnel : $(fmt_mb "$home_mb") libres, ${DISK_WARN_HOME_MB} Mo recommandés (préfixe Wine + Pronote)")
    fi
    if [ -n "$tmp_mb" ] && [ "$tmp_mb" -lt "$DISK_MIN_TMP_MB" ]; then
        problems+=("/tmp : $(fmt_mb "$tmp_mb") libres, ${DISK_MIN_TMP_MB} Mo nécessaires au téléchargement")
    fi

    if [ "${#problems[@]}" -eq 0 ]; then
        return 0
    fi

    echo ""
    log_warning "Espace disque potentiellement insuffisant :"
    local p
    for p in "${problems[@]}"; do
        echo "  • $p"
    done
    echo ""

    if [ "${PRONOTE_IGNORE_DISK:-0}" = "1" ] || [ "$ASSUME_YES" = "1" ]; then
        log_warning "Poursuite malgré l'avertissement (PRONOTE_IGNORE_DISK / --yes)."
        return 0
    fi

    local answer
    answer="$(ask_user "Continuer malgré tout ? [o/N] : " "N")"
    case "$answer" in
        o|O|oui|Oui|OUI|y|Y|yes|YES)
            log_warning "Poursuite à vos risques : surveillez les messages d'erreur d'espace disque."
            return 0
            ;;
    esac

    log_error "Installation interrompue : libérez de l'espace (ou installez la distribution sur disque) puis relancez."
    exit 1
}

# Avant le préfixe / Pronote : blocage net si l'échec est certain.
check_disk_space_before_pronote() {
    local home_mb tmp_mb
    home_mb="$(free_mb_at "$WINEPREFIX")"
    tmp_mb="$(free_mb_at "$TMP_DIR")"

    local fatal=0

    if [ -n "$home_mb" ] && [ "$home_mb" -lt "$DISK_MIN_HOME_MB" ]; then
        log_error "Espace insuffisant pour Pronote dans $(dirname "$WINEPREFIX") : $(fmt_mb "$home_mb") libres (minimum ${DISK_MIN_HOME_MB} Mo)."
        fatal=1
    fi
    if [ -n "$tmp_mb" ] && [ "$tmp_mb" -lt "$DISK_MIN_TMP_MB" ]; then
        log_error "Espace insuffisant dans /tmp pour télécharger l'installateur : $(fmt_mb "$tmp_mb") libres (minimum ${DISK_MIN_TMP_MB} Mo)."
        fatal=1
    fi

    if [ "$fatal" -eq 1 ] && [ "${PRONOTE_IGNORE_DISK:-0}" != "1" ]; then
        echo "L'installation échouerait avec des erreurs « No space left on device »."
        if [ "$IS_LIVE_SESSION" = "1" ]; then
            echo "Session Live : installez la distribution sur disque, ou démarrez avec plus de RAM."
        fi
        echo "Libérez de l'espace puis relancez (ou PRONOTE_IGNORE_DISK=1 pour forcer)."
        exit 1
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Résolution des binaires Wine (erreur 127 / wineserver not found)
# ------------------------------------------------------------------------------
# WineHQ 11 sous Ubuntu 26.04 installe :
#   /opt/wine-stable/bin/wine
#   /opt/wine-stable/bin/wineboot
#   /opt/wine-stable/bin/wineserver
# sans garantir les liens dans /usr/bin. winetricks cherche wineserver dans
# le PATH. On reconstitue donc un PATH cohérent, et on mémorise les chemins.
# ------------------------------------------------------------------------------

discover_wine_paths() {
    local dir candidate resolved wine_dir

    for dir in \
        /opt/wine-stable/bin \
        /opt/wine-devel/bin \
        /opt/wine-staging/bin \
        /usr/lib/wine \
        /usr/lib64/wine \
        "$HOME/.local/bin" \
        /usr/local/bin \
        /usr/bin
    do
        prepend_path "$dir"
    done

    hash -r 2>/dev/null || true

    WINE_BIN=""
    WINEBOOT_BIN=""
    WINECFG_BIN=""
    WINESERVER_BIN=""

    for candidate in wine wine64; do
        if check_command "$candidate"; then
            WINE_BIN="$(command -v "$candidate")"
            break
        fi
    done

    if [ -z "$WINE_BIN" ]; then
        for candidate in \
            /opt/wine-stable/bin/wine \
            /opt/wine-devel/bin/wine \
            /opt/wine-staging/bin/wine \
            /usr/bin/wine \
            /usr/bin/wine64
        do
            if [ -x "$candidate" ]; then
                WINE_BIN="$candidate"
                prepend_path "$(dirname "$candidate")"
                break
            fi
        done
    fi

    if [ -n "$WINE_BIN" ]; then
        resolved="$(readlink -f "$WINE_BIN" 2>/dev/null || echo "$WINE_BIN")"
        wine_dir="$(dirname "$resolved")"
        prepend_path "$wine_dir"

        [ -x "$wine_dir/wineboot" ]    && WINEBOOT_BIN="$wine_dir/wineboot"
        [ -x "$wine_dir/winecfg" ]     && WINECFG_BIN="$wine_dir/winecfg"
        [ -x "$wine_dir/wineserver" ]  && WINESERVER_BIN="$wine_dir/wineserver"
    fi

    if [ -z "$WINEBOOT_BIN" ]   && check_command wineboot;   then WINEBOOT_BIN="$(command -v wineboot)"; fi
    if [ -z "$WINECFG_BIN" ]    && check_command winecfg;    then WINECFG_BIN="$(command -v winecfg)"; fi
    if [ -z "$WINESERVER_BIN" ] && check_command wineserver; then WINESERVER_BIN="$(command -v wineserver)"; fi

    hash -r 2>/dev/null || true

    if [ -n "$WINE_BIN" ]; then
        export WINE="$WINE_BIN"
    fi
    if [ -n "$WINESERVER_BIN" ]; then
        export WINESERVER="$WINESERVER_BIN"
    fi

    return 0
}

wine_is_available() {
    discover_wine_paths
    [ -n "$WINE_BIN" ] && [ -x "$WINE_BIN" ]
}

# Lance wineboot même si le wrapper n'est pas dans le PATH.
# Wine 11 : « wine wineboot --init » fonctionne (wineboot.exe est un builtin).
run_wineboot_tool() {
    if [ -n "${WINEBOOT_BIN:-}" ] && [ -x "$WINEBOOT_BIN" ]; then
        "$WINEBOOT_BIN" "$@"
        return $?
    fi
    if [ -n "${WINE_BIN:-}" ] && [ -x "$WINE_BIN" ]; then
        "$WINE_BIN" wineboot "$@"
        return $?
    fi
    log_error "wineboot introuvable (ni wrapper, ni binaire wine)."
    return 127
}

run_winecfg_tool() {
    if [ -n "${WINECFG_BIN:-}" ] && [ -x "$WINECFG_BIN" ]; then
        "$WINECFG_BIN" "$@"
        return $?
    fi
    if [ -n "${WINE_BIN:-}" ] && [ -x "$WINE_BIN" ]; then
        "$WINE_BIN" winecfg "$@"
        return $?
    fi
    log_warning "winecfg introuvable."
    return 1
}

run_wineserver_tool() {
    if [ -n "${WINESERVER_BIN:-}" ] && [ -x "$WINESERVER_BIN" ]; then
        "$WINESERVER_BIN" "$@"
        return $?
    fi
    if check_command wineserver; then
        wineserver "$@"
        return $?
    fi
    return 0
}

run_wine_bin() {
    if [ -n "${WINE_BIN:-}" ] && [ -x "$WINE_BIN" ]; then
        "$WINE_BIN" "$@"
        return $?
    fi
    wine "$@"
}

# Attend la fin des processus Wine du préfixe courant, avec délai maximal.
# Si le délai est dépassé (processus bloqué), le wineserver est arrêté.
wait_wineserver_idle() {
    local secs="${1:-60}"
    local bin="${WINESERVER_BIN:-}"

    if [ -z "$bin" ]; then
        bin="$(command -v wineserver 2>/dev/null || true)"
    fi
    if [ -z "$bin" ]; then
        return 0
    fi

    local st=0
    set +e
    run_with_timeout "$secs" "$bin" -w >/dev/null 2>&1
    st=$?
    set -e

    if status_is_timeout "$st"; then
        log_warning "Des processus Wine restent actifs après ${secs}s : arrêt du wineserver de ce préfixe."
        "$bin" -k >/dev/null 2>&1 || true
        sleep 1
    fi

    return 0
}

print_wine_diagnostics() {
    echo ""
    echo "Diagnostic Wine :"
    echo "  PATH        = $PATH"
    echo "  wine        = ${WINE_BIN:-introuvable}"
    echo "  wineboot    = ${WINEBOOT_BIN:-introuvable (repli : wine wineboot)}"
    echo "  winecfg     = ${WINECFG_BIN:-introuvable}"
    echo "  wineserver  = ${WINESERVER_BIN:-introuvable}"
    echo "  version     = $(get_wine_version)"
    echo "  WINEPREFIX  = $WINEPREFIX"
    echo "  WINEARCH    = ${WINEARCH:-non défini}"
    echo "  mode préfixe= $PREFIX_MODE"
    echo "  espace libre= $(fmt_mb "$(free_mb_at "$WINEPREFIX")") (préfixe) / $(fmt_mb "$(free_mb_at /tmp)") (/tmp)"
    echo ""
}

# ------------------------------------------------------------------------------
# winetricks autonome (GitHub) — évite le paquet Debian qui dépend de « wine »
# ------------------------------------------------------------------------------

install_winetricks_standalone() {
    log_info "Installation autonome de winetricks (script officiel Winetricks)..."
    mkdir -p "$BIN_DIR"
    prepend_path "$BIN_DIR"

    local wt="$BIN_DIR/winetricks"
    local url="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"

    if ! download_file "$url" "$wt"; then
        log_warning "Téléchargement de winetricks impossible."
        return 1
    fi

    chmod +x "$wt"

    if ! head -n1 "$wt" | grep -qE '^#!' || ! grep -q "winetricks" "$wt"; then
        log_error "Le fichier winetricks téléchargé est invalide."
        rm -f "$wt"
        return 1
    fi

    hash -r 2>/dev/null || true
    log_success "winetricks installé dans $wt"
    return 0
}

# Garantit un winetricks utilisable : paquet de la distribution s'il est
# récent, sinon version autonome dans ~/.local/bin (prioritaire dans le PATH).
ensure_winetricks() {
    prepend_path "$BIN_DIR"
    hash -r 2>/dev/null || true

    if check_command winetricks; then
        local wt_ver=""
        wt_ver="$(winetricks --version 2>/dev/null | grep -oE '20[0-9]{6}' | head -n1 || true)"

        if [ -n "$wt_ver" ] && [ "$wt_ver" -lt 20230101 ] 2>/dev/null; then
            log_warning "winetricks trop ancien ($wt_ver) pour Wine récent : installation d'une version à jour."
            install_winetricks_standalone || log_warning "winetricks conservé dans sa version actuelle."
        else
            log_success "winetricks disponible : $(command -v winetricks)${wt_ver:+ (version $wt_ver)}"
        fi
        return 0
    fi

    if ! install_winetricks_standalone; then
        log_warning "winetricks indisponible : les composants Windows optionnels (polices) seront ignorés."
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Version Windows adaptée à la famille de distribution
# ------------------------------------------------------------------------------
# Sur Debian/Ubuntu/Mint, Wine est souvent livré en paquets séparés
# (wine32/wine64) et, avec « Windows 11 », l'installateur Index Éducation
# refuse de s'installer. Windows 10 contourne le refus.
# Arch / Fedora / SUSE / Solus / Void / Alpine / NixOS conservent win11.
# ------------------------------------------------------------------------------

set_target_windows_version() {
    case "$DISTRO_FAMILY" in
        debian)
            WIN_VERSION="win10"
            log_info "Famille Debian détectée : la version Windows annoncée sera Windows 10."
            log_info "(contournement du refus d'installation 32/64 bits sur Debian/Ubuntu/Mint)"
            ;;
        *)
            WIN_VERSION="win11"
            ;;
    esac
}

win_version_label() {
    case "$WIN_VERSION" in
        win10) echo "Windows 10" ;;
        win11) echo "Windows 11" ;;
        *)     echo "$WIN_VERSION" ;;
    esac
}

win_version_product_name() {
    case "$WIN_VERSION" in
        win10) echo "Windows 10 Pro" ;;
        *)     echo "Windows 11 Pro" ;;
    esac
}

win_version_build() {
    case "$WIN_VERSION" in
        win10) echo "19045" ;;
        *)     echo "22000" ;;
    esac
}

detect_prefix_arch_at() {
    local prefix="$1"

    if [ ! -d "$prefix" ]; then
        echo "none"
        return
    fi

    if [ -f "$prefix/system.reg" ]; then
        if grep -qE '^#arch=win64' "$prefix/system.reg" 2>/dev/null; then
            echo "64"
            return
        fi
        if grep -qE '^#arch=win32' "$prefix/system.reg" 2>/dev/null; then
            echo "32"
            return
        fi
    fi

    echo "64"
}

detect_prefix_arch() {
    detect_prefix_arch_at "$WINEPREFIX"
}

# ------------------------------------------------------------------------------
# Préfixes séparés par architecture
# ------------------------------------------------------------------------------
# 64 bits : ~/.local/share/wineprefixes/pronote-ANNEE  (chemin historique)
# 32 bits : ~/.local/share/wineprefixes/pronote-ANNEE-32
# Même lorsque Wine refuse WINEARCH=win32 (mode WoW64), le préfixe 32 bits
# reste un dossier distinct : les deux clients coexistent.
# ------------------------------------------------------------------------------

set_wineprefix() {
    if [ -n "$WINEPREFIX_USER" ]; then
        WINEPREFIX="$WINEPREFIX_USER"
    else
        local base="$HOME/.local/share/wineprefixes/pronote-$PRONOTE_YEAR"

        if [ "$PRONOTE_ARCH" = "32" ]; then
            if [ ! -d "${base}-32" ] && [ "$(detect_prefix_arch_at "$base")" = "32" ]; then
                WINEPREFIX="$base"
            else
                WINEPREFIX="${base}-32"
            fi
        else
            WINEPREFIX="$base"
        fi
    fi

    export WINEPREFIX
    mkdir -p "$(dirname "$WINEPREFIX")"
}

# ------------------------------------------------------------------------------
# Sondage WINEARCH=win32 (Wine 11 / nouveau WoW64)
# ------------------------------------------------------------------------------

probe_win32_prefix_support() {
    if [ "$WINE_WIN32_PREFIX_OK" = "1" ]; then
        return 0
    fi
    if [ "$WINE_WIN32_PREFIX_OK" = "0" ]; then
        return 1
    fi

    discover_wine_paths
    if [ -z "$WINE_BIN" ]; then
        WINE_WIN32_PREFIX_OK="0"
        return 1
    fi

    log_info "Vérification du support des préfixes Wine 32 bits natifs (WINEARCH=win32)..."

    local test_prefix="$TMP_DIR/wine-win32-probe"
    rm -rf "$test_prefix"
    mkdir -p "$test_prefix"

    local out=""
    local status=0

    set +e
    out="$(
        export WINEPREFIX="$test_prefix"
        export WINEARCH="win32"
        export WINEDEBUG="-all"
        export WINEDLLOVERRIDES="mscoree,mshtml,winemenubuilder.exe="
        if [ -n "${WINEBOOT_BIN:-}" ] && [ -x "$WINEBOOT_BIN" ]; then
            run_with_timeout 600 "$WINEBOOT_BIN" --init 2>&1
        else
            run_with_timeout 600 "$WINE_BIN" wineboot --init 2>&1
        fi
    )"
    status=$?

    (
        export WINEPREFIX="$test_prefix"
        export WINEARCH="win32"
        run_with_timeout 30 "${WINESERVER_BIN:-wineserver}" -k >/dev/null 2>&1
    ) || true
    set -e

    rm -rf "$test_prefix" 2>/dev/null || true

    if grep -qi "not supported in wow64" <<< "$out"; then
        WINE_WIN32_PREFIX_OK="0"
        log_info "Wine fonctionne en mode WoW64 : les préfixes WINEARCH=win32 ne sont pas supportés."
        log_info "Pronote 32 bits sera installé dans un préfixe WoW64 dédié, séparé du 64 bits."
        return 1
    fi

    if [ "$status" -ne 0 ]; then
        WINE_WIN32_PREFIX_OK="0"
        log_warning "Création d'un préfixe 32 bits natif impossible (code $status) : repli sur un préfixe WoW64 dédié."
        return 1
    fi

    WINE_WIN32_PREFIX_OK="1"
    log_success "Préfixes Wine 32 bits natifs supportés : Pronote 32 bits utilisera WINEARCH=win32."
    return 0
}

# ==============================================================================
# Version Pronote : détection en ligne, choix 32/64 bits, URL personnalisée
# ==============================================================================

check_latest_version() {
    log_info "Vérification de la dernière version de Pronote disponible..."

    local page=""
    page="$(fetch_url_stdout "$PRONOTE_DOWNLOAD_PAGE" || true)"

    if [ -z "$page" ]; then
        log_warning "Impossible de vérifier la dernière version (site inaccessible). Version par défaut conservée : $DEFAULT_VERSION"
        return 0
    fi

    local found_url64="" found_url32="" found_ver=""

    found_url64="$(grep -oE 'https?://[A-Za-z0-9./_-]*Install_PRNclient_FR_[0-9]+\.[0-9]+\.[0-9]+_win64\.exe' <<< "$page" | head -n1 || true)"
    found_url32="$(grep -oE 'https?://[A-Za-z0-9./_-]*Install_PRNclient_FR_[0-9]+\.[0-9]+\.[0-9]+_win32\.exe' <<< "$page" | head -n1 || true)"

    if [ -n "$found_url64" ]; then
        found_ver="$(sed -E 's/.*Install_PRNclient_FR_([0-9]+\.[0-9]+\.[0-9]+)_win64\.exe.*/\1/' <<< "$found_url64")"
    else
        # Nom de fichier sans URL complète
        local fname=""
        fname="$(grep -oE 'Install_PRNclient_FR_[0-9]+\.[0-9]+\.[0-9]+_win64\.exe' <<< "$page" | head -n1 || true)"
        if [ -n "$fname" ]; then
            found_ver="$(sed -E 's/Install_PRNclient_FR_([0-9]+\.[0-9]+\.[0-9]+)_win64\.exe/\1/' <<< "$fname")"
        fi
    fi

    if [ -z "$found_ver" ]; then
        # Texte de la page : « CLIENT PRONOTE 2026 - 2.6 »
        local txt="" year="" minor=""
        txt="$(grep -oE 'CLIENT PRONOTE[[:space:]]+[0-9]{4}[[:space:]]*-[[:space:]]*[0-9]+\.[0-9]+' <<< "$page" | head -n1 || true)"
        if [ -n "$txt" ]; then
            year="$(grep -oE '[0-9]{4}' <<< "$txt" | head -n1 || true)"
            minor="$(grep -oE '[0-9]+\.[0-9]+$' <<< "$txt" | head -n1 || true)"
            if [ -n "$year" ] && [ -n "$minor" ]; then
                found_ver="${year}.${minor}"
            fi
        fi
    fi

    if [ -z "$found_ver" ]; then
        log_warning "Version non détectée sur la page de téléchargement ; version par défaut conservée : $DEFAULT_VERSION"
        return 0
    fi

    if [ "$found_ver" = "$DEFAULT_VERSION" ]; then
        log_success "Version Pronote à jour : $found_ver"
        if [ -n "$found_url64" ]; then URL_64="$found_url64"; fi
        if [ -n "$found_url32" ]; then URL_32="$found_url32"; fi
        DEFAULT_URL="$URL_64"
        return 0
    fi

    log_info "Version détectée sur le site : $found_ver (version intégrée au script : $DEFAULT_VERSION)"
    PRONOTE_VERSION="$found_ver"
    PRONOTE_YEAR="${found_ver%%.*}"

    if [ -n "$found_url64" ]; then
        URL_64="$found_url64"
    else
        URL_64="https://tele3.index-education.com/telechargement/pn/v${PRONOTE_YEAR}.0/exe/Install_PRNclient_FR_${PRONOTE_VERSION}_win64.exe"
    fi
    if [ -n "$found_url32" ]; then
        URL_32="$found_url32"
    else
        URL_32="https://tele3.index-education.com/telechargement/pn/v${PRONOTE_YEAR}.0/exe/Install_PRNclient_FR_${PRONOTE_VERSION}_win32.exe"
    fi
    DEFAULT_URL="$URL_64"

    log_success "Le script utilisera Pronote $PRONOTE_VERSION."
    return 0
}

get_pronote_url() {
    echo ""
    box_title "Choix de la version de Pronote" 46
    echo ""

    if [ -n "$PRONOTE_ARCH_FROM_OPTION" ]; then
        PRONOTE_ARCH="$PRONOTE_ARCH_FROM_OPTION"
        log_info "Architecture imposée par --arch : $PRONOTE_ARCH bits"
    else
        echo "Quelle version de Pronote Client souhaitez-vous installer ?"
        echo ""
        echo "  1) 64 bits (recommandé)"
        echo "  2) 32 bits"
        echo ""
        echo "Les deux versions peuvent être installées l'une après l'autre :"
        echo "chacune possède son propre préfixe Wine et son propre désinstallateur."
        echo ""

        local choice
        choice="$(ask_user "Votre choix [1/2] [Entrée=1] : " "1")"

        case "$choice" in
            2|32)
                PRONOTE_ARCH="32"
                ;;
            *)
                PRONOTE_ARCH="64"
                ;;
        esac
    fi

    if [ "$PRONOTE_ARCH" = "32" ]; then
        PRONOTE_URL="$URL_32"
    else
        PRONOTE_URL="$URL_64"
    fi

    log_info "Version retenue : Pronote $PRONOTE_VERSION - $PRONOTE_ARCH bits"
}

process_custom_url() {
    PRONOTE_URL="$PRONOTE_URL_FROM_OPTION"
    log_info "URL personnalisée : $PRONOTE_URL"

    local fname
    fname="$(basename "$PRONOTE_URL")"

    if [ -n "$PRONOTE_ARCH_FROM_OPTION" ]; then
        PRONOTE_ARCH="$PRONOTE_ARCH_FROM_OPTION"
    else
        case "$fname" in
            *win32*|*x86.exe|*_32*)
                PRONOTE_ARCH="32"
                ;;
            *)
                PRONOTE_ARCH="64"
                ;;
        esac
    fi

    local ver=""
    ver="$(grep -oE '[0-9]{4}\.[0-9]+\.[0-9]+' <<< "$fname" | head -n1 || true)"
    if [ -n "$ver" ]; then
        PRONOTE_VERSION="$ver"
        PRONOTE_YEAR="${ver%%.*}"
    fi

    log_info "Architecture : $PRONOTE_ARCH bits — version : $PRONOTE_VERSION"
}

# ==============================================================================
# Installation de Wine : famille Debian / Ubuntu / Mint  (WineHQ)
# ==============================================================================
# Comportement v4.6 conservé : WineHQ configuré AVANT winetricks, clé .asc
# (APT 3.2) + copie .key, repli sur Wine des dépôts si WineHQ est indisponible.
# ------------------------------------------------------------------------------

# Affiche « base codename » (ex. « ubuntu noble », « debian trixie ») ou rien.
debian_winehq_target() {
    local base="" codename=""
    local os_id="" os_id_like="" os_ubuntu_codename="" os_version_codename=""

    if [ -f /etc/os-release ]; then
        os_id="$(. /etc/os-release; echo "${ID:-}")"
        os_id_like="$(. /etc/os-release; echo "${ID_LIKE:-}")"
        os_ubuntu_codename="$(. /etc/os-release; echo "${UBUNTU_CODENAME:-}")"
        os_version_codename="$(. /etc/os-release; echo "${VERSION_CODENAME:-}")"
    fi

    case "$os_id" in
        ubuntu)
            base="ubuntu"
            codename="${os_version_codename:-$os_ubuntu_codename}"
            ;;
        debian)
            base="debian"
            codename="$os_version_codename"
            ;;
        *)
            if [ -n "$os_ubuntu_codename" ]; then
                # Mint, Pop!_OS, Zorin, elementary, KDE neon...
                base="ubuntu"
                codename="$os_ubuntu_codename"
            else
                case " $os_id_like " in
                    *" ubuntu "*)
                        base="ubuntu"
                        codename="$os_version_codename"
                        ;;
                    *" debian "*)
                        base="debian"
                        codename=""
                        ;;
                esac
            fi
            ;;
    esac

    if [ "$base" = "debian" ]; then
        local known=" bullseye bookworm trixie forky sid "
        case "$known" in
            *" $codename "*) ;;
            *) codename="" ;;
        esac

        # LMDE, MX, Kali, Debian testing : déduction via /etc/debian_version
        if [ -z "$codename" ] && [ -f /etc/debian_version ]; then
            local dv=""
            dv="$(cat /etc/debian_version 2>/dev/null || true)"
            case "$dv" in
                11*|bullseye*) codename="bullseye" ;;
                12*|bookworm*) codename="bookworm" ;;
                13*|trixie*)   codename="trixie" ;;
                14*|forky*)    codename="forky" ;;
                *sid*)         codename="sid" ;;
            esac
        fi
    fi

    if [ -n "$base" ] && [ -n "$codename" ]; then
        echo "$base $codename"
    fi

    return 0
}

setup_winehq_repo() {
    log_info "Configuration du dépôt WineHQ (Wine stable récent)..."

    local target base codename
    target="$(debian_winehq_target)"

    if [ -z "$target" ]; then
        log_warning "Impossible de déterminer le nom de code de la distribution."
        log_warning "Le dépôt WineHQ ne sera pas configuré ; Wine des dépôts standards sera utilisé."
        return 1
    fi

    base="${target%% *}"
    codename="${target##* }"
    log_info "Base : $base / nom de code : $codename"

    local sources_url="https://dl.winehq.org/wine-builds/${base}/dists/${codename}/winehq-${codename}.sources"

    if ! url_exists "$sources_url"; then
        log_warning "WineHQ ne propose pas (encore) de dépôt pour ${base} « ${codename} »."
        log_warning "Wine des dépôts standards sera utilisé."
        return 1
    fi

    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y wget gnupg ca-certificates >/dev/null 2>&1 || true
    sudo mkdir -p /etc/apt/keyrings

    # Ubuntu 26.04 / APT 3.2 : une clé ASCII doit s'appeler .asc, pas .key.
    local key_tmp="$TMP_DIR/winehq.key"
    if ! download_file "https://dl.winehq.org/wine-builds/winehq.key" "$key_tmp"; then
        log_warning "Impossible de télécharger la clé WineHQ (.asc)."
        return 1
    fi
    sudo install -m 0644 "$key_tmp" /etc/apt/keyrings/winehq-archive.asc

    # Copie déarmorée sous le nom historique, pour les fichiers .sources WineHQ.
    if check_command gpg && gpg --dearmor --yes -o "$TMP_DIR/winehq-archive.key" "$key_tmp" >/dev/null 2>&1; then
        sudo install -m 0644 "$TMP_DIR/winehq-archive.key" /etc/apt/keyrings/winehq-archive.key
    else
        sudo install -m 0644 "$key_tmp" /etc/apt/keyrings/winehq-archive.key
    fi

    local sources_tmp="$TMP_DIR/winehq-${codename}.sources"
    if ! download_file "$sources_url" "$sources_tmp"; then
        log_warning "Impossible de télécharger le fichier de dépôt WineHQ."
        return 1
    fi

    # Le fichier WineHQ référence winehq-archive.key : on pointe vers la clé
    # ASCII .asc, acceptée par toutes les versions d'APT (2.4 → 3.2).
    sed -i 's|/etc/apt/keyrings/winehq-archive.key|/etc/apt/keyrings/winehq-archive.asc|g' "$sources_tmp" 2>/dev/null || true

    # Nettoyage d'éventuels anciens dépôts WineHQ (autre nom de code)
    sudo rm -f /etc/apt/sources.list.d/winehq-*.sources /etc/apt/sources.list.d/winehq*.list 2>/dev/null || true
    sudo install -m 0644 "$sources_tmp" "/etc/apt/sources.list.d/winehq-${codename}.sources"

    sudo apt-get update || log_warning "apt-get update a signalé des erreurs (autres dépôts ?) : vérification de WineHQ..."

    if apt-cache policy winehq-stable 2>/dev/null | grep -qE 'Candidate: [0-9]'; then
        log_success "Dépôt WineHQ configuré pour ${base} ${codename}."
        return 0
    fi

    log_warning "winehq-stable n'est pas proposé par le dépôt : dépôt WineHQ retiré."
    sudo rm -f "/etc/apt/sources.list.d/winehq-${codename}.sources" 2>/dev/null || true
    sudo apt-get update >/dev/null 2>&1 || true
    return 1
}

install_debian_optional_packages() {
    if sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" >/dev/null 2>&1; then
        return 0
    fi

    # Un paquet manquant ne doit pas bloquer les autres
    local p
    for p in "$@"; do
        if dpkg -s "$p" >/dev/null 2>&1; then
            continue
        fi
        if ! sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$p" >/dev/null 2>&1; then
            log_warning "Paquet optionnel non installé : $p"
        fi
    done

    return 0
}

install_wine_debian() {
    require_privilege_helper
    log_info "Famille Debian/Ubuntu détectée : installation de Wine..."

    if ! dpkg --print-foreign-architectures 2>/dev/null | grep -qx i386; then
        log_info "Activation de l'architecture i386 (nécessaire aux applications 32 bits)..."
        sudo dpkg --add-architecture i386 || log_warning "Impossible d'activer l'architecture i386."
    fi

    local winehq_ok=0

    if setup_winehq_repo; then
        log_info "Installation de winehq-stable (WineHQ)..."
        if sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --install-recommends winehq-stable; then
            winehq_ok=1
            log_success "WineHQ stable installé."
        else
            log_warning "Échec de l'installation de winehq-stable : repli sur Wine des dépôts standards."
        fi
    fi

    if [ "$winehq_ok" -eq 0 ]; then
        sudo apt-get update >/dev/null 2>&1 || true
        log_info "Installation de Wine depuis les dépôts de la distribution..."
        if ! sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --install-recommends wine; then
            sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y wine64 || true
        fi

        # wine32 (préfixes 32 bits natifs) : facultatif
        if ! sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y wine32:i386 >/dev/null 2>&1; then
            if ! sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y wine32 >/dev/null 2>&1; then
                log_info "wine32 non installé (facultatif : le mode WoW64 sera utilisé pour le 32 bits si Wine le permet)."
            fi
        fi
    fi

    log_info "Installation des outils complémentaires (cabextract, icoutils, ImageMagick...)..."
    install_debian_optional_packages cabextract icoutils imagemagick desktop-file-utils wget xdg-utils librsvg2-bin file

    # winetricks : version autonome (le paquet apt dépend du « wine » Ubuntu,
    # ce qui casserait WineHQ). Géré ensuite par ensure_winetricks.
    return 0
}

# ==============================================================================
# Installation de Wine : famille Fedora / RHEL  (dnf)
# ==============================================================================
# Deux temps : wine (obligatoire, sortie visible) puis outils optionnels.
# Un paquet optionnel absent n'interrompt plus le script.
# ------------------------------------------------------------------------------

fedora_pkg_manager() {
    if check_command dnf; then
        echo "dnf"
    elif check_command yum; then
        echo "yum"
    else
        echo ""
    fi
}

fedora_is_dnf5() {
    dnf --version 2>/dev/null | head -n1 | grep -qE '^dnf5|^5\.' && return 0
    dnf --version 2>/dev/null | grep -qiE 'dnf5|^5\.' && return 0
    return 1
}

install_fedora_optional_packages() {
    local pm
    pm="$(fedora_pkg_manager)"
    [ -n "$pm" ] || return 0

    if [ "$pm" = "dnf" ] && fedora_is_dnf5; then
        if sudo dnf install -y --skip-unavailable "$@"; then
            return 0
        fi
    else
        if sudo "$pm" install -y --setopt=strict=0 "$@"; then
            return 0
        fi
    fi

    local p
    for p in "$@"; do
        if rpm -q "$p" >/dev/null 2>&1; then
            continue
        fi
        if ! sudo "$pm" install -y "$p" >/dev/null 2>&1; then
            log_warning "Paquet optionnel non installé : $p"
        fi
    done

    return 0
}

install_wine_fedora() {
    require_privilege_helper
    log_info "Famille Fedora/RHEL détectée : installation de Wine (dnf)..."

    local pm
    pm="$(fedora_pkg_manager)"
    if [ -z "$pm" ]; then
        log_error "Ni dnf ni yum n'est disponible."
        exit 1
    fi

    case "$DISTRO_ID" in
        rhel|centos|almalinux|rocky)
            log_info "Activation d'EPEL et du dépôt CRB (nécessaires à Wine sur RHEL et dérivées)..."
            sudo "$pm" install -y epel-release >/dev/null 2>&1 || true
            sudo "$pm" config-manager --set-enabled crb >/dev/null 2>&1 \
                || sudo "$pm" config-manager setopt crb.enabled=1 >/dev/null 2>&1 \
                || sudo crb enable >/dev/null 2>&1 \
                || true
            ;;
    esac

    log_info "Installation de wine (plusieurs minutes, ~1,5 Go téléchargés)..."
    if ! sudo "$pm" install -y wine; then
        log_error "Installation de wine impossible avec $pm."
        print_disk_hint_if_low
        exit 1
    fi
    log_success "Paquet wine installé."

    log_info "Installation des outils complémentaires (winetricks, cabextract, icoutils, ImageMagick...)..."
    install_fedora_optional_packages winetricks cabextract icoutils ImageMagick desktop-file-utils wget xdg-utils librsvg2-tools file

    return 0
}

# ==============================================================================
# Installation de Wine : famille Arch / CachyOS / Manjaro  (pacman)
# ==============================================================================

install_wine_arch() {
    require_privilege_helper
    log_info "Famille Arch détectée : installation de Wine (pacman)..."

    if ! grep -qE '^\[multilib\]' /etc/pacman.conf 2>/dev/null; then
        if grep -qE '^#\[multilib\]' /etc/pacman.conf 2>/dev/null; then
            log_info "Activation du dépôt multilib dans /etc/pacman.conf..."
            sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
        else
            log_info "Ajout du dépôt multilib à /etc/pacman.conf..."
            printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' | sudo tee -a /etc/pacman.conf >/dev/null
        fi
    fi

    sudo pacman -Sy --noconfirm || log_warning "Rafraîchissement des dépôts pacman incomplet."

    log_info "Installation de wine..."
    if ! sudo pacman -S --needed --noconfirm wine; then
        log_error "Installation de wine impossible avec pacman."
        exit 1
    fi
    log_success "Paquet wine installé."

    log_info "Installation des outils complémentaires..."
    local p
    for p in winetricks wine-mono wine-gecko cabextract icoutils imagemagick desktop-file-utils wget xdg-utils librsvg file; do
        if pacman -Qi "$p" >/dev/null 2>&1; then
            continue
        fi
        if ! sudo pacman -S --needed --noconfirm "$p" >/dev/null 2>&1; then
            log_warning "Paquet optionnel non installé : $p"
        fi
    done

    return 0
}

# ==============================================================================
# Installation de Wine : famille openSUSE  (zypper)
# ==============================================================================

install_wine_suse() {
    require_privilege_helper
    log_info "Famille openSUSE détectée : installation de Wine (zypper)..."

    sudo zypper --non-interactive --gpg-auto-import-keys refresh || log_warning "Rafraîchissement zypper incomplet."

    log_info "Installation de wine..."
    if ! sudo zypper --non-interactive install --auto-agree-with-licenses wine; then
        log_error "Installation de wine impossible avec zypper."
        exit 1
    fi
    log_success "Paquet wine installé."

    log_info "Installation des outils complémentaires (paquet par paquet)..."
    local p
    for p in wine-32bit winetricks cabextract icoutils ImageMagick desktop-file-utils wget xdg-utils rsvg-convert file; do
        if rpm -q "$p" >/dev/null 2>&1; then
            continue
        fi
        if ! zypper --non-interactive search --match-exact --type package "$p" >/dev/null 2>&1; then
            log_info "Paquet absent des dépôts (ignoré) : $p"
            continue
        fi
        if ! sudo zypper --non-interactive install --auto-agree-with-licenses "$p" >/dev/null 2>&1; then
            log_warning "Paquet optionnel non installé : $p"
        fi
    done

    return 0
}

# ==============================================================================
# Installation de Wine : NixOS / GLF OS  (relance dans nix-shell)
# ==============================================================================
# Pas de fetchTarball ni de liens WineHQ : nix-shell -p sur le nixpkgs système,
# repli wineWow64Packages.stable → wineWowPackages.stable → wine64 → wine,
# puis « nix shell nixpkgs#... » (flakes) si le canal est absent.
# Le choix « messages Wine » est transmis via PRONOTE_SHOW_WINE_LOGS.
# ------------------------------------------------------------------------------

install_wine_nixos() {
    log_info "NixOS / GLF OS détecté : préparation d'un environnement nix-shell avec Wine..."

    local script_path=""
    script_path="$(readlink -f "$0" 2>/dev/null || true)"

    if [ -z "$script_path" ] || [ ! -f "$script_path" ]; then
        log_error "Impossible de localiser le fichier du script (\$0 = $0)."
        echo "Enregistrez le script dans un fichier (ex. ~/pronote.sh) puis relancez : bash ~/pronote.sh"
        exit 1
    fi

    export PRONOTE_SHOW_WINE_LOGS="$SHOW_WINE_LOGS"

    local -a wine_candidates=(wineWow64Packages.stable wineWowPackages.stable wine64 wine)
    local -a tools=(winetricks cabextract icoutils imagemagick wget curl desktop-file-utils xdg-utils librsvg file)

    local run_cmd="" a
    printf -v run_cmd 'bash %q --in-nix-shell' "$script_path"
    for a in ${ALL_ARGS[@]+"${ALL_ARGS[@]}"}; do
        printf -v run_cmd '%s %q' "$run_cmd" "$a"
    done

    local cand

    if check_command nix-shell && nix-instantiate --eval -E 'with import <nixpkgs> {}; lib.version' >/dev/null 2>&1; then
        for cand in "${wine_candidates[@]}"; do
            if nix-instantiate --eval -E "with import <nixpkgs> {}; ($cand).name" >/dev/null 2>&1; then
                log_info "Paquet Wine retenu : $cand"
                log_info "Nix va télécharger Wine et les outils si nécessaire (plusieurs minutes possibles)..."
                exec nix-shell -p "$cand" "${tools[@]}" --run "$run_cmd"
            fi
        done
        log_warning "Aucun paquet Wine évaluable dans <nixpkgs>."
    else
        log_info "Canal <nixpkgs> indisponible : tentative via flakes (nix shell nixpkgs#...)."
    fi

    if check_command nix; then
        local -a flake_pkgs=()
        local t
        for cand in "${wine_candidates[@]}"; do
            if nix --extra-experimental-features 'nix-command flakes' eval --raw "nixpkgs#${cand}.name" >/dev/null 2>&1; then
                log_info "Paquet Wine retenu (flakes) : nixpkgs#$cand"
                flake_pkgs=("nixpkgs#$cand")
                for t in "${tools[@]}"; do
                    flake_pkgs+=("nixpkgs#$t")
                done
                exec nix --extra-experimental-features 'nix-command flakes' shell "${flake_pkgs[@]}" --command bash -c "$run_cmd"
            fi
        done
    fi

    log_error "Impossible de préparer Wine via Nix (ni nix-shell, ni flakes)."
    echo "Essai manuel possible :"
    echo "  nix-shell -p wineWow64Packages.stable winetricks cabextract icoutils imagemagick wget --run \"$run_cmd\""
    exit 1
}

# ==============================================================================
# Installation de Wine : Solus  (eopkg)
# ==============================================================================
# Solus construit désormais Wine 11 avec --enable-archs=x86_64,i386 :
# un seul paquet « wine » couvre le 32 et le 64 bits. Le paquet « wine-32bit »
# n'existe plus dans l'index (« Repo item wine-32bit not found »).
# Installation paquet par paquet : un paquet absent est simplement ignoré.
# ------------------------------------------------------------------------------

solus_pkg_available() {
    local pkg="$1"
    local out=""
    out="$(eopkg info "$pkg" 2>&1 || true)"

    if [ -z "$out" ]; then
        return 1
    fi
    if grep -qi "not found" <<< "$out"; then
        return 1
    fi
    return 0
}

install_wine_solus() {
    require_privilege_helper
    log_info "Solus détecté : installation de Wine (eopkg)..."
    log_info "Solus fournit un paquet « wine » unique en WoW64 intégré (32 + 64 bits) :"
    log_info "le paquet « wine-32bit » n'existe plus dans le dépôt et n'est plus nécessaire."

    local -a eopkg_opts=()
    if [ "$IS_LIVE_SESSION" = "1" ]; then
        # En Live, la mise à jour forcée de system.base remplirait la RAM.
        eopkg_opts+=(--ignore-safety)
        log_info "Session Live : --ignore-safety (pas de mise à jour forcée de system.base)."
    fi

    sudo eopkg update-repo >/dev/null 2>&1 || sudo eopkg ur >/dev/null 2>&1 || log_warning "Mise à jour de l'index eopkg impossible (on continue)."

    log_info "Installation de wine..."
    if ! sudo eopkg install -y ${eopkg_opts[@]+"${eopkg_opts[@]}"} wine; then
        log_error "Installation de wine impossible via eopkg."
        print_disk_hint_if_low
        exit 1
    fi
    log_success "Paquet wine installé."

    log_info "Installation des outils complémentaires (un par un, les paquets absents sont ignorés)..."
    local p
    for p in wine-32bit winetricks cabextract icoutils imagemagick desktop-file-utils wget xdg-utils librsvg file; do
        if ! solus_pkg_available "$p"; then
            log_info "Paquet absent du dépôt Solus (ignoré) : $p"
            continue
        fi
        if ! sudo eopkg install -y ${eopkg_opts[@]+"${eopkg_opts[@]}"} "$p" >/dev/null 2>&1; then
            log_warning "Paquet optionnel non installé : $p"
        fi
    done

    return 0
}

# ==============================================================================
# Installation de Wine : Alpine Linux  (apk, dépôt community)
# ==============================================================================

install_wine_alpine() {
    require_privilege_helper
    log_info "Alpine Linux détecté : installation de Wine (apk, dépôt community)..."

    if ! grep -qE '^[^#].*/community/?$' /etc/apk/repositories 2>/dev/null; then
        if grep -qE '^#.*/community/?$' /etc/apk/repositories 2>/dev/null; then
            log_info "Activation du dépôt community..."
            sudo sed -i 's|^#\(.*/community/\{0,1\}\)$|\1|' /etc/apk/repositories
        else
            local main_line="" community_line=""
            main_line="$(grep -E '^[^#].*/main/?$' /etc/apk/repositories 2>/dev/null | head -n1 || true)"
            if [ -n "$main_line" ]; then
                community_line="$(sed 's|/main/\{0,1\}$|/community|' <<< "$main_line")"
                log_info "Ajout du dépôt community : $community_line"
                echo "$community_line" | sudo tee -a /etc/apk/repositories >/dev/null
            fi
        fi
    fi

    sudo apk update || log_warning "apk update incomplet."

    log_info "Installation de wine..."
    if ! sudo apk add wine; then
        log_error "Installation de wine impossible via apk."
        exit 1
    fi
    log_success "Paquet wine installé."

    log_info "Installation des outils complémentaires..."
    local p
    for p in bash coreutils wget curl cabextract icoutils imagemagick desktop-file-utils xdg-utils librsvg file ttf-dejavu; do
        if apk info -e "$p" >/dev/null 2>&1; then
            continue
        fi
        if ! sudo apk add "$p" >/dev/null 2>&1; then
            log_warning "Paquet optionnel non installé : $p"
        fi
    done

    # winetricks n'est pas empaqueté : version autonome via ensure_winetricks
    return 0
}

# ==============================================================================
# Installation de Wine : Void Linux  (xbps)
# ==============================================================================

install_wine_void() {
    require_privilege_helper
    log_info "Void Linux détecté : installation de Wine (xbps)..."

    if ! xbps-query -l 2>/dev/null | grep -q ' void-repo-multilib-'; then
        log_info "Activation du dépôt multilib (void-repo-multilib)..."
        sudo xbps-install -Sy void-repo-multilib \
            || log_warning "Dépôt multilib indisponible (musl ou architecture non x86_64 ?) : Pronote 32 bits pourrait ne pas fonctionner."
    fi

    sudo xbps-install -S || log_warning "Synchronisation xbps incomplète."

    log_info "Installation de wine..."
    if ! sudo xbps-install -y wine; then
        log_error "Installation de wine impossible via xbps."
        exit 1
    fi
    log_success "Paquet wine installé."

    log_info "Installation des outils complémentaires..."
    local p
    for p in wine-32bit wine-mono wine-gecko winetricks cabextract icoutils ImageMagick desktop-file-utils wget xdg-utils librsvg-utils file; do
        if xbps-query "$p" >/dev/null 2>&1; then
            continue
        fi
        if ! sudo xbps-install -y "$p" >/dev/null 2>&1; then
            log_info "Paquet non installé (absent ou optionnel) : $p"
        fi
    done

    return 0
}

# ==============================================================================
# Installation de Wine : Slackware (expérimental) et distribution inconnue
# ==============================================================================

install_wine_slackware() {
    log_warning "Slackware : support expérimental. Wine n'est pas dans les dépôts officiels."

    if wine_is_available; then
        log_success "Wine déjà présent : $WINE_BIN"
        return 0
    fi

    log_error "Wine introuvable. Installez-le (paquets d'Alien Bob ou SlackBuilds.org : wine, winetricks, cabextract, icoutils) puis relancez."
    exit 1
}

install_wine_unknown() {
    log_warning "Distribution non reconnue ($DISTRO_ID) : le script ne peut pas installer Wine automatiquement."

    if wine_is_available; then
        log_success "Wine déjà présent : $WINE_BIN — on continue."
        return 0
    fi

    log_error "Wine est introuvable. Installez Wine (≥ $MIN_WINE_VERSION), winetricks, cabextract, icoutils et ImageMagick, puis relancez."
    exit 1
}

# ==============================================================================
# Vérifications après installation des paquets
# ==============================================================================

verify_wine_installation() {
    if ! wine_is_available; then
        log_error "Wine est introuvable après l'installation des paquets."
        print_wine_diagnostics
        exit 1
    fi

    local v
    v="$(get_wine_version)"
    log_success "Wine détecté : $WINE_BIN (version $v)"

    if version_lt "$v" "$MIN_WINE_VERSION"; then
        log_warning "Wine $v est plus ancien que la version minimale recommandée ($MIN_WINE_VERSION)."
        log_warning "Pronote peut fonctionner, mais une mise à jour de Wine est conseillée."
    fi

    return 0
}

verify_optional_tools() {
    local -a missing=()

    if ! check_command cabextract; then
        missing+=("cabextract (polices Microsoft via winetricks)")
    fi
    if ! check_command wrestool && ! check_command icotool; then
        missing+=("icoutils (extraction de l'icône depuis Pronote)")
    fi
    if ! check_command magick && ! check_command convert && ! check_command rsvg-convert; then
        missing+=("ImageMagick ou rsvg-convert (génération des icônes PNG)")
    fi
    if ! check_command update-desktop-database; then
        missing+=("desktop-file-utils (rafraîchissement du menu)")
    fi

    if [ "${#missing[@]}" -gt 0 ]; then
        log_warning "Outils facultatifs absents :"
        local m
        for m in "${missing[@]}"; do
            echo "  • $m"
        done
        echo "L'installation continue ; seuls des détails cosmétiques peuvent être affectés."
    fi

    return 0
}

# ==============================================================================
# Dépendances : point d'entrée par famille de distribution
# ==============================================================================

ensure_dependencies() {
    echo ""
    box_title "Verification des dependances" 46
    echo ""

    detect_live_session
    check_disk_space_before_wine

    case "$DISTRO_FAMILY" in
        debian)     install_wine_debian ;;
        fedora)     install_wine_fedora ;;
        arch)       install_wine_arch ;;
        suse)       install_wine_suse ;;
        nixos)      install_wine_nixos ;;          # relance le script (exec)
        nixos-done) log_info "Environnement nix-shell actif : utilisation du Wine fourni par Nix." ;;
        solus)      install_wine_solus ;;
        alpine)     install_wine_alpine ;;
        void)       install_wine_void ;;
        slackware)  install_wine_slackware ;;
        *)          install_wine_unknown ;;
    esac

    verify_wine_installation
    ensure_winetricks
    verify_optional_tools

    return 0
}

# ==============================================================================
# Configuration de Wine : préfixe, version Windows, composants
# ==============================================================================

wine_prefix_init() {
    local st=0

    if [ -n "${WINEBOOT_BIN:-}" ] && [ -x "$WINEBOOT_BIN" ]; then
        run_with_timeout 1500 "$WINEBOOT_BIN" --init || st=$?
    else
        run_with_timeout 1500 "$WINE_BIN" wineboot --init || st=$?
    fi

    return "$st"
}

winecfg_set_version() {
    local st=0

    if [ -n "${WINECFG_BIN:-}" ] && [ -x "$WINECFG_BIN" ]; then
        run_with_timeout 300 "$WINECFG_BIN" /v "$WIN_VERSION" || st=$?
    else
        run_with_timeout 300 "$WINE_BIN" winecfg /v "$WIN_VERSION" || st=$?
    fi

    if status_is_timeout "$st"; then
        run_wineserver_tool -k >/dev/null 2>&1 || true
    fi

    return "$st"
}

# Version Windows écrite dans les deux vues du registre (32 et 64 bits) via
# un unique import regedit borné dans le temps (fin du blocage NixOS 32 bits).
force_windows_version_registry() {
    local product build
    product="$(win_version_product_name)"
    build="$(win_version_build)"

    log_info "Forçage de la version Windows ($product) dans les deux vues de registre (32/64 bits)..."

    local reg_dir="$WINEPREFIX/drive_c/windows/temp"
    mkdir -p "$reg_dir" 2>/dev/null || true
    local reg_file="$reg_dir/pronote-winver.reg"
    local reg_win_path='C:\windows\temp\pronote-winver.reg'

    {
        printf 'Windows Registry Editor Version 5.00\r\n\r\n'
        local key
        for key in \
            'HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion' \
            'HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows NT\CurrentVersion'
        do
            printf '[%s]\r\n' "$key"
            printf '"CurrentVersion"="6.3"\r\n'
            printf '"CurrentMajorVersionNumber"=dword:0000000a\r\n'
            printf '"CurrentMinorVersionNumber"=dword:00000000\r\n'
            printf '"CurrentBuild"="%s"\r\n' "$build"
            printf '"CurrentBuildNumber"="%s"\r\n' "$build"
            printf '"ProductName"="%s"\r\n' "$product"
            printf '"CSDVersion"=""\r\n'
            printf '\r\n'
        done
        printf '[HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\ProductOptions]\r\n'
        printf '"ProductType"="WinNT"\r\n\r\n'
        printf '[HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Windows]\r\n'
        printf '"CSDVersion"=dword:00000000\r\n\r\n'
    } > "$reg_file" 2>/dev/null || {
        log_warning "Impossible d'écrire le fichier de registre (disque plein ?) : forçage ignoré."
        print_disk_hint_if_low
        return 0
    }

    local st=0
    set +e
    if [ "$SHOW_WINE_LOGS" = "1" ]; then
        run_with_timeout 180 "$WINE_BIN" regedit /S "$reg_win_path"
        st=$?
    else
        (
            export WINEDEBUG="-all"
            run_with_timeout 180 "$WINE_BIN" regedit /S "$reg_win_path"
        ) >>"$LOG_FILE" 2>&1
        st=$?
    fi
    set -e

    if status_is_timeout "$st"; then
        log_warning "regedit n'a pas répondu dans le délai imparti : arrêt du wineserver et poursuite."
        log_warning "(la version Windows a déjà été définie par winecfg ; ce forçage est une sécurité)"
        run_wineserver_tool -k >/dev/null 2>&1 || true
        sleep 1
    elif [ "$st" -ne 0 ]; then
        log_warning "Forçage du registre terminé avec le code $st (non bloquant)."
    fi

    rm -f "$reg_file" 2>/dev/null || true
    wait_wineserver_idle 60
    return 0
}

winetricks_verb() {
    local st=0
    run_with_timeout 1200 winetricks -q "$@" || st=$?

    if status_is_timeout "$st"; then
        run_wineserver_tool -k >/dev/null 2>&1 || true
    fi

    return "$st"
}

install_windows_components() {
    log_info "Installation des composants Windows utiles à Pronote."

    if ! check_command winetricks; then
        log_warning "winetricks indisponible : composants optionnels (polices, windowscodecs) ignorés."
        return 0
    fi

    export WINETRICKS_LATEST_VERSION_CHECK=disabled

    RUN_QUIET_ACTIVITY_DIR="$WINEPREFIX/drive_c"
    RUN_QUIET_FINALIZE_MSG="Composants : finalisation en cours, veuillez patienter quelques secondes..."

    if ! run_quiet "Installation des polices Microsoft" winetricks_verb corefonts; then
        log_warning "Installation partielle ou impossible de corefonts. Ce n'est pas forcément bloquant."
    fi

    if ! run_quiet "Installation de windowscodecs" winetricks_verb windowscodecs; then
        log_warning "windowscodecs non installé ou partiellement installé. Ce n'est pas forcément bloquant."
    fi

    RUN_QUIET_ACTIVITY_DIR=""
    RUN_QUIET_FINALIZE_MSG=""

    wait_wineserver_idle 120
    return 0
}

check_prefix_sanity() {
    if [ ! -f "$WINEPREFIX/system.reg" ] || [ ! -d "$WINEPREFIX/drive_c/windows/system32" ]; then
        log_error "Le préfixe Wine est incomplet : $WINEPREFIX"
        echo "system.reg ou drive_c/windows/system32 manquant : l'initialisation a échoué."
        print_disk_hint_if_low
        print_wine_diagnostics
        exit 1
    fi

    local mb
    mb="$(free_mb_at "$WINEPREFIX")"
    if [ -n "$mb" ] && [ "$mb" -lt 300 ] && [ "${PRONOTE_IGNORE_DISK:-0}" != "1" ]; then
        log_error "Espace disque presque épuisé après la création du préfixe ($(fmt_mb "$mb") libres)."
        print_disk_hint_if_low
        exit 1
    fi

    return 0
}

configure_wine() {
    echo ""
    box_title "Configuration de Wine" 46
    echo ""

    discover_wine_paths
    if [ -z "$WINE_BIN" ]; then
        log_error "Wine introuvable au moment de la configuration."
        print_wine_diagnostics
        exit 1
    fi

    log_info "Wine utilisé : $WINE_BIN (version $(get_wine_version))"

    # --- Mode du préfixe selon l'architecture demandée -----------------------
    PREFIX_MODE="win64"
    if [ "$PRONOTE_ARCH" = "32" ]; then
        if probe_win32_prefix_support; then
            PREFIX_MODE="win32"
        else
            PREFIX_MODE="wow64"
        fi
    fi

    # --- Préfixe existant ? ---------------------------------------------------
    if [ -f "$WINEPREFIX/system.reg" ]; then
        local existing_arch
        existing_arch="$(detect_prefix_arch)"
        log_info "Préfixe Wine existant détecté : $WINEPREFIX (architecture $existing_arch bits)"

        if [ "$PRONOTE_ARCH" = "64" ] && [ "$existing_arch" = "32" ]; then
            log_error "Ce préfixe est 32 bits : impossible d'y installer Pronote 64 bits."
            echo "Relancez avec un autre préfixe, par exemple :"
            echo "  WINEPREFIX=\"$HOME/.local/share/wineprefixes/pronote-${PRONOTE_YEAR}-64\" bash $0"
            exit 1
        fi

        if [ "$PRONOTE_ARCH" = "32" ]; then
            if [ "$existing_arch" = "32" ]; then
                PREFIX_MODE="win32"
            else
                PREFIX_MODE="wow64"
            fi
        fi

        local reuse
        reuse="$(ask_user "Réutiliser ce préfixe existant ? [O/n] : " "O")"
        case "$reuse" in
            n|N|non|Non|NON)
                local backup="${WINEPREFIX}.ancien-$(date +%Y%m%d-%H%M%S)"
                (
                    export WINEPREFIX
                    run_wineserver_tool -k >/dev/null 2>&1
                ) || true
                mv "$WINEPREFIX" "$backup"
                log_info "Ancien préfixe déplacé vers : $backup"
                if [ "$PRONOTE_ARCH" = "32" ]; then
                    if probe_win32_prefix_support; then PREFIX_MODE="win32"; else PREFIX_MODE="wow64"; fi
                fi
                ;;
            *)
                log_info "Le préfixe existant sera réutilisé."
                ;;
        esac
    fi

    case "$PREFIX_MODE" in
        win32) export WINEARCH="win32" ;;
        *)     export WINEARCH="win64" ;;
    esac

    # --- Création si nécessaire ----------------------------------------------
    if [ ! -f "$WINEPREFIX/system.reg" ]; then
        log_info "Création d'un nouveau préfixe Wine : $WINEPREFIX"
        case "$PREFIX_MODE" in
            win32) log_info "Architecture du nouveau préfixe : 32 bits (natif, WINEARCH=win32)" ;;
            wow64) log_info "Architecture du nouveau préfixe : 64 bits WoW64 (Pronote 32 bits y sera installé)" ;;
            *)     log_info "Architecture du nouveau préfixe : 64 bits" ;;
        esac
        mkdir -p "$WINEPREFIX"
        check_disk_space_before_pronote
    fi

    RUN_QUIET_ACTIVITY_DIR="$WINEPREFIX"
    RUN_QUIET_FINALIZE_MSG="Initialisation : finalisation en cours, veuillez patienter quelques secondes..."

    if ! run_quiet "Initialisation du préfixe Wine" wine_prefix_init; then
        log_error "Échec de l'initialisation du préfixe Wine."
        print_disk_hint_if_low
        print_wine_diagnostics
        exit 1
    fi

    RUN_QUIET_ACTIVITY_DIR=""
    RUN_QUIET_FINALIZE_MSG=""

    wait_wineserver_idle 120
    check_prefix_sanity

    # --- Version Windows ------------------------------------------------------
    log_info "Configuration de la version Windows vue par Wine : $(win_version_label)"
    if ! run_quiet "Configuration Windows" winecfg_set_version; then
        log_warning "winecfg /v $WIN_VERSION a échoué (non bloquant, le registre sera forcé)."
    fi

    force_windows_version_registry

    # --- Composants Windows ---------------------------------------------------
    install_windows_components

    # winetricks peut modifier la version Windows : on la force à nouveau.
    force_windows_version_registry

    log_success "Préfixe Wine prêt : $WINEPREFIX"
    return 0
}

# ==============================================================================
# Installation de Pronote
# ==============================================================================

download_pronote_installer() {
    local dest="$1"
    local -a candidates=("$PRONOTE_URL")

    local default_url="https://tele3.index-education.com/telechargement/pn/v${DEFAULT_YEAR}.0/exe/Install_PRNclient_FR_${DEFAULT_VERSION}_win${PRONOTE_ARCH}.exe"
    if [ "$default_url" != "$PRONOTE_URL" ]; then
        candidates+=("$default_url")
    fi

    local url size
    for url in "${candidates[@]}"; do
        log_info "Tentative de téléchargement : $url"
        rm -f "$dest" 2>/dev/null || true

        if download_file "$url" "$dest" 1; then
            size="$(wc -c < "$dest" 2>/dev/null || echo 0)"
            if [ "$size" -gt 20000000 ] && head -c 2 "$dest" 2>/dev/null | grep -q 'MZ'; then
                log_success "Téléchargement réussi depuis : $url"
                PRONOTE_URL="$url"
                return 0
            fi
            log_warning "Fichier téléchargé invalide ou incomplet ($size octets)."
            print_disk_hint_if_low
        else
            log_warning "Échec du téléchargement depuis cette adresse."
        fi
    done

    return 1
}

# winemenubuilder est désactivé pendant l'installateur : Wine ne crée ainsi
# pas d'entrées de menu « Client PRONOTE » en doublon (dossier Wine des menus
# MATE/XFCE), le script fournit ses propres raccourcis.
run_pronote_installer() {
    local installer="$1"
    local st=0

    (
        export WINEDLLOVERRIDES="winemenubuilder.exe=d${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
        "$WINE_BIN" "$installer"
    ) || st=$?

    return "$st"
}

cleanup_wine_menu_entries() {
    # Entrées créées par winemenubuilder (Wine) : doublons du lanceur Pronote
    if [ -d "$APP_DIR/wine" ]; then
        find "$APP_DIR/wine" \( -iname "*PRONOTE*" -o -iname "*Index Education*" \) -prune -exec rm -rf {} + 2>/dev/null || true
    fi

    if [ -d "$MENU_MERGE_DIR" ]; then
        find "$MENU_MERGE_DIR" -maxdepth 1 -type f -name "wine-Programs-*" \
            \( -iname "*PRONOTE*" -o -iname "*Index Education*" \) -delete 2>/dev/null || true
    fi

    if [ -d "$HOME/.local/share/desktop-directories" ]; then
        find "$HOME/.local/share/desktop-directories" -maxdepth 1 -type f -name "wine-Programs-*" \
            \( -iname "*PRONOTE*" -o -iname "*Index Education*" \) -delete 2>/dev/null || true
    fi

    return 0
}

install_pronote() {
    echo ""
    box_title "Installation de Pronote Client" 46
    echo ""

    check_disk_space_before_pronote

    local installer="$TMP_DIR/InstallPronote-${PRONOTE_YEAR}-${PRONOTE_ARCH}.exe"

    log_info "Téléchargement de l'installateur Pronote ${PRONOTE_ARCH} bits..."
    echo "URL cible : $PRONOTE_URL"
    echo ""

    if ! download_pronote_installer "$installer"; then
        log_error "Téléchargement de l'installateur Pronote impossible."
        echo "Vérifiez la connexion Internet, ou fournissez une URL avec --url."
        exit 1
    fi

    echo ""
    log_warning "Une fenêtre d'installation Windows va s'ouvrir."
    echo ""
    echo "Conseils pendant l'installation :"
    echo "  • Décochez si possible : « Créer un raccourci sur le bureau »."
    echo "  • Décochez si possible : « Lancer Pronote après installation »."
    echo "  • Laissez l'installation se terminer normalement."
    echo ""
    echo "Remarque : une fois l'assistant fermé, l'installation peut encore"
    echo "travailler quelques secondes en arrière-plan (enregistrement de"
    echo "services). Le message affiché vous préviendra automatiquement."
    echo ""

    if [ "$ASSUME_YES" != "1" ]; then
        read -rp "Appuyez sur Entrée pour lancer l'installateur..." _
    fi

    RUN_QUIET_ACTIVITY_DIR="$WINEPREFIX/drive_c"
    RUN_QUIET_FINALIZE_MSG="Installation Pronote : finalisation en arrière-plan (services), veuillez patienter..."

    if ! run_quiet "Installation Pronote en cours" run_pronote_installer "$installer"; then
        log_warning "L'installateur Pronote s'est terminé avec un code d'erreur : vérification de l'installation..."
    fi

    RUN_QUIET_ACTIVITY_DIR=""
    RUN_QUIET_FINALIZE_MSG=""

    wait_wineserver_idle 300

    local exe
    exe="$(find_pronote_exe)"

    if [ -z "$exe" ]; then
        log_error "Pronote ne semble pas installé : exécutable introuvable dans $WINEPREFIX/drive_c."
        echo "Causes fréquentes : assistant annulé, espace disque insuffisant, préfixe Wine incomplet."
        print_disk_hint_if_low
        print_wine_diagnostics
        exit 1
    fi

    log_success "Pronote installé : $exe"
    cleanup_wine_menu_entries
    return 0
}

# ==============================================================================
# Icônes : téléchargement, conversion, extraction, secours
# ==============================================================================

is_image_file() {
    local f="$1"
    [ -s "$f" ] || return 1

    local mime=""
    if check_command file; then
        mime="$(file -b --mime-type "$f" 2>/dev/null || true)"
        case "$mime" in
            image/*)
                return 0
                ;;
            text/html|application/json)
                return 1
                ;;
        esac
    fi

    # Repli : signatures binaires
    local magic=""
    magic="$(head -c 8 "$f" 2>/dev/null | od -An -tx1 2>/dev/null | tr -d ' \n' || true)"
    case "$magic" in
        ffd8ff*)               return 0 ;;   # JPEG
        89504e47*)             return 0 ;;   # PNG
        47494638*)             return 0 ;;   # GIF
        52494646*)             return 0 ;;   # WEBP (RIFF)
        00000100*)             return 0 ;;   # ICO
        3c3f786d6c*|3c737667*) return 0 ;;   # <?xml / <svg
    esac

    if grep -qi "<svg" "$f" 2>/dev/null; then
        return 0
    fi

    return 1
}

# ImageMagick 7 (magick) ou 6 (convert)
image_magick_cmd() {
    if check_command magick; then
        echo "magick"
    elif check_command convert; then
        echo "convert"
    else
        echo ""
    fi
}

im_identify_largest_index() {
    local src="$1"
    local im
    im="$(image_magick_cmd)"
    [ -n "$im" ] || { echo "0"; return 0; }

    local idx=""
    if [ "$im" = "magick" ]; then
        idx="$(magick identify -format "%p %w\n" "$src" 2>/dev/null | sort -k2 -n | tail -n1 | awk '{print $1}' || true)"
    else
        idx="$(identify -format "%p %w\n" "$src" 2>/dev/null | sort -k2 -n | tail -n1 | awk '{print $1}' || true)"
    fi

    case "$idx" in
        ''|*[!0-9]*) echo "0" ;;
        *)           echo "$idx" ;;
    esac
}

rasterize_svg_to_pngs() {
    local svg="$1"
    local name="$2"
    local size ok=0 out_dir im
    im="$(image_magick_cmd)"

    for size in "${ICON_SIZES[@]}"; do
        out_dir="$ICON_BASE_DIR/${size}x${size}/apps"
        mkdir -p "$out_dir"

        if check_command rsvg-convert; then
            if rsvg-convert -w "$size" -h "$size" "$svg" -o "$out_dir/${name}.png" >/dev/null 2>&1 && [ -s "$out_dir/${name}.png" ]; then
                ok=1
                continue
            fi
        fi

        if [ -n "$im" ]; then
            if "$im" -background none -density 384 "$svg" -resize "${size}x${size}" -gravity center -extent "${size}x${size}" "PNG32:$out_dir/${name}.png" >/dev/null 2>&1 && [ -s "$out_dir/${name}.png" ]; then
                ok=1
            else
                rm -f "$out_dir/${name}.png" 2>/dev/null || true
            fi
        fi
    done

    [ "$ok" -eq 1 ]
}

convert_image_to_pngs() {
    local src="$1"
    local name="$2"
    local size ok=0 out_dir

    if grep -qi "<svg" "$src" 2>/dev/null; then
        rasterize_svg_to_pngs "$src" "$name" && return 0
        return 1
    fi

    local im
    im="$(image_magick_cmd)"
    [ -n "$im" ] || return 1

    for size in "${ICON_SIZES[@]}"; do
        out_dir="$ICON_BASE_DIR/${size}x${size}/apps"
        mkdir -p "$out_dir"

        if "$im" "${src}[0]" -alpha set -background none -resize "${size}x${size}" -gravity center -extent "${size}x${size}" "PNG32:$out_dir/${name}.png" >/dev/null 2>&1 && [ -s "$out_dir/${name}.png" ]; then
            ok=1
        else
            rm -f "$out_dir/${name}.png" 2>/dev/null || true
        fi
    done

    [ "$ok" -eq 1 ] && [ -s "$ICON_BASE_DIR/256x256/apps/${name}.png" ]
}

extract_icon_from_exe() {
    local exe="$1"
    local name="$2"

    [ -f "$exe" ] || return 1
    check_command wrestool || return 1

    local work="$TMP_DIR/exe-icon"
    rm -rf "$work"
    mkdir -p "$work/png"

    wrestool -x -t 14 -o "$work" "$exe" >/dev/null 2>&1 || true

    local best_ico=""
    best_ico="$(ls -S "$work"/*.ico 2>/dev/null | head -n1 || true)"
    if [ -z "$best_ico" ] || [ ! -s "$best_ico" ]; then
        return 1
    fi

    local best_png=""
    if check_command icotool; then
        icotool -x -o "$work/png" "$best_ico" >/dev/null 2>&1 || true
        best_png="$(ls -S "$work"/png/*.png 2>/dev/null | head -n1 || true)"
    fi

    if [ -n "$best_png" ] && [ -s "$best_png" ]; then
        if convert_image_to_pngs "$best_png" "$name"; then
            return 0
        fi
        # Sans ImageMagick : copie brute du plus grand PNG extrait
        local out_dir="$ICON_BASE_DIR/256x256/apps"
        mkdir -p "$out_dir"
        cp -f "$best_png" "$out_dir/${name}.png" 2>/dev/null && return 0
    fi

    local im
    im="$(image_magick_cmd)"
    if [ -n "$im" ]; then
        local idx tmp_png="$work/best.png"
        idx="$(im_identify_largest_index "$best_ico")"
        if "$im" "${best_ico}[${idx}]" "PNG32:$tmp_png" >/dev/null 2>&1 && [ -s "$tmp_png" ]; then
            convert_image_to_pngs "$tmp_png" "$name" && return 0
        fi
    fi

    return 1
}

# Icône de secours : papillon stylisé, sans texte (rendu identique partout,
# plus de lettre aléatoire due à une police absente).
write_fallback_svg() {
    local target="$1"
    mkdir -p "$(dirname "$target")"

    cat > "$target" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#1e8f5a"/>
      <stop offset="1" stop-color="#0d5f3b"/>
    </linearGradient>
  </defs>
  <rect x="8" y="8" width="240" height="240" rx="52" fill="url(#bg)"/>
  <g fill="#ffffff" fill-opacity="0.96">
    <path d="M128 78 C 96 40, 40 44, 42 92 C 44 128, 92 136, 122 122 Z"/>
    <path d="M128 78 C 160 40, 216 44, 214 92 C 212 128, 164 136, 134 122 Z"/>
    <path d="M124 132 C 92 128, 52 150, 62 188 C 70 216, 110 208, 124 176 Z"/>
    <path d="M132 132 C 164 128, 204 150, 194 188 C 186 216, 146 208, 132 176 Z"/>
  </g>
  <rect x="122" y="70" width="12" height="118" rx="6" fill="#0a3f28"/>
  <circle cx="128" cy="66" r="10" fill="#0a3f28"/>
  <path d="M120 60 C 108 48, 104 38, 106 30" stroke="#0a3f28" stroke-width="5" fill="none" stroke-linecap="round"/>
  <path d="M136 60 C 148 48, 152 38, 150 30" stroke="#0a3f28" stroke-width="5" fill="none" stroke-linecap="round"/>
</svg>
EOF
}

install_pixmap_and_xdg_icon() {
    local name="$1"
    mkdir -p "$PIXMAP_DIR"

    local src="" size f
    for size in 256 128 64 48; do
        if [ -s "$ICON_BASE_DIR/${size}x${size}/apps/${name}.png" ]; then
            src="$ICON_BASE_DIR/${size}x${size}/apps/${name}.png"
            break
        fi
    done

    if [ -n "$src" ]; then
        cp -f "$src" "$PIXMAP_DIR/${name}.png" 2>/dev/null || true
    fi

    if check_command xdg-icon-resource; then
        for size in "${ICON_SIZES[@]}"; do
            f="$ICON_BASE_DIR/${size}x${size}/apps/${name}.png"
            [ -s "$f" ] || continue
            xdg-icon-resource install --noupdate --novendor --size "$size" "$f" "$name" >/dev/null 2>&1 || true
        done
    fi

    return 0
}

refresh_icon_caches() {
    if check_command gtk-update-icon-cache; then
        gtk-update-icon-cache -f -t "$ICON_BASE_DIR" >/dev/null 2>&1 || true
    fi
    if check_command xdg-icon-resource; then
        xdg-icon-resource forceupdate >/dev/null 2>&1 || true
    fi
    if check_command update-desktop-database; then
        update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
    fi

    rm -f "$HOME/.cache/icon-cache.kcache" 2>/dev/null || true
    if check_command kbuildsycoca6; then
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    fi
    if check_command kbuildsycoca5; then
        kbuildsycoca5 --noincremental >/dev/null 2>&1 || true
    fi

    touch "$ICON_BASE_DIR" "$APP_DIR" 2>/dev/null || true
    return 0
}

resolve_icon_path() {
    local name="$1"
    local size f

    for size in 256 128 64 48 32; do
        f="$ICON_BASE_DIR/${size}x${size}/apps/${name}.png"
        if [ -s "$f" ]; then
            echo "$f"
            return 0
        fi
    done

    if [ -s "$PIXMAP_DIR/${name}.png" ]; then
        echo "$PIXMAP_DIR/${name}.png"
        return 0
    fi

    if [ -s "$ICON_DIR/${name}.svg" ]; then
        echo "$ICON_DIR/${name}.svg"
        return 0
    fi

    echo "$name"
}

fetch_and_install_icon() {
    local exe_path="$1"
    local icon_name="pronote-${PRONOTE_YEAR}"
    local svg_target="$ICON_DIR/${icon_name}.svg"
    local img_tmp="$TMP_DIR/pronote-icon-source"
    local got_raster=0

    mkdir -p "$ICON_DIR" "$PIXMAP_DIR"

    log_info "Téléchargement de l'icône Pronote par défaut..."

    local url
    for url in "${PRONOTE_ICON_URLS[@]}"; do
        rm -f "$img_tmp" 2>/dev/null || true

        if download_file "$url" "$img_tmp" && is_image_file "$img_tmp"; then
            if convert_image_to_pngs "$img_tmp" "$icon_name"; then
                got_raster=1
                log_success "Icône PNG installée depuis l'image par défaut."
                break
            fi
            log_warning "Image téléchargée mais conversion en PNG impossible."
            if [ -z "$(image_magick_cmd)" ] && ! check_command rsvg-convert; then
                break
            fi
        fi
    done

    if [ "$got_raster" -eq 0 ]; then
        log_warning "Icône par défaut indisponible, invalide ou non convertible."
        log_info "Tentative d'extraction de l'icône embarquée dans le programme..."
        if extract_icon_from_exe "$exe_path" "$icon_name"; then
            got_raster=1
            log_success "Icône extraite directement du programme Pronote."
        else
            log_warning "Extraction depuis l'exécutable impossible (icoutils ou ImageMagick absents ?)."
        fi
    fi

    if [ "$got_raster" -eq 0 ]; then
        log_warning "Aucune icône récupérée : création d'une icône de secours (SVG sans texte)."
        write_fallback_svg "$svg_target"
        rasterize_svg_to_pngs "$svg_target" "$icon_name" || true
    else
        # Ne pas laisser une ancienne icône de secours vectorielle prendre le
        # dessus sur les PNG dans certains thèmes.
        rm -f "$svg_target" 2>/dev/null || true
    fi

    install_pixmap_and_xdg_icon "$icon_name"
    refresh_icon_caches

    echo "$icon_name"
}

find_pronote_exe() {
    local -a files=()
    local f

    while IFS= read -r -d '' f; do
        if [[ "$f" == *"$PRONOTE_YEAR"* ]]; then
            files+=("$f")
        fi
    done < <(find "$WINEPREFIX/drive_c" -type f -iname "Client PRONOTE*.exe" -print0 2>/dev/null || true)

    if [ "${#files[@]}" -eq 0 ]; then
        while IFS= read -r -d '' f; do
            files+=("$f")
        done < <(find "$WINEPREFIX/drive_c" -type f -iname "Client PRONOTE*.exe" -print0 2>/dev/null || true)
    fi

    if [ "${#files[@]}" -eq 0 ]; then
        while IFS= read -r -d '' f; do
            case "$f" in
                *[Uu]nins*|*[Ii]nstall*) ;;
                *) files+=("$f") ;;
            esac
        done < <(find "$WINEPREFIX/drive_c" -type f -ipath "*Index Education*" -iname "*PRONOTE*.exe" -print0 2>/dev/null || true)
    fi

    echo "${files[0]:-}"
}

# ==============================================================================
# Ajout de ~/.local/bin au PATH
# ==============================================================================

ensure_path_in_shell_rc() {
    local shell_name
    shell_name="$(basename "${SHELL:-/bin/bash}")"

    local rc_file=""
    local path_line=""

    case "$shell_name" in
        zsh)
            rc_file="$HOME/.zshrc"
            path_line="export PATH=\"$BIN_DIR:\$PATH\""
            ;;
        fish)
            rc_file="$HOME/.config/fish/config.fish"
            path_line="set -gx PATH \$PATH $BIN_DIR"
            ;;
        *)
            rc_file="$HOME/.bashrc"
            path_line="export PATH=\"$BIN_DIR:\$PATH\""
            ;;
    esac

    local files_to_patch=("$rc_file")
    if [ "$shell_name" != "fish" ]; then
        files_to_patch+=("$HOME/.profile")
    fi

    local f
    for f in "${files_to_patch[@]}"; do
        if [ -f "$f" ] && grep -qF "$BIN_DIR" "$f" 2>/dev/null; then
            log_info "Le dossier '$BIN_DIR' est déjà configuré dans $f."
            continue
        fi

        mkdir -p "$(dirname "$f")"
        touch "$f"
        {
            echo ""
            echo "# >>> Ajouté par le script d'installation Pronote >>>"
            echo "# Commandes : pronote-${PRONOTE_YEAR}, pronote-desinstaller-32, pronote-desinstaller-64"
            echo "$path_line"
            echo "# <<< Fin ajout Pronote <<<"
        } >> "$f"

        log_success "Le dossier '$BIN_DIR' a été ajouté au PATH dans $f."
    done

    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) export PATH="$BIN_DIR:$PATH" ;;
    esac

    hash -r 2>/dev/null || true
}

# ==============================================================================
# Raccourci bureau universel
# ==============================================================================

create_desktop_shortcut() {
    local desktop_file_source="$1"
    local -a desktop_dirs=()
    local d

    if check_command xdg-user-dir; then
        d="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
        # xdg-user-dir renvoie $HOME quand aucun dossier Bureau n'est configuré
        if [ -n "$d" ] && [ -d "$d" ] && [ "$d" != "$HOME" ]; then
            desktop_dirs+=("$d")
        fi
    fi

    for d in "$HOME/Bureau" "$HOME/Desktop"; do
        [ -d "$d" ] || continue
        local already=0
        local existing
        for existing in ${desktop_dirs[@]+"${desktop_dirs[@]}"}; do
            [ "$existing" = "$d" ] && already=1
        done
        [ "$already" -eq 0 ] && desktop_dirs+=("$d")
    done

    if [ "${#desktop_dirs[@]}" -eq 0 ]; then
        log_info "Aucun dossier Bureau/Desktop détecté : raccourci bureau non créé."
        return 0
    fi

    local target
    for d in "${desktop_dirs[@]}"; do
        target="$d/pronote-${PRONOTE_YEAR}-${PRONOTE_ARCH}.desktop"
        cp -f "$desktop_file_source" "$target"
        chmod +x "$target"
        if check_command gio; then
            gio set "$target" metadata::trusted true 2>/dev/null || true
        fi
        log_success "Raccourci bureau créé : $target"
    done
}

# ==============================================================================
# Menu XDG fusionné : force la présence dans « Éducation »
# ==============================================================================
# Certains menus (MATE notamment) n'affichaient pas Pronote dans Éducation
# malgré Categories=Education. Le fichier fusionné inclut explicitement les
# lanceurs 32 et 64 bits dans le sous-menu Education (nom standard commun à
# MATE, XFCE, Cinnamon, Budgie, KDE, LXQt). GNOME Shell l'ignore sans effet.
# ------------------------------------------------------------------------------

install_xdg_menu_entry() {
    mkdir -p "$MENU_MERGE_DIR"
    local menu_file="$MENU_MERGE_DIR/pronote-${PRONOTE_YEAR}.menu"

    cat > "$menu_file" << EOF
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
 "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
<!-- Généré par le script d'installation Pronote : place Pronote dans le
     menu Éducation (MATE, XFCE, Cinnamon, Budgie, KDE, LXQt). -->
<Menu>
  <Name>Applications</Name>
  <Menu>
    <Name>Education</Name>
    <Include>
      <Filename>pronote-${PRONOTE_YEAR}-64.desktop</Filename>
      <Filename>pronote-${PRONOTE_YEAR}-32.desktop</Filename>
    </Include>
  </Menu>
</Menu>
EOF

    log_success "Menu XDG (Éducation) créé : $menu_file"
}

# ==============================================================================
# Création des lanceurs et des raccourcis
# ==============================================================================

create_launchers() {
    echo ""
    box_title "Creation des raccourcis Linux" 46
    echo ""

    mkdir -p "$BIN_DIR" "$APP_DIR" "$ICON_DIR" "$PIXMAP_DIR"

    discover_wine_paths

    local real_exe
    real_exe="$(find_pronote_exe)"

    if [ -z "$real_exe" ]; then
        log_warning "Exécutable Pronote non trouvé automatiquement."
        log_warning "Un chemin générique sera utilisé."
        real_exe="$WINEPREFIX/drive_c/Program Files/Index Education/PRONOTE ${PRONOTE_YEAR}/Client PRONOTE.exe"
    fi

    log_info "Exécutable utilisé : $real_exe"

    local icon_name
    icon_name="$(fetch_and_install_icon "$real_exe")"

    local icon_file
    icon_file="$(resolve_icon_path "$icon_name")"
    log_info "Icône utilisée : $icon_file"

    local launcher="$BIN_DIR/pronote-${PRONOTE_YEAR}-${PRONOTE_ARCH}"
    local launcher_log_dir="$HOME/.local/share/pronote-${PRONOTE_YEAR}-${PRONOTE_ARCH}"
    local wine_for_launcher="${WINE_BIN:-wine}"
    local wineserver_for_launcher="${WINESERVER_BIN:-}"
    local wine_dir_for_launcher=""
    wine_dir_for_launcher="$(dirname "$wine_for_launcher")"

    mkdir -p "$launcher_log_dir"

    cat > "$launcher" << EOF
#!/usr/bin/env bash
# Lanceur Pronote ${PRONOTE_YEAR} (${PRONOTE_ARCH} bits) - généré automatiquement
export WINEPREFIX="$WINEPREFIX"
export WINEDEBUG="-nls"
export PATH="$wine_dir_for_launcher:\$PATH"

# Binaire Wine mémorisé à l'installation ; repli sur le PATH si le chemin a
# disparu (ex. NixOS après nix-collect-garbage, mise à jour de Wine).
WINE_CMD="$wine_for_launcher"
if [ ! -x "\$WINE_CMD" ]; then
    WINE_CMD="\$(command -v wine 2>/dev/null || echo wine)"
fi
export WINE="\$WINE_CMD"
$(if [ -n "$wineserver_for_launcher" ]; then echo "[ -x \"$wineserver_for_launcher\" ] && export WINESERVER=\"$wineserver_for_launcher\""; fi)

LOG_DIR="$launcher_log_dir"
LOG_FILE="\$LOG_DIR/pronote.log"
mkdir -p "\$LOG_DIR"

if [ -f "\$LOG_FILE" ] && [ "\$(wc -c < "\$LOG_FILE" 2>/dev/null || echo 0)" -gt 10485760 ]; then
    mv "\$LOG_FILE" "\$LOG_FILE.1" 2>/dev/null || true
fi

CACHE_DIRS=(
    "\$WINEPREFIX/drive_c/ProgramData/IndexEducation/PRONOTE/CLIENT"
    "\$WINEPREFIX/drive_c/users/\$USER/AppData/Local/IndexEducation/PRONOTE/CLIENT"
)

for CACHE_DIR in "\${CACHE_DIRS[@]}"; do
    if [ -d "\$CACHE_DIR" ]; then
        find "\$CACHE_DIR" -type d -name "Cache" -exec rm -rf {} + 2>/dev/null || true
    fi
done

if [ "\${PRONOTE_DEBUG:-0}" = "1" ]; then
    exec "\$WINE_CMD" "$real_exe" "\$@"
else
    exec "\$WINE_CMD" "$real_exe" "\$@" >> "\$LOG_FILE" 2>&1
fi
EOF

    chmod +x "$launcher"
    ln -sf "$launcher" "$BIN_DIR/pronote-${PRONOTE_YEAR}"
    log_success "Lanceur créé : $launcher"
    log_info "Alias générique : $BIN_DIR/pronote-${PRONOTE_YEAR}"

    local desktop_file="$APP_DIR/pronote-${PRONOTE_YEAR}-${PRONOTE_ARCH}.desktop"

    cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Name=Pronote Client ${PRONOTE_YEAR} (${PRONOTE_ARCH} bits)
GenericName=Client Pronote
Comment=Client Pronote ${PRONOTE_YEAR} ${PRONOTE_ARCH} bits via Wine
Exec=$launcher
Terminal=false
Type=Application
Icon=$icon_file
Categories=Education;Office;
StartupNotify=true
Keywords=pronote;education;ecole;college;lycee;
EOF

    chmod +x "$desktop_file"
    log_success "Raccourci menu créé : $desktop_file"

    install_xdg_menu_entry

    update-desktop-database "$APP_DIR" 2>/dev/null || true
    refresh_icon_caches

    cleanup_wine_menu_entries

    ensure_path_in_shell_rc

    create_desktop_shortcut "$desktop_file"

    create_uninstaller "$desktop_file" "$launcher" "$icon_file" "$icon_name"
    create_uninstaller_dispatcher
}

# ==============================================================================
# Désinstallateur (un par architecture)
# ==============================================================================

create_uninstaller() {
    local desktop_file="$1"
    local launcher="$2"
    local icon_file="$3"
    local icon_name="$4"
    local uninstaller="$BIN_DIR/pronote-desinstaller-${PRONOTE_ARCH}"
    local wine_for_uninstaller="${WINE_BIN:-wine}"
    local wineserver_for_uninstaller="${WINESERVER_BIN:-wineserver}"

    local q_wineprefix q_desktop_file q_launcher q_icon_file q_app_dir q_icon_base_dir q_icon_name q_pixmap_dir q_bin_dir q_wine q_wineserver
    printf -v q_wineprefix    '%q' "$WINEPREFIX"
    printf -v q_desktop_file  '%q' "$desktop_file"
    printf -v q_launcher      '%q' "$launcher"
    printf -v q_icon_file     '%q' "$icon_file"
    printf -v q_app_dir       '%q' "$APP_DIR"
    printf -v q_icon_base_dir '%q' "$ICON_BASE_DIR"
    printf -v q_icon_name     '%q' "$icon_name"
    printf -v q_pixmap_dir    '%q' "$PIXMAP_DIR"
    printf -v q_bin_dir       '%q' "$BIN_DIR"
    printf -v q_wine          '%q' "$wine_for_uninstaller"
    printf -v q_wineserver    '%q' "$wineserver_for_uninstaller"

    cat > "$uninstaller" << EOF
#!/usr/bin/env bash
# Désinstallateur Pronote ${PRONOTE_YEAR} (${PRONOTE_ARCH} bits) - généré automatiquement

set -u

WINEPREFIX=$q_wineprefix
DESKTOP_FILE=$q_desktop_file
LAUNCHER=$q_launcher
ICON_FILE=$q_icon_file
ICON_NAME=$q_icon_name
APP_DIR=$q_app_dir
ICON_BASE_DIR=$q_icon_base_dir
PIXMAP_DIR=$q_pixmap_dir
BIN_DIR=$q_bin_dir
WINE_BIN=$q_wine
WINESERVER_BIN=$q_wineserver
PRONOTE_ARCH="${PRONOTE_ARCH}"
LOG_DIR="\$HOME/.local/share/pronote-installer"
LOG_FILE="\$LOG_DIR/desinstallation-${PRONOTE_YEAR}-${PRONOTE_ARCH}-\$(date +%Y%m%d-%H%M%S).log"
WINEDEBUG_QUIET="-all"
SHOW_WINE_LOGS="0"
RUN_QUIET_ACTIVITY_DIR=""
RUN_QUIET_FINALIZE_MSG=""

export WINEPREFIX
export WINE="\$WINE_BIN"
export WINESERVER="\$WINESERVER_BIN"
export PATH="\$(dirname "\$WINE_BIN"):\$PATH"

GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
RED='\\033[0;31m'
BLUE='\\033[0;34m'
NC='\\033[0m'

log_info()    { echo -e "\${BLUE}ℹ️  \$*\${NC}" >&2; }
log_success() { echo -e "\${GREEN}✅ \$*\${NC}" >&2; }
log_warning() { echo -e "\${YELLOW}⚠️  \$*\${NC}" >&2; }
log_error()   { echo -e "\${RED}❌ \$*\${NC}" >&2; }

repeat_char() {
    local char="\$1"
    local count="\$2"
    local out=""
    local i

    for ((i = 0; i < count; i++)); do
        out+="\$char"
    done

    printf "%s" "\$out"
}

box_title() {
    local title="\$1"
    local width="\${2:-46}"
    local inner=\$((width - 2))

    printf "╔"
    repeat_char "═" "\$width"
    printf "╗\\n"

    printf "║ %-*s ║\\n" "\$inner" "\$title"

    printf "╚"
    repeat_char "═" "\$width"
    printf "╝\\n"
}

progress_pulse() {
    local label="\$1"
    local pid="\$2"
    local activity_dir="\${3:-}"
    local finalize_msg="\${4:-Finalisation en cours, veuillez patienter quelques secondes...}"

    local width=24
    local block=7
    local pos=0
    local direction=1
    local start_time=\$SECONDS

    local check_activity=0
    [ -n "\$activity_dir" ] && check_activity=1

    local last_size=-1
    local stable_count=0
    local finalized=0
    local sample_tick=0
    local current_label="\$label"

    if [ ! -t 1 ]; then
        while kill -0 "\$pid" 2>/dev/null; do
            sleep 1
        done
        return
    fi

    while kill -0 "\$pid" 2>/dev/null; do
        local bar=""
        local i
        local elapsed=\$((SECONDS - start_time))
        local min=\$((elapsed / 60))
        local sec=\$((elapsed % 60))

        if [ "\$check_activity" -eq 1 ] && [ "\$finalized" -eq 0 ]; then
            sample_tick=\$((sample_tick + 1))

            if (( sample_tick >= 8 )); then
                sample_tick=0
                local cur_size
                cur_size="\$(du -sk "\$activity_dir" 2>/dev/null | cut -f1)"
                cur_size="\${cur_size:-0}"

                if [ "\$cur_size" = "\$last_size" ]; then
                    stable_count=\$((stable_count + 1))
                else
                    stable_count=0
                fi
                last_size="\$cur_size"

                if (( stable_count >= 3 && elapsed >= 5 )); then
                    finalized=1
                    current_label="\$finalize_msg"
                fi
            fi
        fi

        for ((i = 0; i < width; i++)); do
            if (( i >= pos && i < pos + block )); then
                bar+="█"
            else
                bar+=" "
            fi
        done

        printf "\\r\\033[K%s [%s] %02d:%02d" "\$current_label" "\$bar" "\$min" "\$sec"

        pos=\$((pos + direction))

        if (( pos <= 0 )); then
            pos=0
            direction=1
        elif (( pos + block >= width )); then
            pos=\$((width - block))
            direction=-1
        fi

        sleep 0.12
    done

    printf "\\r\\033[K"
}

run_quiet() {
    local label="\$1"
    shift

    if [ "\$SHOW_WINE_LOGS" = "1" ]; then
        log_info "\$label"
        "\$@"
        return \$?
    fi

    mkdir -p "\$LOG_DIR"

    (
        export WINEDEBUG="\$WINEDEBUG_QUIET"
        "\$@"
    ) >>"\$LOG_FILE" 2>&1 &

    local pid=\$!
    progress_pulse "\$label" "\$pid" "\$RUN_QUIET_ACTIVITY_DIR" "\$RUN_QUIET_FINALIZE_MSG"

    wait "\$pid"
    local status=\$?

    if [ "\$status" -eq 0 ]; then
        log_success "\$label : terminé"
    else
        log_warning "\$label : terminé avec un code retour \$status"
        echo "Journal technique : \$LOG_FILE"
    fi

    return "\$status"
}

clear
box_title "Desinstallation de Pronote ${PRONOTE_YEAR} (${PRONOTE_ARCH} bits)" 46
echo ""

echo "Ce script va ouvrir l'outil Wine « Ajout/Suppression de programmes »."
echo ""
echo "Avant de commencer, assurez-vous que Pronote est fermé."
echo "Le script va aussi tenter de fermer automatiquement les processus Pronote/Wine"
echo "du préfixe suivant :"
echo "  \$WINEPREFIX"
echo ""
log_warning "Si d'autres applications Wine utilisent ce même préfixe, elles peuvent être fermées."
echo ""

read -rp "Continuer ? [O/n] : " CONTINUE
case "\$CONTINUE" in
    n|N|non|Non|NON)
        echo "Désinstallation annulée."
        exit 0
        ;;
esac

echo ""
echo "Par défaut, les messages techniques de Wine seront masqués."
read -rp "Afficher les messages techniques de Wine ? [o/N] : " DEBUG_CHOICE

case "\$DEBUG_CHOICE" in
    o|O|oui|Oui|OUI|y|Y|yes|YES)
        SHOW_WINE_LOGS="1"
        log_warning "Mode expert activé."
        ;;
    *)
        SHOW_WINE_LOGS="0"
        log_info "Mode silencieux activé."
        echo "Journal technique : \$LOG_FILE"
        ;;
esac

echo ""
log_info "Fermeture préventive des processus Pronote/Wine du préfixe..."

"\$WINE_BIN" taskkill /F /IM "Client PRONOTE.exe" >/dev/null 2>&1 || true
"\$WINE_BIN" taskkill /F /IM "PRONOTE.exe" >/dev/null 2>&1 || true
"\$WINE_BIN" taskkill /F /IM "IECefSubProcess.exe" >/dev/null 2>&1 || true

"\$WINESERVER_BIN" -k >/dev/null 2>&1 || true
sleep 1

echo ""
echo "Dans la fenêtre qui va s'ouvrir :"
echo ""
echo "  1. Sélectionnez « INDEX EDUCATION - Client PRONOTE ${PRONOTE_YEAR} » ou l'entrée Pronote équivalente."
echo "  2. Cliquez sur « Modifier/Supprimer »."
echo "  3. Suivez l'assistant de désinstallation jusqu'à son terme."
echo "  4. Remarque : l'assistant peut sembler avoir disparu prématurément ; le bouton « Modifier/Supprimer »"
echo "     apparait alors en grisé (non sélectionnable), même si Pronote est toujours visible dans la liste."
echo "     C'est normal : il suffit de cliquer sur « OK » pour fermer/terminer proprement."
echo ""
echo "Ensuite, relancez la commande pronote-desinstaller-${PRONOTE_ARCH} pour supprimer le service de mise à jour associé, présent"
echo "dans la même liste et nommé exactement :"
echo ""
echo "     « Mise à jour automatique - Index Education - »"
echo ""
echo "Sélectionnez-le puis cliquez à nouveau sur « Modifier/Supprimer »"
echo "(la remarque 4 ci-dessus s'applique aussi à cette étape)."
echo ""
echo "Quand tout est terminé, fermez la fenêtre « Ajout/Suppression de programmes »."
echo ""

read -rp "Appuyez sur Entrée pour ouvrir le désinstallateur Wine..."

RUN_QUIET_ACTIVITY_DIR="\$WINEPREFIX/drive_c"
RUN_QUIET_FINALIZE_MSG="Désinstallation : finalisation en cours, veuillez patienter quelques secondes..."

run_quiet "Desinstallation via Wine" "\$WINE_BIN" uninstaller || true

RUN_QUIET_ACTIVITY_DIR=""
RUN_QUIET_FINALIZE_MSG=""

echo ""
log_info "Nettoyage des raccourcis Linux..."

rm -f "\$DESKTOP_FILE" 2>/dev/null || true
rm -f "\$LAUNCHER" 2>/dev/null || true

GENERIC_LAUNCHER="\$BIN_DIR/pronote-${PRONOTE_YEAR}"
if [ -L "\$GENERIC_LAUNCHER" ] && [ "\$(readlink -f "\$GENERIC_LAUNCHER")" = "\$(readlink -f "\$LAUNCHER" 2>/dev/null)" ]; then
    rm -f "\$GENERIC_LAUNCHER" 2>/dev/null || true
fi

OTHER_DESKTOP_COUNT=\$(find "\$APP_DIR" -maxdepth 1 -name "pronote-${PRONOTE_YEAR}-*.desktop" 2>/dev/null | wc -l)

if [ "\$OTHER_DESKTOP_COUNT" -eq 0 ]; then
    rm -f "\$ICON_FILE" 2>/dev/null || true
    rm -f "\$PIXMAP_DIR/\${ICON_NAME}.png" 2>/dev/null || true
    rm -f "\$ICON_BASE_DIR/scalable/apps/\${ICON_NAME}.svg" 2>/dev/null || true

    for SIZE in 16 22 24 32 48 64 128 256; do
        rm -f "\$ICON_BASE_DIR/\${SIZE}x\${SIZE}/apps/\${ICON_NAME}.png" 2>/dev/null || true
    done

    # Fichier de menu XDG (Éducation) créé par l'installateur v4.7
    rm -f "\$HOME/.config/menus/applications-merged/pronote-${PRONOTE_YEAR}.menu" 2>/dev/null || true
else
    log_info "Une autre version de Pronote est encore installée : l'icône est conservée."
fi

DESKTOP_TARGETS=()
if command -v xdg-user-dir >/dev/null 2>&1; then
    XDG_DESK="\$(xdg-user-dir DESKTOP 2>/dev/null || true)"
    [ -n "\$XDG_DESK" ] && DESKTOP_TARGETS+=("\$XDG_DESK")
fi
DESKTOP_TARGETS+=("\$HOME/Bureau" "\$HOME/Desktop")

for DDIR in "\${DESKTOP_TARGETS[@]}"; do
    [ -d "\$DDIR" ] || continue
    rm -f "\$DDIR/pronote-${PRONOTE_YEAR}-${PRONOTE_ARCH}.desktop" 2>/dev/null || true
    rm -f "\$DDIR/pronote-${PRONOTE_YEAR}.desktop" 2>/dev/null || true
done

if [ -d "\$APP_DIR/wine/Programs" ]; then
    find "\$APP_DIR/wine/Programs" -maxdepth 1 \\
        \\( -iname "PRONOTE*" -o -iname "Index Education*" \\) \\
        -exec rm -rf {} + 2>/dev/null || true
fi

# Menus Wine résiduels (winemenubuilder)
if [ -d "\$HOME/.config/menus/applications-merged" ]; then
    find "\$HOME/.config/menus/applications-merged" -maxdepth 1 -type f -name "wine-Programs-*" \\
        \\( -iname "*PRONOTE*" -o -iname "*Index Education*" \\) -delete 2>/dev/null || true
fi

update-desktop-database "\$APP_DIR" 2>/dev/null || true
gtk-update-icon-cache -f -t "\$ICON_BASE_DIR" 2>/dev/null || true
rm -f "\$HOME/.cache/icon-cache.kcache" 2>/dev/null || true
kbuildsycoca6 --noincremental 2>/dev/null || true
kbuildsycoca5 --noincremental 2>/dev/null || true

echo ""
log_success "Désinstallation terminée."
echo ""
echo "Vous pouvez maintenant fermer la fenêtre « Ajout/Suppression de programmes »"
echo "si elle est encore ouverte."
echo ""
echo "Remarque : le préfixe Wine n'a pas été supprimé :"
echo "  \$WINEPREFIX"
echo ""
echo "Pour supprimer entièrement ce préfixe Wine, uniquement si vous êtes sûr"
echo "qu'il ne contient pas d'autres logiciels utiles :"
echo "  rm -rf \\"\$WINEPREFIX\\""
echo ""
EOF

    chmod +x "$uninstaller"
    log_success "Désinstallateur créé : $uninstaller"

    ln -sf "$uninstaller" "$BIN_DIR/pronote-desinstaller-${PRONOTE_YEAR}-${PRONOTE_ARCH}"
}

create_uninstaller_dispatcher() {
    local dispatcher="$BIN_DIR/pronote-desinstaller"
    local q_bin_dir
    printf -v q_bin_dir '%q' "$BIN_DIR"

    cat > "$dispatcher" << EOF
#!/usr/bin/env bash
# Sélecteur de désinstallateur Pronote - généré automatiquement
set -u

BIN_DIR=$q_bin_dir

U32="\$BIN_DIR/pronote-desinstaller-32"
U64="\$BIN_DIR/pronote-desinstaller-64"

HAS32=0
HAS64=0
[ -x "\$U32" ] && HAS32=1
[ -x "\$U64" ] && HAS64=1

if [ "\$HAS32" -eq 0 ] && [ "\$HAS64" -eq 0 ]; then
    echo "Aucun désinstallateur Pronote trouvé dans \$BIN_DIR."
    exit 1
fi

if [ "\$#" -ge 1 ]; then
    case "\$1" in
        32) exec "\$U32" ;;
        64) exec "\$U64" ;;
    esac
fi

if [ "\$HAS32" -eq 1 ] && [ "\$HAS64" -eq 0 ]; then
    exec "\$U32"
fi

if [ "\$HAS64" -eq 1 ] && [ "\$HAS32" -eq 0 ]; then
    exec "\$U64"
fi

echo "Deux versions de Pronote sont installées."
echo ""
echo "  1) Désinstaller la version 64 bits  (pronote-desinstaller-64)"
echo "  2) Désinstaller la version 32 bits  (pronote-desinstaller-32)"
echo ""
read -rp "Votre choix [1/2] [Entrée=1] : " CHOICE

case "\${CHOICE:-1}" in
    2) exec "\$U32" ;;
    *) exec "\$U64" ;;
esac
EOF

    chmod +x "$dispatcher"
    log_success "Sélecteur de désinstallation créé : $dispatcher"
}

# ==============================================================================
# Aide / problèmes connus
# ==============================================================================

show_troubleshooting() {
    echo ""
    box_title "Problemes connus et solutions" 62
    echo ""
    echo "1. Erreur libcef.dll au démarrage, surtout avec deux écrans :"
    echo "   → Lancez : WINEPREFIX=\"$WINEPREFIX\" winecfg"
    echo "   → Onglet « Affichage » > cochez « Émuler un bureau virtuel » (ex. 1920x1080)."
    echo ""
    echo "2. Crash IECefSubProcess.exe :"
    echo "   → Essayez d'augmenter la résolution du bureau virtuel dans winecfg."
    echo ""
    echo "3. Pronote ne se lance qu'une seule fois :"
    echo "   → Le lanceur nettoie automatiquement certains caches au démarrage."
    echo "   → Si le problème persiste, relancez la session Linux."
    echo ""
    echo "4. Raccourci bureau non cliquable sous GNOME/Nautilus (icône avec cadenas) :"
    echo "   → Clic droit sur l'icône > « Autoriser le lancement »."
    echo ""
    echo "5. Diagnostic au lancement de Pronote :"
    echo "   → PRONOTE_DEBUG=1 pronote-${PRONOTE_YEAR}-${PRONOTE_ARCH}"
    echo ""
    echo "6. Une commande pronote-* semble « ne rien faire » (fréquent sur Mint XFCE) :"
    echo "   → Le PATH du terminal courant n'est pas encore à jour."
    echo "   → Faites simplement :  source ~/.bashrc && hash -r"
    echo "   → Ou ouvrez un nouveau terminal / reconnectez-vous."
    echo "   → En dernier recours, chemin complet :"
    echo "     $BIN_DIR/pronote-desinstaller-${PRONOTE_ARCH}"
    echo ""
    echo "7. « WINEARCH is set to win32 but this is not supported in wow64 mode » :"
    echo "   → Wine 10+/11 n'accepte plus les préfixes win32 purs."
    echo "   → Ce script installe alors Pronote 32 bits dans un préfixe WoW64 dédié."
    echo ""
    echo "8. Erreurs « No space left on device », « error=112 », « could not load kernel32.dll » :"
    echo "   → Disque (ou couche d'écriture du Live CD) plein pendant l'installation."
    echo "   → Libérez de l'espace, supprimez le préfixe incomplet puis relancez :"
    echo "     rm -rf \"$WINEPREFIX\""
    echo ""
    echo "9. L'entrée n'apparaît pas tout de suite dans le menu (MATE, XFCE, Budgie) :"
    echo "   → Déconnectez-vous / reconnectez-vous, ou relancez le tableau de bord"
    echo "     (MATE : mate-panel --replace &  |  XFCE : xfce4-panel -r)."
    echo ""
    if [ "$IN_NIX_SHELL" = "1" ]; then
        echo "10. NixOS : Wine provient de nix-shell. Pour le pérenniser (nix-collect-garbage),"
        echo "    ajoutez wineWow64Packages.stable (ou wineWowPackages.stable) et winetricks"
        echo "    à environment.systemPackages, puis nixos-rebuild switch."
        echo ""
    fi
}

# ==============================================================================
# Programme principal
# ==============================================================================

main() {
    mkdir -p "$LOG_DIR"
    ensure_privilege_helper || true

    PRONOTE_URL_FROM_OPTION=""
    PRONOTE_ARCH_FROM_OPTION=""

    if [ ! -t 0 ]; then
        ASSUME_YES="1"
        SHOW_WINE_LOGS="0"
        log_info "Entrée non interactive détectée : mode silencieux activé."
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                usage
                exit 0
                ;;
            --yes)
                ASSUME_YES="1"
                shift
                ;;
            --arch)
                if [ -z "${2:-}" ]; then
                    log_error "--arch nécessite une valeur (32 ou 64)."
                    exit 1
                fi
                if [[ "$2" != "32" && "$2" != "64" ]]; then
                    log_error "Architecture invalide : $2 (attendu 32 ou 64)."
                    exit 1
                fi
                PRONOTE_ARCH_FROM_OPTION="$2"
                shift 2
                ;;
            --url)
                if [ -z "${2:-}" ]; then
                    log_error "--url nécessite une URL."
                    exit 1
                fi
                PRONOTE_URL_FROM_OPTION="$2"
                shift 2
                ;;
            --uninstall)
                UNINSTALL_ONLY="1"
                if [[ "${2:-}" == "32" || "${2:-}" == "64" ]]; then
                    UNINSTALL_ARCH="$2"
                    shift
                fi
                shift
                ;;
            --in-nix-shell)
                IN_NIX_SHELL="1"
                shift
                ;;
            *)
                log_error "Option inconnue : $1"
                usage
                exit 1
                ;;
        esac
    done

    if [ "$UNINSTALL_ONLY" = "1" ]; then
        local uninstaller=""

        if [ -n "$UNINSTALL_ARCH" ]; then
            uninstaller="$BIN_DIR/pronote-desinstaller-${UNINSTALL_ARCH}"
        else
            uninstaller="$BIN_DIR/pronote-desinstaller"
        fi

        if [ ! -x "$uninstaller" ]; then
            for candidate in \
                "$BIN_DIR/pronote-desinstaller-64" \
                "$BIN_DIR/pronote-desinstaller-32" \
                "$BIN_DIR/pronote-desinstaller-${DEFAULT_YEAR}" \
                "$BIN_DIR/pronote-desinstaller"; do
                if [ -x "$candidate" ]; then
                    uninstaller="$candidate"
                    break
                fi
            done
        fi

        if [ -x "$uninstaller" ]; then
            exec "$uninstaller"
        else
            log_error "Désinstallateur introuvable. Avez-vous déjà installé Pronote avec ce script ?"
            exit 1
        fi
    fi

    detect_distro

    if [ "$IN_NIX_SHELL" = "1" ]; then
        DISTRO_FAMILY="nixos-done"
        log_success "Environnement NixOS (ou dérivé) actif."
    fi

    log_info "Distribution détectée : $DISTRO_NAME ($DISTRO_FAMILY)"
    log_info "Installateur Pronote Linux v$SCRIPT_VERSION"

    set_target_windows_version

    ask_wine_output_mode
    ensure_dependencies

    check_latest_version

    if [ -n "$PRONOTE_URL_FROM_OPTION" ]; then
        process_custom_url
    else
        get_pronote_url
    fi

    set_wineprefix
    configure_wine
    install_pronote
    create_launchers

    log_info "Nettoyage des fichiers temporaires..."
    rm -rf "$TMP_DIR" 2>/dev/null || true

    echo ""
    echo -e "${GREEN}"
    box_title "Installation terminee avec succes" 62
    echo -e "${NC}"

    log_success "Version installée : Pronote $PRONOTE_VERSION - ${PRONOTE_ARCH} bits"
    echo ""
    echo "Pour lancer Pronote :"
    echo "  • Menu Applications > Éducation > Pronote Client $PRONOTE_YEAR (${PRONOTE_ARCH} bits)"
    echo "  • Ou en terminal : pronote-${PRONOTE_YEAR}-${PRONOTE_ARCH}   (alias : pronote-$PRONOTE_YEAR)"
    echo "  • Ou double-clic sur le raccourci Bureau (si un dossier Bureau a été détecté)"
    echo ""
    echo "Pour désinstaller :"
    echo "  • Version 64 bits : ~/.local/bin/pronote-desinstaller-64"
    echo "  • Version 32 bits : ~/.local/bin/pronote-desinstaller-32"
    echo "  • Ou simplement   : ~/.local/bin/pronote-desinstaller (propose le choix si les deux sont installées)"
    echo ""
    echo "Astuce : les versions 32 et 64 bits peuvent être installées en même temps ;"
    echo "chacune a son propre préfixe Wine et son propre désinstallateur."
    echo ""
    echo "Emplacements :"
    echo "  • Préfixe Wine : $WINEPREFIX"
    echo "  • Lanceur : $BIN_DIR/pronote-${PRONOTE_YEAR}-${PRONOTE_ARCH}"
    echo "  • Raccourci menu : $APP_DIR/pronote-${PRONOTE_YEAR}-${PRONOTE_ARCH}.desktop"
    echo "  • Menu XDG : $MENU_MERGE_DIR/pronote-${PRONOTE_YEAR}.menu"
    echo "  • Journal d'installation : $LOG_FILE"
    echo ""

    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *)
            log_warning "$BIN_DIR n'est pas présent dans le PATH actuel."
            echo "Dans ce terminal, faites :"
            echo "  source ~/.bashrc && hash -r"
            ;;
    esac

    show_troubleshooting

    log_success "Bonne utilisation de Pronote !"
    echo ""
}

main "$@"
