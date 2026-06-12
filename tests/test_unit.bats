#!/usr/bin/env bats
# Unit tests: core library functions (common.sh)

setup() {
    load helpers/mocks
    setup_mocks
    EASYWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "${EASYWORK_ROOT}/lib/common.sh"
}

teardown() { teardown_mocks; }

# ── System Detection ─────────────────────────────────────────

@test "unit: detect_os returns known value" {
    local os; os="$(detect_os)"
    [[ "$os" =~ ^(macos|linux|unknown)$ ]]
}

@test "unit: detect_shell returns valid shell name" {
    local sh; sh="$(detect_shell)"
    [[ "$sh" =~ ^(zsh|bash|sh|unknown)$ ]]
}

@test "unit: detect_pkg_manager returns known value" {
    local pm; pm="$(detect_pkg_manager)"
    [[ -n "$pm" ]]
}

# ── Command Detection ────────────────────────────────────────

@test "unit: has_cmd true for existing command" {
    run has_cmd bash
    [[ "$status" -eq 0 ]]
}

@test "unit: has_cmd false for missing command" {
    run has_cmd nonexistent_cmd_xyz123
    [[ "$status" -ne 0 ]]
}

# ── Logging ──────────────────────────────────────────────────

@test "unit: log_info/log_success output to stdout" {
    run log_info "test info"
    [[ "$output" =~ "test info" ]]
    run log_success "test ok"
    [[ "$output" =~ "test ok" ]]
}

@test "unit: log_error/log_warn output to stderr" {
    run log_error "test err"
    [[ "$output" =~ "test err" ]]
    run log_warn "test warn"
    [[ "$output" =~ "test warn" ]]
}

# ── File Operations ──────────────────────────────────────────

@test "unit: backup_file creates timestamped backup" {
    local f="${TEST_HOME}/testfile"
    echo "original" > "$f"
    local bak; bak="$(backup_file "$f")"
    [[ -f "$bak" ]]
    [[ "$bak" =~ "testfile.bak." ]]
}

@test "unit: backup_file returns empty for missing file" {
    local bak; bak="$(backup_file "${TEST_HOME}/noexist")"
    [[ -z "$bak" ]]
}

@test "unit: restore_backup restores file" {
    local f="${TEST_HOME}/orig"; echo "orig" > "$f"
    local bak="${TEST_HOME}/orig.backup.test"; echo "backup" > "$bak"
    restore_backup "$bak" "$f"
    [[ "$(cat "$f")" == "backup" ]]
}

# ── Config ───────────────────────────────────────────────────

@test "unit: config_path returns path" {
    run config_path
    [[ "$output" =~ ".easywork.conf" ]]
}

@test "unit: config_init creates config" {
    rm -f "$CONFIG_FILE"
    config_init
    [[ -f "$CONFIG_FILE" ]]
    # Should NOT contain git placeholder values
    run cat "$CONFIG_FILE"
    [[ ! "$output" =~ "Your Name" ]]
}

@test "unit: config_load reads variables" {
    echo 'TEST_VAR="loaded_value"' > "$CONFIG_FILE"
    config_load
    [[ "${TEST_VAR:-}" == "loaded_value" ]]
}

@test "unit: _save_config_var writes and updates" {
    rm -f "$CONFIG_FILE"
    _save_config_var "git" "GIT_PERSONAL_NAME" "Alice"
    _save_config_var "git" "GIT_PERSONAL_EMAIL" "a@b.com"
    _save_config_var "git" "GIT_PERSONAL_NAME" "Alice2"
    run cat "$CONFIG_FILE"
    [[ "$output" =~ "## git" ]]
    [[ "$output" =~ 'GIT_PERSONAL_NAME="Alice2"' ]]
    [[ "$output" =~ 'GIT_PERSONAL_EMAIL="a@b.com"' ]]
}

# ── Manifest ─────────────────────────────────────────────────

@test "unit: manifest lifecycle" {
    rm -f "$MANIFEST_FILE"
    run manifest_exists; [[ "$status" -ne 0 ]]

    manifest_init "1.0.0"
    run manifest_exists; [[ "$status" -eq 0 ]]
    [[ "$(manifest_get_version)" == "1.0.0" ]]

    manifest_set_section "shell" "installed=true" "shell_type=zsh"
    run manifest_section_exists "shell"; [[ "$status" -eq 0 ]]
    [[ "$(manifest_read 'shell_type')" == "zsh" ]]
    [[ "$(manifest_read 'missing' 'default')" == "default" ]]

    run manifest_section_installed "shell"; [[ "$status" -eq 0 ]]
    run manifest_list_installed
    [[ "$output" =~ "shell" ]]

    manifest_remove_section "shell"
    run manifest_section_exists "shell"; [[ "$status" -ne 0 ]]

    manifest_clear
    [[ ! -f "$MANIFEST_FILE" ]]
}

@test "unit: manifest handles corrupt file" {
    echo "garbage line" > "$MANIFEST_FILE"
    run manifest_read 'anykey' 'fallback'
    [[ "$output" == "fallback" ]]
    run manifest_section_exists "anything"; [[ "$status" -ne 0 ]]
}

@test "unit: manifest section_installed false for missing" {
    manifest_init "1.0.0"
    run manifest_section_installed "nonexistent"; [[ "$status" -ne 0 ]]
}

# ── Module Registry ──────────────────────────────────────────

@test "unit: module registry operations" {
    register_module "testmod" "Test Module" 10
    run module_registered "testmod"; [[ "$status" -eq 0 ]]
    run module_registered "noexist"; [[ "$status" -ne 0 ]]
}

@test "unit: register_module rejects reserved names" {
    run register_module "install" "bad"
    [[ "$status" -ne 0 ]]
}

@test "unit: duplicate registration is idempotent" {
    register_module "dupmod" "First" 10
    register_module "dupmod" "Second" 20
    # Should not crash, still registered
    run module_registered "dupmod"; [[ "$status" -eq 0 ]]
}

@test "unit: empty module registry is safe" {
    run list_modules_sorted; [[ -z "$output" ]]
    run list_modules; [[ "$status" -eq 0 ]]
}

# ── Semver ───────────────────────────────────────────────────

_sv() { set +e; _semver_compare "$1" "$2"; local rc=$?; set -e; return $rc; }

@test "unit: semver comparisons" {
    run _sv "1.0.0" "1.0.0"; [[ "$status" -eq 0 ]]
    run _sv "2.0.0" "1.9.9"; [[ "$status" -eq 1 ]]
    run _sv "1.2.0" "1.1.9"; [[ "$status" -eq 1 ]]
    run _sv "1.0.1" "1.0.0"; [[ "$status" -eq 1 ]]
    run _sv "0.9.0" "1.0.0"; [[ "$status" -eq 2 ]]
    run _sv "0.0.0" "0.0.0"; [[ "$status" -eq 0 ]]
}

# ── Managed Section ──────────────────────────────────────────

@test "unit: replace_managed_section creates file with markers" {
    local f="${TEST_HOME}/managed_test"
    replace_managed_section "$f" "1.0.0" "content line"
    grep -q "EasyWork managed section begin" "$f"
    grep -q "content line" "$f"
    grep -q "EasyWork managed section end" "$f"
}

@test "unit: replace_managed_section preserves user content" {
    local f="${TEST_HOME}/managed_test2"
    echo "user_before" > "$f"
    echo "# >>> EasyWork managed section begin (v1.0.0) >>>" >> "$f"
    echo "old_managed" >> "$f"
    echo "# <<< EasyWork managed section end <<<" >> "$f"
    echo "user_after" >> "$f"
    replace_managed_section "$f" "2.0.0" "new_managed"
    grep -q "user_before" "$f"
    grep -q "user_after" "$f"
    grep -q "new_managed" "$f"
    ! grep -q "old_managed" "$f"
}

@test "unit: replace_managed_section handles empty content" {
    local f="${TEST_HOME}/managed_empty"
    replace_managed_section "$f" "1.0.0" ""
    [[ -f "$f" ]]
    grep -q "EasyWork managed section" "$f"
}

@test "unit: replace_managed_section prepends to existing" {
    local f="${TEST_HOME}/managed_prepend"
    echo "preexisting" > "$f"
    replace_managed_section "$f" "1.0.0" "new content"
    grep -q "preexisting" "$f"
    grep -q "new content" "$f"
}

# ── Exit Codes ───────────────────────────────────────────────

@test "unit: exit codes are non-zero and distinct" {
    [[ "$EXIT_SUCCESS" -eq 0 ]]
    [[ "$EXIT_ERROR" -ne 0 ]]
    [[ "$EXIT_MISSING_DEPS" -ne 0 ]]
}

# ── String Escaping Helpers ──────────────────────────────────

@test "unit: _escape_regex escapes metacharacters" {
    local r; r="$(_escape_regex "key.with.dots")"
    [[ "$r" == 'key\.with\.dots' ]]
    r="$(_escape_regex "[bracket]")"
    [[ "$r" == '\[bracket\]' ]]
    r="$(_escape_regex "star*plus+")"
    [[ "$r" == 'star\*plus\+' ]]
}

@test "unit: _escape_sed_replacement escapes sed chars" {
    local r; r="$(_escape_sed_replacement "a/b")"
    [[ -n "$r" ]] && ! [[ "$r" == */* ]]
    r="$(_escape_sed_replacement "foo&bar")"
    [[ -n "$r" ]] && ! [[ "$r" == *'&'* ]]
}

# ── Semver with v-prefix ─────────────────────────────────────

_sv() { set +e; _semver_compare "$1" "$2"; local rc=$?; set -e; return $rc; }

@test "unit: semver handles v prefix from GitHub tags" {
    run _sv "v2.0.0" "v1.0.0"; [[ "$status" -eq 1 ]]
    run _sv "v1.0.0" "1.0.0"; [[ "$status" -eq 0 ]]
    run _sv "1.0.0" "v1.0.0"; [[ "$status" -eq 0 ]]
    run _sv "v0.9.0" "1.0.0"; [[ "$status" -eq 2 ]]
}

@test "unit: semver strips pre-release suffixes" {
    run _sv "2.0.0" "1.9.9-alpha"; [[ "$status" -eq 1 ]]
    run _sv "1.0.0" "1.0.0-rc1"; [[ "$status" -eq 0 ]]
}

# ── Module Name Validation ──────────────────────────────────

@test "unit: register_module rejects names with spaces" {
    run register_module "bad name" "desc"
    [[ "$status" -ne 0 ]]
}

@test "unit: register_module rejects names with slashes" {
    run register_module "bad/name" "desc"
    [[ "$status" -ne 0 ]]
}

@test "unit: register_module rejects names with dots" {
    run register_module "bad.name" "desc"
    [[ "$status" -ne 0 ]]
}

@test "unit: register_module accepts valid names with hyphens" {
    register_module "valid-name" "test" 99
    run module_registered "valid-name"; [[ "$status" -eq 0 ]]
    # Clean up to avoid polluting other tests
    MODULE_NAMES=()
    MODULE_DESCRIPTIONS=()
    MODULE_PRIORITY_VALUES=()
}

# ── Manifest Read with Section Key ───────────────────────────

@test "unit: manifest_read_section_key reads from correct section" {
    manifest_init "1.0.0"
    manifest_set_section "git" "installed=true" "config_backup=/bak/git.bak"
    manifest_set_section "vim" "installed=true" "config_backup=/bak/vim.bak"
    [[ "$(manifest_read_section_key 'git' 'config_backup')" == '/bak/git.bak' ]]
    [[ "$(manifest_read_section_key 'vim' 'config_backup')" == '/bak/vim.bak' ]]
    # Non-existent key returns default
    [[ "$(manifest_read_section_key 'git' 'missing' 'fallback')" == 'fallback' ]]
}

# ── Manifest Read escapes regex ──────────────────────────────

@test "unit: manifest_read escapes dot in key" {
    manifest_init "1.0.0"
    manifest_set_section "test" "key.with.dots=works"
    [[ "$(manifest_read_section_key 'test' 'key.with.dots')" == 'works' ]]
}
