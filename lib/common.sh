#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# EasyWork — Common Library
# Provides: system detection, logging, download, manifest, config, managed sections,
#           module registry, concurrency lock, signal handling, exit codes.

set -euo pipefail

# Version (set by bin/easywork; default for standalone module usage)
EASYWORK_VERSION="${EASYWORK_VERSION:-1.0.0}"

# ─── Exit Codes ───────────────────────────────────────────────
export EXIT_SUCCESS=0
export EXIT_ERROR=1
export EXIT_MISSING_DEPS=2
export EXIT_NETWORK=3
export EXIT_PERMISSION=4
export EXIT_LOCK=5
export EXIT_INTERRUPT=130

# ─── Color Support Detection ──────────────────────────────────
COLOR_ENABLED=false
if [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]] && [[ -z "${NO_COLOR:-}" ]]; then
    COLOR_ENABLED=true
fi

C_BLACK=''
C_RED=''
C_GREEN=''
C_YELLOW=''
C_BLUE=''
C_PURPLE=''
C_CYAN=''
C_WHITE=''
C_RESET=''
if $COLOR_ENABLED; then
    C_BLACK=$'\e[30m'
    C_RED=$'\e[31m'
    C_GREEN=$'\e[32m'
    C_YELLOW=$'\e[33m'
    C_BLUE=$'\e[34m'
    C_PURPLE=$'\e[35m'
    C_CYAN=$'\e[36m'
    C_WHITE=$'\e[37m'
    C_RESET=$'\e[0m'
fi

# ─── Logging ──────────────────────────────────────────────────
log_info() { printf "  %s[INFO]%s %s\n" "${C_BLUE}" "${C_RESET}" "$*"; }
log_success() { printf "  %s[OK]%s %s\n" "${C_GREEN}" "${C_RESET}" "$*"; }
log_warn() { printf "  %s[WARN]%s %s\n" "${C_YELLOW}" "${C_RESET}" "$*" >&2; }
log_error() { printf "  %s[ERROR]%s %s\n" "${C_RED}" "${C_RESET}" "$*" >&2; }

# ─── System Detection ─────────────────────────────────────────
detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux) echo "linux" ;;
        *) echo "unknown" ;;
    esac
}

detect_shell() {
    basename "${SHELL:-/bin/bash}"
}

detect_pkg_manager() {
    if command -v brew > /dev/null 2>&1; then
        echo "brew"
    elif command -v apt-get > /dev/null 2>&1; then
        echo "apt-get"
    elif command -v dnf > /dev/null 2>&1; then
        echo "dnf"
    elif command -v yum > /dev/null 2>&1; then
        echo "yum"
    elif command -v pacman > /dev/null 2>&1; then
        echo "pacman"
    elif command -v zypper > /dev/null 2>&1; then
        echo "zypper"
    elif command -v apk > /dev/null 2>&1; then
        echo "apk"
    else
        echo "unknown"
    fi
}

has_cmd() { command -v "$1" > /dev/null 2>&1; }

# ─── Network ──────────────────────────────────────────────────
check_network() {
    local target="${1:-github.com}"
    local timeout="${2:-5}"
    if has_cmd curl; then
        curl -s --connect-timeout "$timeout" "https://${target}" > /dev/null 2>&1
    elif has_cmd wget; then
        wget -q --timeout="$timeout" -O /dev/null "https://${target}" 2> /dev/null
    else
        return 1
    fi
}

safe_download() {
    local url="$1"
    local output="${2:-}"
    shift 2 2>/dev/null || true
    local opts=(-fsSL --proto '=https' --tlsv1.2 --retry 3 --retry-delay 1 --retry-connrefused)
    if [[ -n "$output" ]]; then
        curl "${opts[@]}" "$@" -o "$output" "$url"
    else
        curl "${opts[@]}" "$@" "$url"
    fi
}

# ─── File Operations ──────────────────────────────────────────
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local ts
        ts="$(date +%Y%m%dT%H%M%S)"
        local bak="${file}.bak.${ts}"
        cp -p "$file" "$bak"
        echo "$bak"
    fi
}

restore_backup() {
    local bak="$1"
    local target="$2"
    if [[ -f "$bak" ]]; then
        mv "$bak" "$target"
        return 0
    fi
    return 1
}

# ─── Managed Section Markers ──────────────────────────────────
managed_section_begin() {
    local version="${1:-unknown}"
    echo "# >>> EasyWork managed section begin (v${version}) >>>"
}

managed_section_end() {
    echo "# <<< EasyWork managed section end <<<"
}

replace_managed_section() {
    local file="$1"
    local version="$2"
    local content="$3"
    local begin_marker
    begin_marker="$(managed_section_begin "$version")"
    local end_marker
    end_marker="$(managed_section_end)"

    if [[ ! -f "$file" ]]; then
        # File doesn't exist — create with managed section
        {
            echo "$begin_marker"
            echo "$content"
            echo "$end_marker"
        } > "$file"
        return 0
    fi

    if grep -qF "# >>> EasyWork managed section begin" "$file" 2>/dev/null; then
        # Managed section exists — replace it (match markers by prefix for cross-version compat)
        local tmpfile
        tmpfile="${file}.tmp.$$"
        local in_section=false
        local marker_prefix="# >>> EasyWork managed section begin"
        while IFS= read -r line; do
            if [[ "$line" == "$marker_prefix"* ]]; then
                in_section=true
                echo "$begin_marker" >> "$tmpfile"
                echo "$content" >> "$tmpfile"
                continue
            fi
            if [[ "$line" == "$end_marker" ]]; then
                in_section=false
                echo "$end_marker" >> "$tmpfile"
                continue
            fi
            if ! $in_section; then
                echo "$line" >> "$tmpfile"
            fi
        done < "$file"
        mv "$tmpfile" "$file"
    else
        # No managed section — prepend
        local tmpfile
        tmpfile="${file}.tmp.$$"
        {
            echo "$begin_marker"
            echo "$content"
            echo "$end_marker"
            echo ""
            cat "$file"
        } > "$tmpfile"
        mv "$tmpfile" "$file"
    fi
}

# ─── Manifest Management ──────────────────────────────────────
MANIFEST_FILE="$HOME/.easywork.manifest"

manifest_file() { echo "$MANIFEST_FILE"; }

manifest_exists() { [[ -f "$MANIFEST_FILE" ]]; }

manifest_read() {
    local key="$1"
    local default="${2:-}"
    if manifest_exists; then
        local val
        val="$(grep -E "^${key}=" "$MANIFEST_FILE" 2> /dev/null | head -1 | cut -d= -f2-)"
        echo "${val:-$default}"
    else
        echo "$default"
    fi
}

manifest_get_version() {
    manifest_read "easywork_version" "0.0.0"
}

manifest_section_exists() {
    local section="$1"
    manifest_exists && grep -qF "[$section]" "$MANIFEST_FILE" 2> /dev/null
}

manifest_section_installed() {
    local section="$1"
    manifest_list_installed | grep -qFx "$section"
}

manifest_list_installed() {
    if ! manifest_exists; then return 0; fi
    awk -F'=' '/^\[/{section=$1; gsub(/[\[\]]/,"",section)} /^installed=true$/{print section}' "$MANIFEST_FILE"
}

manifest_init() {
    local version="$1"
    cat > "$MANIFEST_FILE" << EOF
# EasyWork Manifest — auto-generated, do not edit
easywork_version=${version}
install_date=$(date +%Y-%m-%dT%H:%M:%S%z)
EOF
}

manifest_write() {
    local manifest_data="$1"
    local tmpfile
    tmpfile="${MANIFEST_FILE}.tmp.$$"
    echo "$manifest_data" > "$tmpfile"
    mv "$tmpfile" "$MANIFEST_FILE"
}

manifest_set_section() {
    local section="$1"
    shift
    local pairs=("$@")

    # Read existing manifest (minus the target section)
    local new_manifest=""
    local skip_section=false
    if manifest_exists; then
        while IFS= read -r line; do
            if [[ "$line" == "[${section}]" ]]; then
                skip_section=true
                continue
            fi
            if $skip_section; then
                if [[ "$line" == "["*"]" ]]; then
                    skip_section=false
                    new_manifest+="$line"$'\n'
                fi
                continue
            fi
            new_manifest+="$line"$'\n'
        done < "$MANIFEST_FILE"
    else
        new_manifest="# EasyWork Manifest — auto-generated, do not edit"$'\n'
    fi

    # Append the new section
    new_manifest+="[${section}]"$'\n'
    for pair in "${pairs[@]}"; do
        new_manifest+="${pair}"$'\n'
    done

    manifest_write "$new_manifest"
}

manifest_remove_section() {
    local section="$1"
    if ! manifest_exists; then return 0; fi
    local new_manifest=""
    local skip_section=false
    while IFS= read -r line; do
        if [[ "$line" == "[${section}]" ]]; then
            skip_section=true
            continue
        fi
        if $skip_section; then
            if [[ "$line" == "["*"]" ]]; then
                skip_section=false
                new_manifest+="$line"$'\n'
            fi
            continue
        fi
        new_manifest+="$line"$'\n'
    done < "$MANIFEST_FILE"

    # Remove trailing blank lines
    # Remove trailing blank lines (portable awk instead of BSD/GNU sed)
    new_manifest="$(echo "$new_manifest" | awk 'NF{last=NR}; {lines[NR]=$0} END{for(i=1;i<=last;i++) print lines[i]}')"
    echo "$new_manifest" > "$MANIFEST_FILE"
}

manifest_clear() {
    rm -f "$MANIFEST_FILE"
}

# ─── Config File Management ───────────────────────────────────
CONFIG_FILE="${HOME}/.easywork.conf"
CONFIG_EXAMPLE="${EASYWORK_ROOT:-.}/easywork.conf.example"

config_path() { echo "$CONFIG_FILE"; }

config_exists() { [[ -f "$CONFIG_FILE" ]]; }

config_load() {
    if config_exists; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi
}

config_init() {
    if ! config_exists; then
        if [[ -f "$CONFIG_EXAMPLE" ]]; then
            cp "$CONFIG_EXAMPLE" "$CONFIG_FILE"
            log_info "已创建配置文件: $CONFIG_FILE"
            log_info "请编辑此文件填入你的个人信息: easywork config edit"
        else
            log_warn "配置模板 $CONFIG_EXAMPLE 不存在，创建空配置"
            cat > "$CONFIG_FILE" << 'EOC'
# EasyWork 配置文件
GIT_PERSONAL_NAME="Your Name"
GIT_PERSONAL_EMAIL="your@email.com"
GIT_WORK_NAME="Your Name"
GIT_WORK_EMAIL="your@work.com"
EOC
        fi
    fi
    config_load
}

config_show() {
    echo "配置文件路径: $(config_path)"
    if config_exists; then
        echo "---"
        cat "$(config_path)"
    else
        echo "（配置文件不存在，运行 easywork install 自动创建）"
    fi
}

config_edit() {
    if ! config_exists; then
        config_init
    fi
    local editor="${EDITOR:-}"
    if [[ -z "$editor" ]]; then
        for e in vim nano vi; do
            if has_cmd "$e"; then
                editor="$e"
                break
            fi
        done
    fi
    if [[ -z "$editor" ]]; then
        log_error "未找到编辑器，请设置 \$EDITOR 环境变量"
        return 1
    fi
    "$editor" "$(config_path)"
}

# ─── Module Registry ──────────────────────────────────────────
# Uses indexed arrays for bash 3.2+ compatibility (macOS default)
MODULE_NAMES=()
MODULE_DESCRIPTIONS=()
MODULE_PRIORITY_VALUES=()

register_module() {
    local name="$1"
    local description="$2"
    local priority="${3:-50}"

    # Validate: module name must not conflict with reserved words
    local reserved="^(install|uninstall|config|version|update|help)$"
    if [[ "$name" =~ $reserved ]]; then
        log_error "模块名 '$name' 与内置命令冲突"
        exit $EXIT_ERROR
    fi

    # Prevent duplicate registration
    if module_registered "$name"; then
        return 0
    fi

    MODULE_NAMES+=("$name")
    MODULE_DESCRIPTIONS+=("$description")
    MODULE_PRIORITY_VALUES+=("$priority")
}

module_registered() {
    local name="$1"
    local n
    [[ ${#MODULE_NAMES[@]} -eq 0 ]] && return 1
    for n in "${MODULE_NAMES[@]}"; do
        [[ "$n" == "$name" ]] && return 0
    done
    return 1
}

_get_module_index() {
    local name="$1"
    local i
    [[ ${#MODULE_NAMES[@]} -eq 0 ]] && return 0
    for i in "${!MODULE_NAMES[@]}"; do
        if [[ "${MODULE_NAMES[$i]}" == "$name" ]]; then
            echo "$i"
            return 0
        fi
    done
    return 1
}

list_modules() {
    local entries=() i
    [[ ${#MODULE_NAMES[@]} -eq 0 ]] && return 0
    for i in "${!MODULE_NAMES[@]}"; do
        entries+=("${MODULE_PRIORITY_VALUES[$i]}|${MODULE_NAMES[$i]}|${MODULE_DESCRIPTIONS[$i]}")
    done
    if [[ ${#entries[@]} -gt 0 ]]; then
        printf '%s\n' "${entries[@]}" | sort -t'|' -k1 -n | while IFS='|' read -r prio name desc; do
            [[ -n "$name" ]] && printf "  %-30s %s\n" "$name" "$desc"
        done
    fi
}

list_modules_sorted() {
    local entries=() i
    [[ ${#MODULE_NAMES[@]} -eq 0 ]] && return 0
    for i in "${!MODULE_NAMES[@]}"; do
        entries+=("${MODULE_PRIORITY_VALUES[$i]}|${MODULE_NAMES[$i]}")
    done
    if [[ ${#entries[@]} -gt 0 ]]; then
        printf '%s\n' "${entries[@]}" | sort -t'|' -k1 -n | cut -d'|' -f2
    fi
}

# ─── Concurrency Lock ─────────────────────────────────────────
LOCK_FILE="${TMPDIR:-/tmp}/easywork.lock"
# Use fixed fd=200 for bash 3.2 compatibility (no {varname}> auto-assignment)
LOCK_FD=200

acquire_lock() {
    local timeout="${1:-30}"

    # Try flock (Linux) first
    if has_cmd flock; then
        eval "exec ${LOCK_FD}> \"$LOCK_FILE\""
        if flock -w "$timeout" "$LOCK_FD" 2>/dev/null; then
            return 0
        fi
        eval "exec ${LOCK_FD}>&-" 2>/dev/null || true
    fi

    # Try shlock (macOS)
    if has_cmd shlock; then
        if shlock -f "$LOCK_FILE" -p $$ 2>/dev/null; then
            return 0
        fi
    fi

    # Fallback: mkdir atomic operation
    local lock_dir="${LOCK_FILE}.dir"
    local start
    start=$(date +%s)
    while ! mkdir "$lock_dir" 2>/dev/null; do
        local now
        now=$(date +%s)
        if ((now - start >= timeout)); then
            log_error "无法获取锁，可能有另一个 easywork 实例正在运行"
            return $EXIT_LOCK
        fi
        sleep 0.5
    done
    # Save lock_dir path for cleanup (overwrite LOCK_FILE to signal mkdir was used)
    LOCK_FILE="$lock_dir"
    return 0
}

release_lock() {
    # Release flock if active
    if [[ -n "${LOCK_FD:-}" ]]; then
        flock -u "$LOCK_FD" 2>/dev/null || true
        eval "exec ${LOCK_FD}>&-" 2>/dev/null || true
    fi
    # Clean up mkdir-based lock directory
    if [[ "$LOCK_FILE" == *.dir ]] && [[ -d "$LOCK_FILE" ]]; then
        rmdir "$LOCK_FILE" 2>/dev/null || true
    elif [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE" 2>/dev/null || true
    fi
    LOCK_FD=""
}

# ─── Signal Handling ──────────────────────────────────────────
TEMP_FILES=""

cleanup_on_interrupt() {
    log_warn "操作被中断"
    release_lock
    if [[ -n "$TEMP_FILES" ]]; then
        # shellcheck disable=SC2086
        rm -f $TEMP_FILES
    fi
    exit $EXIT_INTERRUPT
}

trap cleanup_on_interrupt INT TERM

# ─── Preflight Check ──────────────────────────────────────────
preflight_check() {
    local missing=()
    local optional_missing=()

    has_cmd curl || missing+=("curl")
    has_cmd git || missing+=("git")
    has_cmd bash || missing+=("bash")

    if ! has_cmd zsh; then
        optional_missing+=("zsh (Oh My Zsh 将跳过)")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少必须依赖: ${missing[*]}"
        log_error "请先安装后重试"
        return $EXIT_MISSING_DEPS
    fi

    if [[ ${#optional_missing[@]} -gt 0 ]]; then
        log_warn "缺少可选依赖: ${optional_missing[*]}"
    fi

    if ! check_network; then
        log_warn "网络不可达 (github.com)，部分功能可能不可用"
    fi

    return $EXIT_SUCCESS
}

# ─── Dependency Installer ─────────────────────────────────────
ensure_deps() {
    local deps=("$@")
    local missing=()
    for dep in "${deps[@]}"; do
        if ! has_cmd "$dep"; then
            missing+=("$dep")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少依赖: ${missing[*]}"
        return $EXIT_MISSING_DEPS
    fi
    return $EXIT_SUCCESS
}
