#!/usr/bin/env bats
# Tests for Vim configuration module

setup() {
    load helpers/mocks
    setup_mocks
    EASYWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "${EASYWORK_ROOT}/lib/common.sh"
    source "${EASYWORK_ROOT}/lib/vim.sh"
}

teardown() { teardown_mocks; }

@test "vim: module variables are set" {
    [[ "$MODULE_NAME" == "vim" ]]
    [[ -n "$MODULE_DESCRIPTION" ]]
}

@test "vim: module_check false when not installed" {
    rm -f "$VIMRC_FILE"
    run module_check
    [[ "$status" -ne 0 ]]
}

@test "vim: _generate_vimrc contains plugins" {
    content="$(_generate_vimrc)"
    [[ "$content" =~ "NERDTree" ]]
    [[ "$content" =~ "coc.nvim" ]]
    [[ "$content" =~ "fzf" ]]
    [[ "$content" =~ "vim-airline" ]]
    [[ "$content" =~ "ale" ]]
}

@test "vim: _generate_vimrc contains key mappings" {
    content="$(_generate_vimrc)"
    [[ "$content" =~ "<C-n>" ]]
    [[ "$content" =~ "gd <Plug>(coc-definition)" ]]
    [[ "$content" =~ "MarkdownPreview" ]]
}

@test "vim: dry-run install does not create config" {
    DRY_RUN=true
    EASYWORK_VERSION="1.0.0"
    rm -f "$VIMRC_FILE"
    module_install
    [[ ! -f "$VIMRC_FILE" ]]
}
