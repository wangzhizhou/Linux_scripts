#!/usr/bin/env bats
# Tests for Git configuration module

setup() {
    load helpers/mocks
    setup_mocks
    EASYWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "${EASYWORK_ROOT}/lib/common.sh"
    source "${EASYWORK_ROOT}/lib/git.sh"
    # Setup test config
    cat > "$CONFIG_FILE" <<'EOF'
GIT_PERSONAL_NAME="Test User"
GIT_PERSONAL_EMAIL="test@example.com"
GIT_WORK_NAME="Work User"
GIT_WORK_EMAIL="work@example.com"
EOF
    config_load
}

teardown() { teardown_mocks; }

@test "git: module variables are set" {
    [[ "$MODULE_NAME" == "git" ]]
    [[ -n "$MODULE_DESCRIPTION" ]]
}

@test "git: module_check false when not installed" {
    rm -f "$GIT_CONFIG_FILE"
    run module_check
    [[ "$status" -ne 0 ]]
}

@test "git: _validate_email accepts valid emails" {
    run _validate_email "user@example.com"
    [[ "$status" -eq 0 ]]
    run _validate_email "user.name+tag@domain.co.uk"
    [[ "$status" -eq 0 ]]
}

@test "git: _validate_email rejects invalid emails" {
    run _validate_email "not-an-email"
    [[ "$status" -ne 0 ]]
    run _validate_email ""
    [[ "$status" -ne 0 ]]
}

@test "git: _validate_name rejects shell metacharacters" {
    run _validate_name "name\`evil\`"
    [[ "$status" -ne 0 ]]
    run _validate_name "name\$(bad)"
    [[ "$status" -ne 0 ]]
}

@test "git: _validate_name accepts normal names" {
    run _validate_name "John Doe"
    [[ "$status" -eq 0 ]]
}

@test "git: _generate_git_config contains aliases" {
    content="$(_generate_git_config)"
    [[ "$content" =~ "l = log" ]]
    [[ "$content" =~ "alias" ]]
    [[ "$content" =~ "submodule" ]]
    [[ "$content" =~ "worktree" ]]
}

@test "git: dry-run install does not create config" {
    DRY_RUN=true
    EASYWORK_VERSION="1.0.0"
    YES_MODE=true
    rm -f "$GIT_CONFIG_FILE"
    module_install
    [[ ! -f "$GIT_CONFIG_FILE" ]]
}
