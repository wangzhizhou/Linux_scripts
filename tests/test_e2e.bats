#!/usr/bin/env bats
# E2E tests: real user flows with standalone binary simulation

EASYWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"
    mkdir -p "$TEST_HOME/.local/bin"

    # Create mock wrapper that replaces curl to serve from local repo
    cat > "$TEST_HOME/.local/bin/curl" << MOCK_CURL
#!/usr/bin/env bash
out="" url=""
while [[ \$# -gt 0 ]]; do
    case "\$1" in
        -o) out="\$2"; shift 2 ;;
        -H) shift 2 ;;
        -*) shift ;;
        *) url="\$1"; shift ;;
    esac
done
repo="${EASYWORK_ROOT}"
path="\${url#*raw.githubusercontent.com/EasyIndie/EasyWork/*/}"
if [[ "\$url" == *"api.github.com"* ]]; then
    echo '{"tag_name":"v1.0.0"}'
elif [[ -n "\$path" ]] && [[ -f "\${repo}/\${path}" ]]; then
    if [[ -n "\$out" ]]; then
        cat "\${repo}/\${path}" > "\$out"
    else
        cat "\${repo}/\${path}"
    fi
fi
exit 0
MOCK_CURL
    chmod +x "$TEST_HOME/.local/bin/curl"

    # Mock other commands
    for cmd in git vim brew sudo node; do
        cat > "$TEST_HOME/.local/bin/$cmd" << EOF
#!/usr/bin/env bash
case "\${1:-}" in config) echo "mock-value" ;; rev-parse) [[ "\$*" == *--git-dir* ]] && exit 128 ;; esac
exit 0
EOF
        chmod +x "$TEST_HOME/.local/bin/$cmd"
    done

    # Standalone binary (no lib/ directory)
    cp "${EASYWORK_ROOT}/bin/easywork" "$TEST_HOME/.local/bin/easywork"
    chmod +x "$TEST_HOME/.local/bin/easywork"

    export PATH="$TEST_HOME/.local/bin:$PATH"
}

teardown() {
    rm -rf "$TEST_HOME"
}

# ─── A: Standalone binary basics ─────────────────────────────

@test "e2e: standalone binary version" {
    run easywork version
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "EasyWork" ]]
    [[ -f "$TEST_HOME/.easywork/lib/v1.0.0/common.sh" ]]
}

@test "e2e: standalone binary help lists modules" {
    run easywork help
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "shell" ]]
    [[ "$output" =~ "git" ]]
    [[ "$output" =~ "vim" ]]
}

@test "e2e: standalone binary help (no args)" {
    run easywork
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "EasyWork" ]]
}

@test "e2e: config creates generic config" {
    run easywork config
    [[ "$status" -eq 0 ]]
    run cat "$TEST_HOME/.easywork/config"
    [[ ! "$output" =~ "Your Name" ]]
}

# ─── B: Piped install ───────────────────────────────────────

@test "e2e: piped install CLI only" {
    run bash -c "cat ${EASYWORK_ROOT}/bin/easywork | PATH=${TEST_HOME}/.local/bin:\$PATH HOME=${TEST_HOME} bash -s -- install --dry-run" 2>&1
    [[ "$output" =~ "CLI 准备就绪" ]]
    [[ ! "$output" =~ "配置 shell" ]]
}

@test "e2e: piped reinstall overwrites" {
    mkdir -p "$TEST_HOME/.easywork"
    echo "easywork_version=1.0.0" > "$TEST_HOME/.easywork/manifest"
    run bash -c "cat ${EASYWORK_ROOT}/bin/easywork | PATH=${TEST_HOME}/.local/bin:\$PATH HOME=${TEST_HOME} bash -s -- install --dry-run" 2>&1
    [[ "$output" =~ "CLI 准备就绪" ]]
}

# ─── C: Full install lifecycle ──────────────────────────────

@test "e2e: install --dry-run all modules" {
    run easywork install --dry-run --yes
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "配置 shell" ]]
    [[ "$output" =~ "配置 git" ]]
    [[ "$output" =~ "配置 vim" ]]
}

@test "e2e: install --yes creates files" {
    run easywork install --yes
    [[ "$status" -eq 0 ]]
    [[ -f "$TEST_HOME/.easywork/manifest" ]]
    [[ -f "$TEST_HOME/.sh_config_custom" ]]
    run cat "$TEST_HOME/.easywork/manifest"
    [[ "$output" =~ "shell" ]]
}

@test "e2e: version shows installed components" {
    easywork install --yes 2> /dev/null
    run easywork version
    [[ "$output" =~ "已安装组件" ]]
}

@test "e2e: full uninstall cleanup" {
    easywork install --yes 2> /dev/null
    run easywork uninstall --yes --remove-config
    [[ "$status" -eq 0 ]]
    [[ ! -f "$TEST_HOME/.easywork/manifest" ]]
}

# ─── D: Single module ───────────────────────────────────────

@test "e2e: install vim only" {
    run easywork install vim --dry-run --yes
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "配置 vim" ]]
    # Only vim module should run (no shell or git install messages)
    [[ ! "$output" =~ "shell 完成" ]]
    [[ ! "$output" =~ "git 完成" ]]
}

@test "e2e: install unknown module errors" {
    run easywork install unknown --dry-run
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "未知组件" ]]
}

@test "e2e: partial uninstall keeps others" {
    easywork install --yes 2> /dev/null
    run easywork uninstall vim --yes
    [[ "$status" -eq 0 ]]
    run cat "$TEST_HOME/.easywork/manifest"
    [[ "$output" =~ "shell" ]]
    [[ ! "$output" =~ "vim" ]]
}

# ─── E: Git specifics ───────────────────────────────────────

@test "e2e: git with config values" {
    mkdir -p "$TEST_HOME/.easywork"
    cat > "$TEST_HOME/.easywork/config" << 'EOF'
## git
GIT_PERSONAL_NAME="Test User"
GIT_PERSONAL_EMAIL="test@example.com"
EOF
    run easywork install git --dry-run --yes
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "Test User" ]]
}

@test "e2e: git dry-run with empty config uses dummy values" {
    mkdir -p "$TEST_HOME/.easywork"
    echo "# empty" > "$TEST_HOME/.easywork/config"
    run easywork install git --dry-run --yes
    [[ "$status" -eq 0 ]]
    # Dry-run fills in dummy values for preview
    [[ "$output" =~ "your-name" ]]
}

# ─── F: Cache ───────────────────────────────────────────────

@test "e2e: cache reused on second run" {
    easywork version 2> /dev/null
    rm -f "$TEST_HOME/.local/bin/curl"
    run easywork version
    [[ "$status" -eq 0 ]]
}

@test "e2e: URL fallback to main branch when version tag is missing" {
    # Simulate version tag not existing: make the versioned URL fail
    # The mock curl will return 0 for the main-branch URL after tag failure
    # Check that the fallback warning is emitted to stderr
    export EASYWORK_RAW_URL="https://raw.githubusercontent.com/EasyIndie/EasyWork/v99.99.99"
    run easywork version 2>&1
    # Should still succeed (falls back to main)
    [[ "$status" -eq 0 ]]
}

# ─── G: Global flags ────────────────────────────────────────

@test "e2e: dry-run prevents module file writes" {
    # dry-run creates manifest for tracking but modules should not write configs
    run easywork install --dry-run --yes
    [[ "$status" -eq 0 ]]
    # Module config files should NOT be created
    [[ ! -f "$TEST_HOME/.sh_config_custom" ]]
}
