#!/usr/bin/env bats
# Tests for lib/common.sh — Core utility functions

setup() {
    load helpers/mocks
    setup_mocks
    # Source common.sh in a way that doesn't exit on errors during test
    EASYWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    LIB_DIR="${EASYWORK_ROOT}/lib"
    source "${LIB_DIR}/common.sh"
}

teardown() {
    teardown_mocks
}

# ── System Detection ──────────────────────────────────────────

@test "detect_os returns a known value" {
    result="$(detect_os)"
    [[ "$result" =~ ^(macos|linux|unknown)$ ]]
}

@test "detect_shell returns a valid shell name" {
    result="$(detect_shell)"
    [[ -n "$result" ]]
}

@test "detect_pkg_manager returns a known value" {
    result="$(detect_pkg_manager)"
    [[ "$result" =~ ^(brew|apt-get|dnf|yum|pacman|zypper|apk|unknown)$ ]]
}

@test "has_cmd detects existing command" {
    run has_cmd bash
    [[ "$status" -eq 0 ]]
}

@test "has_cmd detects missing command" {
    run has_cmd nonexistent_command_xyz
    [[ "$status" -ne 0 ]]
}

# ── Logging ──────────────────────────────────────────────────

@test "log_info outputs to stdout" {
    run log_info "test message"
    [[ "$output" =~ "test message" ]]
}

@test "log_error outputs to stderr" {
    run log_error "error message"
    [[ "$output" =~ "error message" ]]
}

@test "log_success outputs to stdout" {
    run log_success "success message"
    [[ "$output" =~ "success message" ]]
}

@test "log_warn outputs to stderr" {
    run log_warn "warning message"
    [[ "$output" =~ "warning message" ]]
}

# ── File Operations ──────────────────────────────────────────

@test "backup_file creates timestamped backup" {
    echo "original" > "${TEST_HOME}/test_file"
    bak="$(backup_file "${TEST_HOME}/test_file")"
    [[ -f "$bak" ]]
    [[ "$bak" =~ \.bak\.[0-9]+T[0-9]+ ]]
}

@test "backup_file returns empty for non-existent file" {
    bak="$(backup_file "${TEST_HOME}/nonexistent")"
    [[ -z "$bak" ]]
}

@test "restore_backup restores file" {
    echo "backup content" > "${TEST_HOME}/backup_file"
    restore_backup "${TEST_HOME}/backup_file" "${TEST_HOME}/restored"
    [[ -f "${TEST_HOME}/restored" ]]
    [[ "$(cat "${TEST_HOME}/restored")" == "backup content" ]]
}

# ── Manifest ─────────────────────────────────────────────────

@test "manifest_file returns path" {
    [[ "$(manifest_file)" == *".easywork.manifest" ]]
}

@test "manifest_exists false before init" {
    rm -f "$MANIFEST_FILE"
    run manifest_exists
    [[ "$status" -ne 0 ]]
}

@test "manifest_init creates manifest" {
    manifest_init "1.0.0"
    [[ -f "$MANIFEST_FILE" ]]
    grep -q "easywork_version=1.0.0" "$MANIFEST_FILE"
}

@test "manifest_read gets value" {
    manifest_init "1.0.0"
    version="$(manifest_read 'easywork_version')"
    [[ "$version" == "1.0.0" ]]
}

@test "manifest_get_version returns version" {
    manifest_init "2.0.0"
    [[ "$(manifest_get_version)" == "2.0.0" ]]
}

@test "manifest_set_section adds section" {
    manifest_init "1.0.0"
    manifest_set_section "shell" "installed=true" "shell_type=zsh"
    grep -q "\[shell\]" "$MANIFEST_FILE"
    grep -q "installed=true" "$MANIFEST_FILE"
}

@test "manifest_remove_section removes section" {
    manifest_init "1.0.0"
    manifest_set_section "testmod" "installed=true"
    manifest_remove_section "testmod"
    ! grep -q "\[testmod\]" "$MANIFEST_FILE"
}

@test "manifest_list_installed lists installed modules" {
    manifest_init "1.0.0"
    manifest_set_section "shell" "installed=true"
    manifest_set_section "git" "installed=true"
    manifest_set_section "vim" "installed=false"
    result="$(manifest_list_installed)"
    [[ "$result" =~ "shell" ]]
    [[ "$result" =~ "git" ]]
    ! [[ "$result" =~ "vim" ]]
}

# ── Config ───────────────────────────────────────────────────

@test "config_path returns path" {
    [[ "$(config_path)" == *".easywork.conf" ]]
}

@test "config_exists false when no config" {
    rm -f "$CONFIG_FILE"
    run config_exists
    [[ "$status" -ne 0 ]]
}

@test "config_init creates config from example" {
    # Create a minimal example
    EXAMPLE_DIR="${TEST_HOME}/example_dir"
    mkdir -p "$EXAMPLE_DIR"
    echo 'GIT_PERSONAL_NAME="Test"' > "${EXAMPLE_DIR}/easywork.conf.example"
    CONFIG_EXAMPLE="${EXAMPLE_DIR}/easywork.conf.example"
    config_init
    [[ -f "$CONFIG_FILE" ]]
}

# ── Managed Sections ─────────────────────────────────────────

@test "replace_managed_section creates new file with markers" {
    local testfile="${TEST_HOME}/managed_test"
    replace_managed_section "$testfile" "1.0.0" "content line 1"$'\n'"content line 2"
    [[ -f "$testfile" ]]
    grep -q ">>> EasyWork managed section" "$testfile"
    grep -q "<<< EasyWork managed section end <<<" "$testfile"
    grep -q "content line 1" "$testfile"
}

@test "replace_managed_section preserves user content outside markers" {
    local testfile="${TEST_HOME}/managed_test2"
    echo "user content before" > "$testfile"
    echo "# >>> EasyWork managed section begin (v1.0.0) >>>" >> "$testfile"
    echo "old managed content" >> "$testfile"
    echo "# <<< EasyWork managed section end <<<" >> "$testfile"
    echo "user content after" >> "$testfile"

    replace_managed_section "$testfile" "2.0.0" "new managed content"

    grep -q "user content before" "$testfile"
    grep -q "user content after" "$testfile"
    grep -q "new managed content" "$testfile"
    ! grep -q "old managed content" "$testfile"
}

# ── Module Registry ──────────────────────────────────────────

@test "register_module and module_registered" {
    register_module "testmod" "Test Module" 10
    run module_registered "testmod"
    [[ "$status" -eq 0 ]]
}

@test "module_registered false for unknown" {
    run module_registered "nonexistent_mod"
    [[ "$status" -ne 0 ]]
}

@test "register_module rejects reserved names" {
    run register_module "install" "bad module"
    [[ "$status" -ne 0 ]]
}

# ── Exit Codes ───────────────────────────────────────────────

@test "exit codes are defined" {
    [[ "$EXIT_SUCCESS" -eq 0 ]]
    [[ "$EXIT_ERROR" -eq 1 ]]
    [[ "$EXIT_MISSING_DEPS" -eq 2 ]]
    [[ "$EXIT_NETWORK" -eq 3 ]]
}
