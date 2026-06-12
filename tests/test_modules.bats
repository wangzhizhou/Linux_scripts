#!/usr/bin/env bats
# Module tests: shell, git, vim module behavior + integration

setup() {
    load helpers/mocks
    setup_mocks
    EASYWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "${EASYWORK_ROOT}/lib/common.sh"
}

teardown() { teardown_mocks; }

# ── Shell Module ─────────────────────────────────────────────

@test "module-shell: variables and module_check" {
    source "${EASYWORK_ROOT}/lib/shell.sh"
    [[ "$MODULE_NAME" == "shell" ]]
    [[ -n "$MODULE_DESCRIPTION" ]]
    [[ "$MODULE_PRIORITY" -eq 10 ]]
    # Not installed by default
    run module_check; [[ "$status" -ne 0 ]]
}

@test "module-shell: module_check true with markers" {
    source "${EASYWORK_ROOT}/lib/shell.sh"
    echo "# >>> EasyWork managed section begin (v1.0.0) >>>" > "$SH_CONFIG_FILE"
    echo "# <<< EasyWork managed section end <<<" >> "$SH_CONFIG_FILE"
    run module_check; [[ "$status" -eq 0 ]]
}

@test "module-shell: _detect_shell_rc returns a path" {
    source "${EASYWORK_ROOT}/lib/shell.sh"
    local rc; rc="$(_detect_shell_rc)"
    [[ "$rc" == "$HOME/"* ]]
}

@test "module-shell: _generate_shell_config has expected content" {
    source "${EASYWORK_ROOT}/lib/shell.sh"
    local content; content="$(_generate_shell_config)"
    [[ "$content" =~ "sh_config_custom" ]] || [[ "$content" =~ "alias" ]]
}

@test "module-shell: dry-run install does not create files" {
    source "${EASYWORK_ROOT}/lib/shell.sh"
    DRY_RUN=true module_install
    [[ ! -f "$SH_CONFIG_FILE" ]]
}

# ── Git Module ───────────────────────────────────────────────

@test "module-git: variables and module_check" {
    source "${EASYWORK_ROOT}/lib/git.sh"
    [[ "$MODULE_NAME" == "git" ]]
    run module_check; [[ "$status" -ne 0 ]]
}

@test "module-git: email validation" {
    source "${EASYWORK_ROOT}/lib/git.sh"
    run _validate_email "user@example.com"; [[ "$status" -eq 0 ]]
    run _validate_email "invalid-email"; [[ "$status" -ne 0 ]]
    run _validate_email ""; [[ "$status" -ne 0 ]]
}

@test "module-git: name validation" {
    source "${EASYWORK_ROOT}/lib/git.sh"
    run _validate_name "John Doe"; [[ "$status" -eq 0 ]]
    run _validate_name ""; [[ "$status" -ne 0 ]]
    run _validate_name 'name$(evil)'; [[ "$status" -ne 0 ]]
}

@test "module-git: _generate_git_config contains aliases" {
    source "${EASYWORK_ROOT}/lib/git.sh"
    local content; content="$(_generate_git_config)"
    [[ "$content" =~ "l = log" ]]
    [[ "$content" =~ "s = status" ]]
    [[ "$content" =~ "co = checkout" ]]
}

@test "module-git: dry-run install with config values" {
    cat > "$CONFIG_FILE" << 'EOF'
## git
GIT_PERSONAL_NAME="Test User"
GIT_PERSONAL_EMAIL="test@example.com"
EOF
    config_load
    source "${EASYWORK_ROOT}/lib/git.sh"
    DRY_RUN=true YES_MODE=true module_install
    [[ "$?" -eq 0 ]]
    # Git config should NOT be created in dry-run
    [[ ! -f "$GIT_CONFIG_FILE" ]]
}

# ── Vim Module ───────────────────────────────────────────────

@test "module-vim: variables and module_check" {
    source "${EASYWORK_ROOT}/lib/vim.sh"
    [[ "$MODULE_NAME" == "vim" ]]
    run module_check; [[ "$status" -ne 0 ]]
}

@test "module-vim: _generate_vimrc has plugins and mappings" {
    source "${EASYWORK_ROOT}/lib/vim.sh"
    local content; content="$(_generate_vimrc)"
    [[ "$content" =~ "NERDTree" ]]
    [[ "$content" =~ "coc.nvim" ]]
    [[ "$content" =~ "fzf" ]]
    [[ "$content" =~ "<C-n>" ]]
}

@test "module-vim: dry-run install does not create config" {
    source "${EASYWORK_ROOT}/lib/vim.sh"
    DRY_RUN=true module_install
    [[ ! -f "$VIMRC_FILE" ]]
}

# ── Integration ──────────────────────────────────────────────

@test "integration: fresh install manifest with modules" {
    manifest_init "1.0.0"
    manifest_set_section "shell" "installed=true"
    manifest_set_section "git" "installed=true"
    manifest_set_section "vim" "installed=true"

    local installed; installed="$(manifest_list_installed)"
    [[ "$installed" =~ "shell" ]]
    [[ "$installed" =~ "git" ]]
    [[ "$installed" =~ "vim" ]]
}

@test "integration: uninstall removes sections" {
    manifest_init "1.0.0"
    manifest_set_section "shell" "installed=true"
    manifest_set_section "git" "installed=true"
    manifest_remove_section "shell"
    run manifest_section_exists "shell"; [[ "$status" -ne 0 ]]
    run manifest_section_exists "git"; [[ "$status" -eq 0 ]]
}

@test "integration: partial uninstall leaves others" {
    manifest_init "1.0.0"
    manifest_set_section "shell" "installed=true"
    manifest_set_section "git" "installed=true"
    manifest_set_section "vim" "installed=true"
    manifest_remove_section "vim"
    local installed; installed="$(manifest_list_installed)"
    [[ "$installed" =~ "shell" ]]
    [[ "$installed" =~ "git" ]]
    [[ ! "$installed" =~ "vim" ]]
}

@test "integration: reinstall refreshes section" {
    manifest_init "1.0.0"
    manifest_set_section "shell" "installed=true" "shell_type=bash"
    manifest_set_section "shell" "installed=true" "shell_type=zsh"
    [[ "$(manifest_read 'shell_type')" == "zsh" ]]
}

@test "integration: upgrade updates manifest version" {
    manifest_init "1.0.0"
    sed "s/^easywork_version=.*/easywork_version=1.1.0/" "$MANIFEST_FILE" > "${MANIFEST_FILE}.tmp"
    mv "${MANIFEST_FILE}.tmp" "$MANIFEST_FILE"
    [[ "$(manifest_get_version)" == "1.1.0" ]]
}

@test "integration: modules sorted by priority" {
    register_module "aaa" "AAA" 90
    register_module "bbb" "BBB" 10
    register_module "ccc" "CCC" 50
    local sorted; sorted="$(list_modules_sorted)"
    # bbb (10) should come before ccc (50) before aaa (90)
    local b_pos="${sorted%%bbb*}"; b_pos="${#b_pos}"
    local c_pos="${sorted%%ccc*}"; c_pos="${#c_pos}"
    local a_pos="${sorted%%aaa*}"; a_pos="${#a_pos}"
    [[ "$b_pos" -lt "$c_pos" ]]
    [[ "$c_pos" -lt "$a_pos" ]]
}

@test "integration: manifest write-read cycle" {
    manifest_init "1.0.0"
    manifest_set_section "test" "key1=val1" "key2=val2" "installed=true"
    [[ "$(manifest_read 'key1')" == "val1" ]]
    [[ "$(manifest_read 'key2')" == "val2" ]]
    run manifest_section_installed "test"; [[ "$status" -eq 0 ]]
}
