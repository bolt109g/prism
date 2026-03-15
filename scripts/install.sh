#!/bin/sh
# Установщик Prism для Keenetic с Entware
#
# Использование:
#   curl -sL https://raw.githubusercontent.com/bolt109g/prism/main/scripts/install.sh | sh
#   wget -qO- .../install.sh | sh
#
# Установка конкретной версии:
#   curl -sL .../install.sh | sh -s -- 1.0.0

set -e

REPO="bolt109g/prism"
INSTALL_DIR="/opt/bin"
CONF_DIR="/opt/etc/prism"
INIT_SCRIPT="/opt/etc/init.d/S99prism"
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
TMP_DIR="/tmp/prism-install"
ENTWARE_REPO="https://hoaxisr.github.io/entware-repo"
OPKG_CONF="/opt/etc/opkg/awg.conf"

# Цветной вывод
info()  { printf "\033[1;32m[+]\033[0m %s\n" "$1"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$1"; }
error() { printf "\033[1;31m[-]\033[0m %s\n" "$1"; exit 1; }

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# Проверить наличие curl или wget
ensure_curl() {
    if command -v curl >/dev/null 2>&1; then
        FETCH="curl -fsSL"
        FETCH_OUT="curl -fL -o"
        return
    fi
    if command -v wget >/dev/null 2>&1; then
        FETCH="wget -qO-"
        FETCH_OUT="wget -qO"
        return
    fi
    # Попытка установить curl через opkg
    if command -v opkg >/dev/null 2>&1; then
        info "Устанавливаю curl через opkg..."
        opkg update >/dev/null 2>&1
        opkg install curl >/dev/null 2>&1
        if command -v curl >/dev/null 2>&1; then
            FETCH="curl -fsSL"
            FETCH_OUT="curl -fL -o"
            return
        fi
    fi
    error "Требуется curl или wget"
}

# Определить архитектуру Keenetic
detect_arch() {
    ARCH=$(opkg print-architecture 2>/dev/null | grep '_kn' | awk '{print $2}' | sed 's/_kn.*//')
    if [ -z "$ARCH" ]; then
        # Fallback: определить по uname
        UNAME_M=$(uname -m)
        case "$UNAME_M" in
            mipsel) ARCH="mipsel" ;;
            mips)   ARCH="mips" ;;
            aarch64) ARCH="aarch64" ;;
            x86_64)  ARCH="x86_64" ;;
            *) error "Не удалось определить архитектуру: $UNAME_M" ;;
        esac
    fi
    case "$ARCH" in
        mipsel*) GOARCH="mipsel" ;;
        mips*)   GOARCH="mips" ;;
        aarch64*) GOARCH="arm64" ;;
        x86_64) GOARCH="amd64" ;;
        *) error "Неподдерживаемая архитектура: $ARCH" ;;
    esac
    info "Архитектура: $ARCH ($GOARCH)"
}

# Добавить кастомный opkg-репозиторий для AWG пакетов
add_awg_repo() {
    REPO_LINE="src/gz awg_custom ${ENTWARE_REPO}/${ARCH}-kn"
    if [ -f "$OPKG_CONF" ] && grep -qF "$REPO_LINE" "$OPKG_CONF" 2>/dev/null; then
        return
    fi
    mkdir -p /opt/etc/opkg
    echo "$REPO_LINE" > "$OPKG_CONF"
    info "Репозиторий AWG добавлен"
}

# Установить awg-quick / wg-quick если отсутствуют
install_wg_tools() {
    # Проверить наличие awg-quick или wg-quick
    if command -v awg-quick >/dev/null 2>&1; then
        info "awg-quick найден: $(which awg-quick)"
        return
    fi
    if command -v wg-quick >/dev/null 2>&1; then
        info "wg-quick найден: $(which wg-quick)"
        return
    fi

    info "awg-quick / wg-quick не найдены, устанавливаю..."
    opkg update >/dev/null 2>&1 || true

    # Попытка 1: установить awg-tools (amneziawg) из кастомного репо
    if opkg install awg-tools 2>/dev/null; then
        if command -v awg-quick >/dev/null 2>&1; then
            info "awg-tools установлен"
            return
        fi
    fi

    # Попытка 2: установить wireguard-tools (стандартный WireGuard)
    if opkg install wireguard-tools 2>/dev/null; then
        if command -v wg-quick >/dev/null 2>&1; then
            info "wireguard-tools установлен"
            return
        fi
    fi

    warn "Не удалось автоматически установить awg-quick / wg-quick"
    warn "Установите вручную: opkg install awg-tools  или  opkg install wireguard-tools"
}

# Получить последнюю версию с GitHub
fetch_version() {
    if [ -n "$TARGET_VERSION" ]; then
        VERSION="$TARGET_VERSION"
        info "Используется указанная версия: $VERSION"
        return
    fi

    # Метод 1: redirect header
    VERSION=$($FETCH -I "https://github.com/$REPO/releases/latest" 2>/dev/null | \
        sed -n 's/^[Ll]ocation:.*\/v\([^ \t\r]*\).*/\1/p' | tr -d '\r\n')
    if [ -n "$VERSION" ]; then
        info "Последняя версия: $VERSION"
        return
    fi

    # Метод 2: GitHub API
    VERSION=$($FETCH "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null | \
        grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
    if [ -n "$VERSION" ]; then
        info "Последняя версия: $VERSION"
        return
    fi

    # Метод 3: HTML scraping
    VERSION=$($FETCH "https://github.com/$REPO/releases" 2>/dev/null | \
        grep -o '/releases/tag/v[0-9][^"]*' | head -1 | sed 's|.*/v||')
    if [ -n "$VERSION" ]; then
        info "Последняя версия: $VERSION"
        return
    fi

    error "Не удалось определить версию. Укажите вручную: sh install.sh 1.0.0"
}

# Скачать и установить бинарь
install_binary() {
    BINARY="prism-linux-${GOARCH}"
    URL="https://github.com/$REPO/releases/download/v${VERSION}/${BINARY}"
    mkdir -p "$TMP_DIR"
    info "Скачиваю $URL ..."
    $FETCH_OUT "$TMP_DIR/prism" "$URL" || error "Не удалось скачать $URL"
    chmod +x "$TMP_DIR/prism"
    mv "$TMP_DIR/prism" "$INSTALL_DIR/prism"
    info "Бинарь установлен: $INSTALL_DIR/prism"
}

# Создать директории конфигурации
setup_dirs() {
    mkdir -p "$CONF_DIR/tunnels"
    chmod 700 "$CONF_DIR"
    info "Директории созданы: $CONF_DIR"
}

# Установить init.d скрипт
install_initd() {
    INITD_DIR="$(dirname "$INIT_SCRIPT")"
    mkdir -p "$INITD_DIR"

    # Попытка скопировать из локального scripts/S99prism
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/S99prism" ]; then
        cp "$SCRIPT_DIR/S99prism" "$INIT_SCRIPT"
    else
        # Скачать из репозитория
        $FETCH_OUT "$INIT_SCRIPT" \
            "https://raw.githubusercontent.com/$REPO/main/scripts/S99prism" 2>/dev/null || \
            warn "Не удалось скачать init.d скрипт"
    fi

    if [ -f "$INIT_SCRIPT" ]; then
        chmod +x "$INIT_SCRIPT"
        info "Init.d скрипт установлен: $INIT_SCRIPT"
    fi
}

# Запустить сервис
start_service() {
    if [ -x "$INIT_SCRIPT" ]; then
        "$INIT_SCRIPT" stop 2>/dev/null || true
        sleep 1
        "$INIT_SCRIPT" start || warn "Запустите вручную: $INIT_SCRIPT start"
    else
        warn "Init.d скрипт не найден, запустите вручную: prism --port 8080"
    fi
}

# Health check
health_check() {
    info "Проверяю работоспособность..."
    ATTEMPTS=0
    MAX_ATTEMPTS=5
    while [ "$ATTEMPTS" -lt "$MAX_ATTEMPTS" ]; do
        ATTEMPTS=$((ATTEMPTS + 1))
        if curl -sf http://localhost:8080/api/health >/dev/null 2>&1; then
            info "Сервис работает!"
            return
        fi
        [ "$ATTEMPTS" -lt "$MAX_ATTEMPTS" ] && sleep 2
    done
    warn "Сервис не отвечает (может потребоваться больше времени для запуска)"
}

# Показать URL доступа
show_url() {
    IP=$(ip -4 addr show br0 2>/dev/null | awk '/inet /{sub(/\/.*/, "", $2); print $2; exit}')
    [ -z "$IP" ] && IP=$(ip -4 addr show eth0 2>/dev/null | awk '/inet /{sub(/\/.*/, "", $2); print $2; exit}')
    [ -z "$IP" ] && IP="192.168.1.1"
    echo ""
    info "========================================"
    info "  Prism установлен!"
    info "  Открыть: http://${IP}:8080"
    info "  Логин по умолчанию: admin / admin"
    warn "  СМЕНИТЕ ПАРОЛЬ после первого входа!"
    info "========================================"
    echo ""
}

TARGET_VERSION="${1:-}"
ensure_curl
detect_arch
add_awg_repo
install_wg_tools
fetch_version
install_binary
setup_dirs
install_initd
start_service
health_check
show_url
