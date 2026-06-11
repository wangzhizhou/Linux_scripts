#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# EasyWork — Git Configuration Module
# Configures Git user identity and extensive alias set.

MODULE_NAME="git"
MODULE_DESCRIPTION="配置 Git 别名和身份"
MODULE_PRIORITY=20

GIT_CONFIG_FILE="$HOME/.gitconfig"

module_check() {
    [[ -f "$GIT_CONFIG_FILE" ]] && grep -qF "# >>> EasyWork managed section" "$GIT_CONFIG_FILE" 2> /dev/null
}

module_status() {
    if module_check; then
        local name
        name="$(git config --global user.name 2> /dev/null || echo 'unknown')"
        local email
        email="$(git config --global user.email 2> /dev/null || echo 'unknown')"
        echo "git: 已安装 — ${name} <${email}>"
    else
        echo "git: 未安装"
    fi
}

# ─── Input Validation ─────────────────────────────────────────
_validate_email() {
    local email="$1"
    # Basic email format validation
    [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

_validate_name() {
    local name="$1"
    # Must not be empty
    [[ -n "$name" ]] || return 1
    # Must not contain dangerous shell metacharacters
    local pattern
    pattern='[$`\|&;()]'
    if echo "$name" | grep -qE "$pattern" 2> /dev/null; then
        return 1
    fi
    return 0
}

# ─── Show Git Config ──────────────────────────────────────────
_show_current_git_config() {
    local scope="${1:-global}"
    local name
    name="$(git config --"$scope" user.name 2> /dev/null || echo '(未设置)')"
    local email
    email="$(git config --"$scope" user.email 2> /dev/null || echo '(未设置)')"
    echo "  Git 用户名: $name"
    echo "  Git 邮箱:   $email"
}

# ─── Select Identity ───────────────────────────────────────────
_select_identity() {
    # Load config for available identities
    config_load

    echo ""
    echo "  选择 Git 身份:"
    echo "    1) personal  — ${GIT_PERSONAL_NAME:-'(未配置)'} <${GIT_PERSONAL_EMAIL:-'(未配置)'}>"
    echo "    2) work      — ${GIT_WORK_NAME:-'(未配置)'} <${GIT_WORK_EMAIL:-'(未配置)'}>"
    echo "    3) custom    — 手动输入"

    local choice
    if [[ "${YES_MODE:-false}" != "true" ]]; then
        read -r -p "  请选择 [1-3]: " choice
    else
        choice="1"
        log_info "非交互模式，使用默认: personal"
    fi

    case "$choice" in
        1)
            GIT_USER_NAME="${GIT_PERSONAL_NAME:-}"
            GIT_USER_EMAIL="${GIT_PERSONAL_EMAIL:-}"
            ;;
        2)
            GIT_USER_NAME="${GIT_WORK_NAME:-}"
            GIT_USER_EMAIL="${GIT_WORK_EMAIL:-}"
            ;;
        3)
            if [[ "${YES_MODE:-false}" != "true" ]]; then
                read -r -p "  输入 Git 用户名: " GIT_USER_NAME
                read -r -p "  输入 Git 邮箱: " GIT_USER_EMAIL
            else
                log_error "非交互模式下不支持自定义身份，请编辑 $(config_path)"
                return 1
            fi
            ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac

    # Validate
    if ! _validate_name "${GIT_USER_NAME:-}"; then
        log_error "Git 用户名无效或为空。请编辑 $(config_path)"
        return 1
    fi
    if ! _validate_email "${GIT_USER_EMAIL:-}"; then
        log_error "Git 邮箱格式无效: ${GIT_USER_EMAIL:-}"
        log_error "请编辑 $(config_path) 填入正确的邮箱地址"
        return 1
    fi

    log_info "使用身份: ${GIT_USER_NAME} <${GIT_USER_EMAIL}>"
    return 0
}

# ─── Generate Git Config ──────────────────────────────────────
_generate_git_config() {
    cat << 'GITCONF'
[user]
    name = __GIT_USER_NAME__
    email = __GIT_USER_EMAIL__

[diff]
    submodule = log

[pager]
    branch = false

[pull]
    rebase = false

[color]
    ui = auto

[alias]
    # ── Config ──
    cfg = config --global --list
    cfl = config --local --list
    cfs = config --system --list
    cfw = config --worktree --list

    # ── Log (美化日志) ──
    l = log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset %C(bold yellow) by %an' --abbrev-commit --date=relative --decorate
    la = log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset %C(bold yellow) by %an' --abbrev-commit --date=relative --decorate --all
    lm = log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset' --abbrev-commit --date=relative --decorate --author="$(git config user.name)"
    lma = log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset' --abbrev-commit --date=relative --decorate --author="$(git config user.name)" --all
    lc = log --oneline -n 10
    lg = log --graph --oneline --decorate --all
    lgs = log --stat -n 1
    lgt = log --oneline --since="2 weeks ago"
    lgb = log --oneline --branches
    lgr = log --oneline --remotes
    lgtg = log --oneline --tags

    # ── Branch ──
    b = branch
    br = branch -r
    bv = branch -vv
    bd = branch -d
    bD = branch -D
    bu = branch -u

    # ── Pull / Push ──
    pl = pull
    plrs = pull --recurse-submodules --ff-only
    plrb = pull --rebase
    pu = push
    pm = push --mirror
    po = push origin
    pof = push origin -f
    poh = push origin HEAD
    pot = push origin --tags
    poa = push origin --all
    pofs = push origin --force-with-lease

    # ── Add / Commit ──
    a = add
    c = commit
    ca = commit --amend
    cm = commit -m

    # ── Checkout ──
    co = checkout
    cb = checkout -b

    # ── Clone ──
    cl = clone
    cdf = clean -dxf
    clrs = clone --recurse-submodules

    # ── Cherry Pick ──
    pk = cherry-pick
    pkc = cherry-pick --continue
    pka = cherry-pick --abort

    # ── Diff ──
    d = diff
    dsm = diff --submodule

    # ── Merge ──
    m = merge
    mc = merge --continue
    ma = merge --abort

    # ── Status ──
    s = status
    ss = status -s

    # ── Stash ──
    st = stash
    sl = stash list
    sp = stash pop

    # ── Tag ──
    t = tag
    tl = tag -l
    td = tag -d

    # ── Submodule ──
    sm = submodule
    smi = submodule init
    smu = submodule update
    sms = submodule sync
    smur = submodule update --remote
    smuir = submodule update --init --recursive

    # ── Remote ──
    r = remote
    ra = remote add
    rv = remote -v
    rp = remote prune
    rpo = remote prune origin

    # ── Restore / Reset / Revert ──
    dp = restore
    re = restore
    ic = update-index --assume-unchanged
    uic = update-index --no-assume-unchanged
    rst = reset
    rsth = reset --hard HEAD
    rvt = revert

    # ── Rebase ──
    rb = rebase
    rbc = rebase --continue
    rba = rebase --abort
    rbi = rebase -i
    rbir = rebase -i --root

    # ── Worktree ──
    wt = worktree
    wta = worktree add
    wtl = worktree list
    wtr = worktree remove
    wtm = worktree move
    wtp = worktree prune

    # ── Format Patch ──
    fp = format-patch
    fp1 = format-patch -1
    ap = am

    # ── Misc ──
    h = config --global --list
    sh = !git --no-pager show HEAD
GITCONF
}

# ─── Module: Install ──────────────────────────────────────────
module_install() {
    if ! has_cmd git; then
        log_error "Git 未安装"
        return $EXIT_MISSING_DEPS
    fi

    # Ensure config is loaded
    if ! config_exists; then
        config_init
    fi
    config_load

    # Select identity
    if ! _select_identity; then
        return $EXIT_ERROR
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] 将配置 Git 身份: ${GIT_USER_NAME} <${GIT_USER_EMAIL}>"
        log_info "[DRY-RUN] 将生成/更新: $GIT_CONFIG_FILE"
        return 0
    fi

    # Backup existing gitconfig (if not already backed up by easywork)
    local bak
    if [[ -f "$GIT_CONFIG_FILE" ]] && ! grep -qF "# >>> EasyWork managed section" "$GIT_CONFIG_FILE" 2> /dev/null; then
        bak="$(backup_file "$GIT_CONFIG_FILE")"
        log_info "已备份现有 ~/.gitconfig → ${bak}"
    fi

    # Generate config with placeholders replaced
    local config_content
    config_content="$(_generate_git_config)"
    config_content="${config_content//__GIT_USER_NAME__/${GIT_USER_NAME}}"
    config_content="${config_content//__GIT_USER_EMAIL__/${GIT_USER_EMAIL}}"

    replace_managed_section "$GIT_CONFIG_FILE" "$EASYWORK_VERSION" "$config_content"
    log_success "已生成: $GIT_CONFIG_FILE"

    # Set git config globally (for immediate effect)
    git config --global --replace-all user.name "$GIT_USER_NAME" 2>/dev/null || git config --global user.name "$GIT_USER_NAME"
    git config --global --replace-all user.email "$GIT_USER_EMAIL" 2>/dev/null || git config --global user.email "$GIT_USER_EMAIL"

    # Record to manifest
    manifest_set_section "git" \
        "installed=true" \
        "config_file=${GIT_CONFIG_FILE}" \
        "${bak:+config_backup=${bak}}"

    log_success "Git 配置完成 ✓"
    _show_current_git_config "global"

    return 0
}

# ─── Module: Uninstall ────────────────────────────────────────
module_uninstall() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] 将恢复备份的 ~/.gitconfig（如有）"
        return 0
    fi

    # Try to restore backup
    local config_backup
    config_backup="$(manifest_read 'git_config_backup')"
    if [[ -n "$config_backup" ]] && [[ -f "$config_backup" ]]; then
        local answer="y"
        if [[ "${YES_MODE:-false}" != "true" ]]; then
            read -r -p "  恢复备份的 ~/.gitconfig？[Y/n] " answer
        fi
        if [[ ! "$answer" =~ ^[Nn] ]]; then
            restore_backup "$config_backup" "$GIT_CONFIG_FILE"
            log_success "已恢复备份的 ~/.gitconfig"
        fi
    else
        # No backup — just remove the managed section
        if [[ -f "$GIT_CONFIG_FILE" ]] && grep -qF "# >>> EasyWork managed section" "$GIT_CONFIG_FILE" 2> /dev/null; then
            local answer="y"
            if [[ "${YES_MODE:-false}" != "true" ]]; then
                read -r -p "  移除 EasyWork 写入的 Git 配置？[Y/n] " answer
            fi
            if [[ ! "$answer" =~ ^[Nn] ]]; then
                # Remove managed section, keep the rest
                local tmpfile="${GIT_CONFIG_FILE}.tmp.$$"
                local begin_marker="# >>> EasyWork managed section"
                local end_marker="# <<< EasyWork managed section end <<<"
                local in_section=false
                local had_content=false
                while IFS= read -r line; do
                    if [[ "$line" == "$begin_marker"* ]]; then
                        in_section=true
                        had_content=true
                        continue
                    fi
                    if $in_section && [[ "$line" == "$end_marker" ]]; then
                        in_section=false
                        continue
                    fi
                    if ! $in_section; then
                        echo "$line" >> "$tmpfile"
                    fi
                done < "$GIT_CONFIG_FILE"
                if $had_content; then
                    mv "$tmpfile" "$GIT_CONFIG_FILE"
                else
                    rm -f "$tmpfile"
                fi
                log_success "已移除 EasyWork Git 配置"
            fi
        fi
    fi

    return 0
}
