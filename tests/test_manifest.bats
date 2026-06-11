#!/usr/bin/env bats
# Tests for manifest edge cases

setup() {
    load helpers/mocks
    setup_mocks
    EASYWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "${EASYWORK_ROOT}/lib/common.sh"
}

teardown() { teardown_mocks; }

@test "manifest_read returns default for missing key" {
    manifest_init "1.0.0"
    result="$(manifest_read 'nonexistent' 'default_val')"
    [[ "$result" == "default_val" ]]
}

@test "manifest_section_exists detects section" {
    manifest_init "1.0.0"
    manifest_set_section "example" "installed=true"
    run manifest_section_exists "example"
    [[ "$status" -eq 0 ]]
}

@test "manifest_section_exists false for missing section" {
    manifest_init "1.0.0"
    run manifest_section_exists "no_such_section"
    [[ "$status" -ne 0 ]]
}

@test "manifest_section_installed true" {
    manifest_init "1.0.0"
    manifest_set_section "active" "installed=true"
    run manifest_section_installed "active"
    [[ "$status" -eq 0 ]]
}

@test "manifest works with empty sections" {
    manifest_init "1.0.0"
    manifest_set_section "empty"
    grep -q "\[empty\]" "$MANIFEST_FILE"
}

@test "manifest survives write-read cycle" {
    manifest_init "1.0.0"
    manifest_set_section "a" "key1=val1" "key2=val2"
    manifest_set_section "b" "key3=val3"
    # Remove and re-add
    manifest_remove_section "a"
    manifest_set_section "a" "key1=newval"
    grep -q "key1=newval" "$MANIFEST_FILE"
    grep -q "key3=val3" "$MANIFEST_FILE"
}

@test "manifest_clear removes file" {
    manifest_init "1.0.0"
    manifest_clear
    [[ ! -f "$MANIFEST_FILE" ]]
}
