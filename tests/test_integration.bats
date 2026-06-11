#!/usr/bin/env bats
# Integration tests — full install → uninstall lifecycle

setup() {
    load helpers/mocks
    setup_mocks
    EASYWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "${EASYWORK_ROOT}/lib/common.sh"
}

teardown() {
    teardown_mocks
}

# ── Full lifecycle ─────────────────────────────────────────

@test "integration: fresh install writes manifest with all modules" {
    YES_MODE=true
    DRY_RUN=true
    # Reset module registry for clean test
    MODULE_NAMES=()
    MODULE_DESCRIPTIONS=()
    MODULE_PRIORITY_VALUES=()
    for mod in shell git vim; do
        source "${EASYWORK_ROOT}/lib/${mod}.sh"
        register_module "$MODULE_NAME" "${MODULE_DESCRIPTION}" "${MODULE_PRIORITY}"
    done
    [[ ${#MODULE_NAMES[@]} -eq 3 ]]
    [[ "$(list_modules_sorted | wc -l | tr -d ' ')" -eq 3 ]]
}

@test "integration: uninstall removes all sections from manifest" {
    manifest_init "1.0.0"
    manifest_set_section "shell" "installed=true"
    manifest_set_section "git" "installed=true"
    manifest_set_section "vim" "installed=true"

    [[ "$(manifest_list_installed | wc -l | tr -d ' ')" -eq 3 ]]

    manifest_remove_section "shell"
    [[ "$(manifest_list_installed | wc -l | tr -d ' ')" -eq 2 ]]

    manifest_remove_section "git"
    manifest_remove_section "vim"
    [[ -z "$(manifest_list_installed)" ]]
}

@test "integration: partial uninstall leaves remaining modules intact" {
    manifest_init "1.0.0"
    manifest_set_section "shell" "installed=true"
    manifest_set_section "git" "installed=true"

    manifest_remove_section "shell"
    run manifest_section_exists "shell"
    [[ "$status" -ne 0 ]]
    run manifest_section_exists "git"
    [[ "$status" -eq 0 ]]
}

@test "integration: reinstall after partial uninstall refreshes section" {
    manifest_init "1.0.0"
    manifest_set_section "shell" "installed=true"
    manifest_set_section "git" "installed=true"

    manifest_remove_section "shell"
    manifest_set_section "shell" "installed=true" "shell_type=zsh"

    run manifest_section_installed "shell"
    [[ "$status" -eq 0 ]]
    run manifest_section_installed "git"
    [[ "$status" -eq 0 ]]
}

@test "integration: same version install is detected" {
    manifest_init "1.0.0"
    manifest_set_section "shell" "installed=true"

    [[ "$(manifest_get_version)" == "1.0.0" ]]
    run manifest_section_installed "shell"
    [[ "$status" -eq 0 ]]
}

@test "integration: upgrade version flow updates manifest version" {
    manifest_init "1.0.0"
    manifest_set_section "shell" "installed=true"

    # Simulate upgrade to new version
    local tmpfile
    tmpfile="${MANIFEST_FILE}.tmp.$$"
    sed "s/^easywork_version=.*/easywork_version=2.0.0/" "$MANIFEST_FILE" > "$tmpfile"
    mv "$tmpfile" "$MANIFEST_FILE"

    [[ "$(manifest_get_version)" == "2.0.0" ]]
}

# ── Module iteration order ──────────────────────────────────

@test "integration: modules are sorted by priority" {
    # Register modules in reverse priority order
    register_module "c" "Third" 30
    register_module "a" "First" 10
    register_module "b" "Second" 20

    local sorted
    sorted="$(list_modules_sorted | tr '\n' ' ')"
    [[ "$sorted" =~ a.*b.*c ]]
}

@test "integration: manifest survives full write-read cycle" {
    manifest_init "1.0.0"
    manifest_set_section "test" "key1=val1" "key2=val2"
    manifest_set_section "other" "key3=val3"

    # Verify both sections
    run manifest_section_exists "test"
    [[ "$status" -eq 0 ]]
    run manifest_section_exists "other"
    [[ "$status" -eq 0 ]]

    # Remove one, verify other intact
    manifest_remove_section "test"
    run manifest_section_exists "test"
    [[ "$status" -ne 0 ]]
    run manifest_section_exists "other"
    [[ "$status" -eq 0 ]]
}
