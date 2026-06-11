#!/usr/bin/env bats
# Tests for Shell configuration module

setup() {
    load helpers/mocks
    setup_mocks
    EASYWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "${EASYWORK_ROOT}/lib/common.sh"
    source "${EASYWORK_ROOT}/lib/shell.sh"
}

teardown() { teardown_mocks; }

@test "shell: module variables are set" {
    [[ "$MODULE_NAME" == "shell" ]]
    [[ -n "$MODULE_DESCRIPTION" ]]
}

@test "shell: module_check false when not installed" {
    rm -f "$SH_CONFIG_FILE"
    run module_check
    [[ "$status" -ne 0 ]]
}

@test "shell: module_check true when installed with markers" {
    mkdir -p "$(dirname "$SH_CONFIG_FILE")"
    echo "# >>> EasyWork managed section begin (v1.0.0) >>>" > "$SH_CONFIG_FILE"
    echo "content" >> "$SH_CONFIG_FILE"
    echo "# <<< EasyWork managed section end <<<" >> "$SH_CONFIG_FILE"
    run module_check
    [[ "$status" -eq 0 ]]
}

@test "shell: module_status shows status" {
    run module_status
    [[ "$output" =~ "shell:" ]]
}

@test "shell: _detect_shell_rc returns a file path" {
    result="$(_detect_shell_rc)"
    [[ "$result" == *"/."* ]] || [[ "$result" == *"/bash"* ]]
}

@test "shell: _generate_shell_config contains expected content" {
    content="$(_generate_shell_config)"
    [[ "$content" =~ "alias g='git'" ]]
    [[ "$content" =~ "flushdns" ]]
    [[ "$content" =~ "net_list" ]]
    [[ "$content" =~ "vpn_start" ]]
    [[ "$content" =~ "vpn_restart" ]]
}

@test "shell: dry-run install does not create files" {
    DRY_RUN=true
    EASYWORK_VERSION="1.0.0"
    module_install
    [[ ! -f "$SH_CONFIG_FILE" ]]
}
