#!/usr/bin/env bash
# EasyWork — Test Helpers & Mocks

# ── Setup / Teardown ─────────────────────────────────────────
# Override HOME to a temp directory so tests don't touch real config
export TEST_HOME="${BATS_TMPDIR:-/tmp}/easywork_test_home"
export HOME="$TEST_HOME"

# EasyWork variables expected by modules
export EASYWORK_VERSION="1.0.0"
export DRY_RUN=false
export YES_MODE=false
export VERBOSE=false

# Mock functions that modules call but tests shouldn't execute
setup_mocks() {
    mkdir -p "$TEST_HOME"

    # Override manifest and config paths
    export MANIFEST_FILE="${TEST_HOME}/.easywork.manifest"
    export CONFIG_FILE="${TEST_HOME}/.easywork.conf"
    export SH_CONFIG_FILE="${TEST_HOME}/.sh_config_custom"
    export GIT_CONFIG_FILE="${TEST_HOME}/.gitconfig"
    export VIMRC_FILE="${TEST_HOME}/.vimrc"
    export VIM_DIR="${TEST_HOME}/.vim"
    export TEMP_DIR="${TEST_HOME}/tmp"
    mkdir -p "$TEMP_DIR"
    export TMPDIR="$TEMP_DIR"

    # Mock curl: capture calls instead of making real network requests
    function curl() {
        echo "MOCK_CURL: $*" >> "${TEST_HOME}/mock_curl.log"
        return 0
    }

    # Mock git for non-destructive testing
    function git() {
        case "${1:-}" in
            config)
                echo "mock-value"
                ;;
            symbolic-ref)
                echo "main"
                ;;
            --version)
                echo "git version 2.40.0"
                ;;
            *)
                echo "MOCK_GIT: $*" >> "${TEST_HOME}/mock_git.log"
                ;;
        esac
        return 0
    }

    # Mock vim for non-interactive testing
    function vim() {
        echo "MOCK_VIM: $*" >> "${TEST_HOME}/mock_vim.log"
        return 0
    }

    # Mock brew
    function brew() {
        echo "MOCK_BREW: $*" >> "${TEST_HOME}/mock_brew.log"
        return 0
    }

    # Mock sudo
    function sudo() {
        shift 2>/dev/null || true
        echo "MOCK_SUDO: $*" >> "${TEST_HOME}/mock_sudo.log"
        return 0
    }

    # Mock node
    function node() {
        echo "v18.0.0"
        return 0
    }

    # Mock networksetup (macOS)
    function networksetup() {
        echo "MOCK_NETWORKSETUP: $*" >> "${TEST_HOME}/mock_networksetup.log"
        return 0
    }

    # Mock scutil (macOS)
    function scutil() {
        echo "MOCK_SCUTIL: $*" >> "${TEST_HOME}/mock_scutil.log"
        return 0
    }

    export -f curl git vim brew sudo node networksetup scutil 2>/dev/null || true
}

teardown_mocks() {
    rm -rf "$TEST_HOME"
}
