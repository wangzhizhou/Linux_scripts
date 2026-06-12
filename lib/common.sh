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
log_info() { printf "  %s●%s %s\n" "${C_CYAN}" "${C_RESET}" "$*"; }
log_success() { printf "  %s✓%s %s\n" "${C_GREEN}" "${C_RESET}" "$*"; }
log_warn() { printf "  %s!%s %s\n" "${C_YELLOW}" "${C_RESET}" "$*" >&2; }
log_error() { printf "  %s✗%s %s\n" "${C_RED}" "${C_RESET}" "$*" >&2; }
log_verbose() { [[ "${VERBOSE:-false}" == "true" ]] && printf "  %s[DEBUG]%s %s\n" "${C_PURPLE}" "${C_RESET}" "$*" >&2; }

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
    if (( $# >= 2 )); then
        shift 2
    else
        shift
    fi
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
        if cp -p "$file" "$bak"; then
            echo "$bak"
        else
            log_error "无法创建备份: $bak"
            return 1
        fi
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
    local comment="${2:-#}"
    echo "${comment} >>> EasyWork managed section begin (v${version}) >>>"
}

managed_section_end() {
    local comment="${1:-#}"
    echo "${comment} <<< EasyWork managed section end <<<"
}

replace_managed_section() {
    local file="$1"
    local version="$2"
    local content="$3"
    local comment="${4:-#}"
    local begin_marker
    begin_marker="$(managed_section_begin "$version" "$comment")"
    local end_marker
    end_marker="$(managed_section_end "$comment")"

    if [[ ! -f "$file" ]]; then
        # File doesn't exist — create with managed section
        {
            printf '%s\n' "$begin_marker"
            printf '%s\n' "$content"
            printf '%s\n' "$end_marker"
        } > "$file"
        return 0
    fi

    # Comment-agnostic detection: match distinctive marker text to avoid
    # false positives on content lines that casually mention "EasyWork"
    if grep -qE "managed section begin" "$file" 2> /dev/null; then
        # Managed section exists — replace it (comment-agnostic matching for cross-version compat)
        local tmpfile
        tmpfile="${file}.tmp.$$"
        _register_temp_file "$tmpfile"
        local in_section=false
        while IFS= read -r line; do
            if [[ "$line" =~ "managed section begin" ]]; then
                in_section=true
                printf '%s\n' "$begin_marker" >> "$tmpfile"
                printf '%s\n' "$content" >> "$tmpfile"
                continue
            fi
            if [[ "$line" =~ "managed section end" ]]; then
                in_section=false
                printf '%s\n' "$end_marker" >> "$tmpfile"
                continue
            fi
            if ! $in_section; then
                printf '%s\n' "$line" >> "$tmpfile"
            fi
        done < "$file"
        mv "$tmpfile" "$file"
    else
        # No managed section — prepend
        local tmpfile
        tmpfile="${file}.tmp.$$"
        _register_temp_file "$tmpfile"
        {
            printf '%s\n' "$begin_marker"
            printf '%s\n' "$content"
            printf '%s\n' "$end_marker"
            printf '%s\n' ""
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
        # Escape key for safe regex matching; || true prevents set -e from
        # firing when grep returns 1 (no match — a normal, expected case)
        local escaped_key
        escaped_key="$(_escape_regex "$key")"
        val="$(grep -E "^${escaped_key}=" "$MANIFEST_FILE" 2> /dev/null | head -1 | cut -d= -f2- || true)"
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
    _register_temp_file "$tmpfile"
    printf '%s\n' "$manifest_data" > "$tmpfile"
    mv "$tmpfile" "$MANIFEST_FILE"
}

manifest_set_section() {
    local section="$1"
    local new_manifest=""
    local skip_section=false

    # Read existing manifest (minus the target section)
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

    # Append the new section with key=value pairs (if any)
    new_manifest+="[${section}]"$'\n'
    if [[ $# -gt 1 ]]; then
        shift
        local pair
        for pair in "$@"; do
            new_manifest+="${pair}"$'\n'
        done
    fi

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
    new_manifest="$(printf '%s\n' "$new_manifest" | awk 'NF{last=NR}; {lines[NR]=$0} END{for(i=1;i<=last;i++) print lines[i]}')"
    printf '%s\n' "$new_manifest" > "$MANIFEST_FILE"
}

manifest_clear() {
    rm -f "$MANIFEST_FILE"
}

# ─── Date Formatting ─────────────────────────────────────────────
# Convert ISO 8601 date string to human-readable local time.
# Input:  2026-06-12T10:15:30+0800  (from manifest install_date)
# Output: 2026年06月12日 10:15:30 CST (varies by local timezone)
format_date_human() {
    local raw_date="$1"
    local fallback="${2:-${raw_date:-unknown}}"

    if [[ -z "$raw_date" ]] || [[ "$raw_date" == "unknown" ]]; then
        echo "$fallback"
        return
    fi

    local formatted
    case "$(detect_os)" in
        macos)
            # BSD date: -j for dry-run parse, -f for input format
            formatted="$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$raw_date" \
                "+%Y年%m月%d日 %H:%M:%S %Z" 2> /dev/null || true)"
            ;;
        *)
            # GNU date: -d for date string parsing
            formatted="$(date -d "$raw_date" \
                "+%Y年%m月%d日 %H:%M:%S %Z" 2> /dev/null || true)"
            ;;
    esac

    # Fallback to raw date if parsing fails (e.g. corrupt manifest)
    echo "${formatted:-$raw_date}"
}

# ─── Manifest Section Key Reader ─────────────────────────────────
# Read a key from within a specific manifest section.
# Usage: manifest_read_section_key <section> <key> [default]
manifest_read_section_key() {
    local section="$1"
    local key="$2"
    local default="${3:-}"

    if ! manifest_exists; then
        echo "$default"
        return
    fi

    # Escape key for safe regex matching
    local escaped_key
    escaped_key="$(_escape_regex "$key")"

    local in_section=false
    while IFS= read -r line; do
        if [[ "$line" == "[${section}]" ]]; then
            in_section=true
            continue
        fi
        if $in_section; then
            if [[ "$line" == "["*"]" ]]; then
                break # reached next section, stop
            fi
            if [[ "$line" =~ ^${escaped_key}= ]]; then
                echo "${line#*=}"
                return
            fi
        fi
    done < "$MANIFEST_FILE"
    echo "$default"
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
            cat > "$CONFIG_FILE" << 'EOC'
# EasyWork 配置文件
# 各模块配置由对应模块自行管理
# 编辑: easywork config edit
EOC
        fi
    fi
    config_load
}

_save_config_var() {
    local section="$1" key="$2" value="$3"
    local section_marker="## ${section}"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        config_init
    fi

    # Escape key for regex use (grep -E / sed)
    local escaped_key
    escaped_key="$(_escape_regex "$key")"
    # Escape value for sed replacement side
    local escaped_value
    escaped_value="$(_escape_sed_replacement "$value")"

    # Ensure section marker exists
    if ! grep -qF "$section_marker" "$CONFIG_FILE" 2> /dev/null; then
        printf '\n' >> "$CONFIG_FILE"
        printf '%s\n' "$section_marker" >> "$CONFIG_FILE"
    fi

    # Upsert key=value
    if grep -q "^${escaped_key}=" "$CONFIG_FILE" 2> /dev/null; then
        local tmpfile="${CONFIG_FILE}.tmp.$$"
        _register_temp_file "$tmpfile"
        sed "s/^${escaped_key}=.*/${key}=\"${escaped_value}\"/" "$CONFIG_FILE" > "$tmpfile" 2> /dev/null
        mv "$tmpfile" "$CONFIG_FILE"
    else
        # Insert after section marker
        local tmpfile="${CONFIG_FILE}.tmp.$$"
        _register_temp_file "$tmpfile"
        while IFS= read -r line; do
            printf '%s\n' "$line" >> "$tmpfile"
            [[ "$line" == "$section_marker" ]] && printf '%s\n' "${key}=\"${value}\"" >> "$tmpfile"
        done < "$CONFIG_FILE"
        mv "$tmpfile" "$CONFIG_FILE"
    fi
}

config_show() {
    echo "配置文件路径: $(config_path)"
    echo ""
    if config_exists; then
        local cfg_file
        cfg_file="$(config_path)"

        # --- File Metadata ---
        local file_size line_count mod_time
        file_size="$(wc -c < "$cfg_file" | tr -d ' ')"
        line_count="$(wc -l < "$cfg_file" | tr -d ' ')"
        if [[ "$(detect_os)" == "macos" ]]; then
            mod_time="$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$cfg_file" 2> /dev/null || echo 'unknown')"
        else
            mod_time="$(stat -c "%y" "$cfg_file" 2> /dev/null | cut -d. -f1 || echo 'unknown')"
        fi

        echo "  文件大小: ${file_size} 字节"
        echo "  行数:     ${line_count} 行"
        echo "  修改时间: ${mod_time}"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # --- Config Content ---
        local content
        content="$(cat "$cfg_file")"
        cat "$cfg_file"

        # Show hint when config has no actual key=value pairs (template-only file)
        if ! grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*=' "$cfg_file" 2> /dev/null; then
            echo ""
            echo "（配置文件尚无配置项，可通过 'easywork config edit' 编辑添加）"
        fi
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
    if ! "$editor" "$(config_path)"; then
        # Editor exited non-zero (e.g. :cq in vim) — ignore, not a fatal error
        :
    fi
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
    local reserved="^(install|uninstall|config|version|update)$"
    if [[ "$name" =~ $reserved ]]; then
        log_error "模块名 '$name' 与内置命令冲突"
        exit $EXIT_ERROR
    fi

    # Validate: no whitespace, control chars, path traversal, or special chars
    if [[ "$name" =~ [[:space:]] ]] || [[ "$name" =~ [[:cntrl:]] ]]; then
        log_error "模块名包含非法空白/控制字符: '$name'"
        exit $EXIT_ERROR
    fi
    if [[ "$name" =~ [/] ]] || [[ "$name" == ".." ]]; then
        log_error "模块名包含路径穿越字符: '$name'"
        exit $EXIT_ERROR
    fi
    if [[ "$name" =~ [^a-zA-Z0-9_-] ]]; then
        log_error "模块名包含非法字符（仅允许字母、数字、-、_）: '$name'"
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
    [[ ${#MODULE_NAMES[@]} -eq 0 ]] && return 1
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

# ─── Semver Comparison ───────────────────────────────────────
# Returns: 0=equal, 1=first is newer, 2=second is newer
_semver_compare() {
    local IFS=.
    local i
    local a
    IFS=. read -ra a <<< "${1:-0.0.0}"
    local b
    IFS=. read -ra b <<< "${2:-0.0.0}"
    for i in 0 1 2; do
        local ai=${a[$i]:-0}
        # Strip leading v prefix (GitHub tag style) and pre-release suffix
        ai="${ai#v}"
        ai="${ai%%[-+]*}"
        ai="${ai:-0}"
        local bi=${b[$i]:-0}
        bi="${bi#v}"
        bi="${bi%%[-+]*}"
        bi="${bi:-0}"
        if ((ai > bi)); then return 1; fi
        if ((ai < bi)); then return 2; fi
    done
    return 0
}

_semver_is_newer() {
    # Returns 0 (true) if $1 > $2
    _semver_compare "$1" "$2"
    [[ $? -eq 1 ]]
}

# ─── Concurrency Lock ─────────────────────────────────────────
LOCK_FILE="${TMPDIR:-/tmp}/easywork.lock"
# Use fixed fd=200 for bash 3.2 compatibility (no {varname}> auto-assignment)
LOCK_FD=200

acquire_lock() {
    local timeout="${1:-30}"

    # Try flock (Linux) first — not available on macOS by default.
    # When flock is absent or fails, we fall through to shlock or mkdir.
    if has_cmd flock; then
        eval "exec ${LOCK_FD}> \"$LOCK_FILE\""
        if flock -w "$timeout" "$LOCK_FD" 2> /dev/null; then
            return 0
        fi
        eval "exec ${LOCK_FD}>&-" 2> /dev/null || true
    fi

    # Try shlock (macOS)
    if has_cmd shlock; then
        if shlock -f "$LOCK_FILE" -p $$ 2> /dev/null; then
            return 0
        fi
    fi

    # Fallback: mkdir atomic operation
    local lock_dir="${LOCK_FILE}.dir"
    local start
    start=$(date +%s)
    while ! mkdir "$lock_dir" 2> /dev/null; do
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
        flock -u "$LOCK_FD" 2> /dev/null || true
        eval "exec ${LOCK_FD}>&-" 2> /dev/null || true
    fi
    # Clean up mkdir-based lock directory
    if [[ "$LOCK_FILE" == *.dir ]] && [[ -d "$LOCK_FILE" ]]; then
        rmdir "$LOCK_FILE" 2> /dev/null || true
    elif [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE" 2> /dev/null || true
    fi
    # Preserve the numeric fd constant so re-acquire works correctly.
    # acquire_lock uses eval "exec ${LOCK_FD}> ..." — clearing this to ""
    # would redirect stdout on the next call instead of opening a file descriptor.
    : "${LOCK_FD:=200}"
}

# ─── Signal Handling ──────────────────────────────────────────

cleanup_on_interrupt() {
    log_warn "操作被中断"
    release_lock
    if [[ -n "$TEMP_FILES" ]]; then
        # shellcheck disable=SC2086
        rm -f -- $TEMP_FILES
    fi
    # Safety net: clean common tmp patterns for this PID
    rm -f "${HOME}/.easywork"*.tmp."$$" 2> /dev/null || true
    rm -f "${TMPDIR:-/tmp}/easywork"*.tmp."$$" 2> /dev/null || true
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
    has_cmd awk || missing+=("awk")
    has_cmd sed || missing+=("sed")

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

# ─── String Escaping Helpers ──────────────────────────────────

# Escape regex metacharacters for safe use in grep -E / [[ =~ ]]
_escape_regex() {
    sed -e 's/\\/\\\\/g' \
        -e 's/\./\\./g' \
        -e 's/\*/\\*/g' \
        -e 's/\[/\\[/g' \
        -e 's/\]/\\]/g' \
        -e 's/\^/\\^/g' \
        -e 's/\$/\\$/g' \
        -e 's/|/\\|/g' \
        -e 's/(/\\(/g' \
        -e 's/)/\\)/g' \
        -e 's/\+/\\+/g' \
        -e 's/?/\\?/g' \
        <<< "$1"
}

# Escape value for safe use in sed s/// replacement (handles \ & /)
_escape_sed_replacement() {
    sed -e 's/\\/\\\\/g' \
        -e 's/&/\\&/g' \
        -e 's/\//\\\//g' \
        <<< "$1"
}

# ─── Temp File Tracking (for signal cleanup) ──────────────────
TEMP_FILES=""

_register_temp_file() {
    TEMP_FILES="${TEMP_FILES}${TEMP_FILES:+ }$1"
}
