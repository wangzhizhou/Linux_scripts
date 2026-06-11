#!/usr/bin/env bats
# Tests for version and update functionality

setup() {
    load helpers/mocks
    setup_mocks
    EASYWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "${EASYWORK_ROOT}/lib/common.sh"
}

teardown() { teardown_mocks; }

@test "update: manifest_get_version reads version" {
    manifest_init "1.5.0"
    result="$(manifest_get_version)"
    [[ "$result" == "1.5.0" ]]
}

@test "update: manifest_get_version returns default when no manifest" {
    manifest_clear
    result="$(manifest_get_version)"
    [[ "$result" == "0.0.0" ]]
}

@test "update: version command shows version info" {
    run bash "${BATS_TEST_DIRNAME}/../bin/easywork" version
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "EasyWork" ]]
}

@test "update: check_network returns true for github.com" {
    # Skip if no real network
    skip "Requires network access"
    run check_network "github.com" 5
    [[ "$status" -eq 0 ]]
}

@test "update: safe_download captures url" {
    # Uses mock curl which returns 0
    run safe_download "https://example.com/test"
    [[ "$status" -eq 0 ]]
}
