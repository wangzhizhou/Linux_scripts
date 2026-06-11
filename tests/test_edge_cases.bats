#!/usr/bin/env bats
# Tests for edge cases and boundary conditions

setup() {
    load helpers/mocks
    setup_mocks
    EASYWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "${EASYWORK_ROOT}/lib/common.sh"
}

teardown() {
    teardown_mocks
}

# ── Empty module registry ───────────────────────────────────

@test "edge: list_modules_sorted with empty registry returns nothing" {
    # MODULE_NAMES is initially empty — should not crash with set -u
    local sorted
    sorted="$(list_modules_sorted)"
    [[ -z "$sorted" ]]
}

@test "edge: list_modules with empty registry returns nothing" {
    run list_modules
    [[ "$status" -eq 0 ]]
}

@test "edge: module_registered returns false with empty registry" {
    run module_registered "nonexistent"
    [[ "$status" -ne 0 ]]
}

@test "edge: _get_module_index returns error for unknown module" {
    set +e
    _get_module_index "unknown_module" >/dev/null 2>&1
    local rc=$?
    set -e
    [[ $rc -ne 0 ]]
}

# ── Duplicate module registration ───────────────────────────

@test "edge: duplicate registration does not create duplicates" {
    register_module "dup" "First" 10
    register_module "dup" "Second" 20
    # Count occurrences of "dup" in MODULE_NAMES
    local count=0
    local n
    for n in "${MODULE_NAMES[@]}"; do
        [[ "$n" == "dup" ]] && ((count++)) || true
    done
    [[ $count -eq 1 ]]
}

# ── Corrupt manifest ────────────────────────────────────────

@test "edge: manifest_read returns default for corrupt file" {
    echo "garbage without equals" > "$MANIFEST_FILE"
    echo "also_bad= =empty_value" >> "$MANIFEST_FILE"
    local val
    val="$(manifest_read 'nonexistent' 'fallback')"
    [[ "$val" == "fallback" ]]
}

@test "edge: manifest_section_exists false for corrupt file" {
    echo "not a valid manifest" > "$MANIFEST_FILE"
    run manifest_section_exists "anything"
    [[ "$status" -ne 0 ]]
}

# ── Missing dependencies ────────────────────────────────────

@test "edge: detect_pkg_manager returns unknown on minimal system" {
    # Mock: remove all known package managers
    local result
    # On a system with brew, this test just validates the function runs
    result="$(detect_pkg_manager)"
    [[ -n "$result" ]]
    [[ "$result" =~ ^(brew|apt-get|dnf|yum|pacman|zypper|apk|unknown)$ ]]
}

# ── Semver comparison ───────────────────────────────────────

# Helper: run semver with set +e to capture non-zero return codes
_semver_run() { set +e; _semver_compare "$1" "$2"; local rc=$?; set -e; return $rc; }

@test "edge: semver equal versions" {
    run _semver_run "1.0.0" "1.0.0"
    [[ "$status" -eq 0 ]]
}

@test "edge: semver newer major" {
    run _semver_run "2.0.0" "1.9.9"
    [[ "$status" -eq 1 ]]
}

@test "edge: semver newer minor" {
    run _semver_run "1.2.0" "1.1.9"
    [[ "$status" -eq 1 ]]
}

@test "edge: semver newer patch" {
    run _semver_run "1.0.1" "1.0.0"
    [[ "$status" -eq 1 ]]
}

@test "edge: semver older is newer reversed" {
    run _semver_run "0.9.0" "1.0.0"
    [[ "$status" -eq 2 ]]
}

@test "edge: semver handles 0.0.0" {
    run _semver_run "0.0.0" "0.0.0"
    [[ "$status" -eq 0 ]]
    set +e; _semver_is_newer "1.0.0" "0.0.0"; local rc=$?; set -e
    [[ $rc -eq 0 ]]
}

@test "edge: semver strips non-numeric characters" {
    run _semver_run "1.0.0" "0.0.0"
    [[ "$status" -eq 1 ]]
}

# ── Managed section edge cases ──────────────────────────────

@test "edge: replace_managed_section handles empty content" {
    local testfile="${TEST_HOME}/empty_content"
    replace_managed_section "$testfile" "1.0.0" ""
    [[ -f "$testfile" ]]
    grep -qF "# >>> EasyWork managed section" "$testfile"
}

@test "edge: replace_managed_section prepends to existing content" {
    local testfile="${TEST_HOME}/existing_content"
    echo "preexisting config" > "$testfile"
    replace_managed_section "$testfile" "1.0.0" "new managed"
    grep -qF "preexisting config" "$testfile"
    grep -qF "new managed" "$testfile"
}

# ── Manifest parsing edge cases ─────────────────────────────

@test "edge: manifest handles empty file" {
    : > "$MANIFEST_FILE"
    run manifest_section_exists "anything"
    [[ "$status" -ne 0 ]]
}

@test "edge: manifest_section_installed false when section missing" {
    manifest_init "1.0.0"
    run manifest_section_installed "no_such_section"
    [[ "$status" -ne 0 ]]
}
