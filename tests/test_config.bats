#!/usr/bin/env bats
# Tests for config file management

setup() {
    load helpers/mocks
    setup_mocks
    EASYWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "${EASYWORK_ROOT}/lib/common.sh"
    # Setup example config for init tests
    mkdir -p "${TEST_HOME}/example_dir"
    cat > "${TEST_HOME}/example_dir/easywork.conf.example" << 'EOF'
GIT_PERSONAL_NAME="Test Person"
GIT_PERSONAL_EMAIL="test@example.com"
GIT_WORK_NAME="Test Work"
GIT_WORK_EMAIL="work@example.com"
EOF
    CONFIG_EXAMPLE="${TEST_HOME}/example_dir/easywork.conf.example"
}

teardown() { teardown_mocks; }

@test "config_init creates config when missing" {
    rm -f "$CONFIG_FILE"
    config_init
    [[ -f "$CONFIG_FILE" ]]
}

@test "config_init loads config variables" {
    rm -f "$CONFIG_FILE"
    config_init
    [[ "${GIT_PERSONAL_NAME:-}" == "Test Person" ]]
    [[ "${GIT_PERSONAL_EMAIL:-}" == "test@example.com" ]]
}

@test "config_load reads existing config" {
    echo 'GIT_PERSONAL_NAME="Loaded Name"' > "$CONFIG_FILE"
    echo 'GIT_PERSONAL_EMAIL="loaded@test.com"' >> "$CONFIG_FILE"
    config_load
    [[ "$GIT_PERSONAL_NAME" == "Loaded Name" ]]
}

@test "config_show outputs path" {
    echo "dummy" > "$CONFIG_FILE"
    run config_show
    [[ "$output" =~ ".easywork.conf" ]]
}
