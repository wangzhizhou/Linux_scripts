# EasyWork

[![CI](https://github.com/EasyIndie/EasyWork/actions/workflows/ci.yml/badge.svg)](https://github.com/EasyIndie/EasyWork/actions/workflows/ci.yml)
[![Release](https://github.com/EasyIndie/EasyWork/actions/workflows/release.yml/badge.svg)](https://github.com/EasyIndie/EasyWork/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**一条命令，配置好你的开发环境。**

EasyWork 是一个 macOS / Linux 开发环境一键配置工具。首次接触新机器时，执行一条命令即可完成 Shell 环境、Git 配置、Vim IDE 的全套设置，告别重复的手动配置。

---

## 快速开始

```bash
# 一键安装（自动下载并运行）
curl -sL https://raw.githubusercontent.com/EasyIndie/EasyWork/main/bin/easywork | bash

# 然后开始配置你的环境
easywork install
```

> 需要：macOS 或 Linux，bash 或 zsh，已安装 curl 和 git。

---

## 目录

- [CLI 使用指南](#cli-使用指南)
- [模块功能详解](#模块功能详解)
  - [Shell 模块](#shell-模块)
  - [Git 模块](#git-模块)
  - [Vim 模块](#vim-模块)
- [配置说明](#配置说明)
- [目录结构](#目录结构)
- [Makefile 命令](#makefile-命令)
- [从零开始](#从零开始)
- [卸载](#卸载)
- [贡献](#贡献)
- [许可证](#许可证)

---

## CLI 使用指南

```
easywork <命令> [参数] [选项]
```

### 命令

| 命令 | 说明 |
|---|---|
| `install` | 一键安装全部组件 |
| `install <模块名>` | 只安装指定组件（如 `easywork install git`） |
| `uninstall` | 卸载全部组件 |
| `uninstall <模块名>` | 卸载指定组件 |
| `config` | 查看配置文件内容及元信息 |
| `config edit` | 编辑配置文件（`~/.easywork/config`） |
| `version` | 查看版本、安装日期和已安装组件 |
| `update` | 检查并升级到最新版本 |
| `help` | 显示帮助信息 |
| `<模块名>` | 模块快捷命令，直接安装该组件 |

### 全局选项

| 选项 | 说明 |
|---|---|
| `--dry-run` | 预览变更，不实际执行 |
| `--yes`, `-y` | 跳过交互确认 |
| `--verbose`, `-v` | 详细输出 |
| `--keep-config` | 卸载时保留配置文件 |
| `--remove-config` | 卸载时移除配置文件 |

---

## 模块功能详解

### Shell 模块

配置 Shell 环境，兼容 **bash** 和 **zsh**，写入 `~/.sh_config_custom`。

**环境设置：**
- 设置 `LC_ALL=en_US.UTF-8`、`LANG=en_US.UTF-8`
- 启用 `CLICOLOR=1`
- bash 启用 bracketed paste 模式
- 导出 `$BLACK` / `$RED` / `$GREEN` / `$YELLOW` / `$BLUE` / `$PURPLE` / `$CYAN` / `$WHITE` / `$RESET` 颜色变量

**命令提示符：**
- 彩色 `user@host:path` 显示
- 自动显示当前 Git 分支和上游跟踪信息
- bash（PS1）和 zsh（PROMPT）统一风格，带有 cat ASCII 艺术标识

**系统别名：**

| 别名 | 指向 |
|---|---|
| `grep` | `grep --color=auto` |
| `mv` | `mv -i` |
| `cp` | `cp -i` |
| `rm` | `rm -i` |
| `q` | `exit` |
| `g` | `git` |

**FFmpeg 简写：**

| 别名 | 指向 |
|---|---|
| `ff` | `ffmpeg` |
| `fp` | `ffplay` |
| `fb` | `ffprobe` |
| `fs` | `ffserver` |

**Swift / 工具别名：**
- `spm` → `swift package`
- `run <N> <命令>` — 重复执行命令 N 次

**macOS 网络工具：**
- `flushdns` — 刷新 DNS 缓存（`dscacheutil -flushcache` + `killall -HUP mDNSResponder`）
- `net_list` — 列出所有网络服务
- `net_enable <名称>` — 启用网络服务
- `net_disable <名称>` — 禁用网络服务
- `net_stat <名称>` — 查看网络服务状态

**macOS VPN 工具：**
- `vpn_list` — 列出所有 VPN
- `vpn_start <名称>` — 启动 VPN
- `vpn_stop <名称>` — 停止 VPN
- `vpn_stat` / `vpn <名称>` — 检查 VPN 状态
- `vpn_restart <名称>` — 重启 VPN

**其他功能：**
- `sys_info` — 显示硬件和软件信息（macOS，通过 `system_profiler`）
- 自动安装 Oh My Zsh（如使用 zsh 且未安装）

---

### Git 模块

一站式配置 Git：身份、全局配置项、Git 别名（共 **25 类、80+ 个别名**）。

**身份管理：**
- 支持三种身份选择：
  - **personal** — 从配置读取个人姓名/邮箱
  - **work** — 从配置读取工作姓名/邮箱
  - **custom** — 运行时手动输入
- 支持全局（`~/.gitconfig`）和本地仓库两种作用域
- 输入校验：检查 shell 特殊字符、邮箱格式
- 自动备份已有 `~/.gitconfig`

**全局配置项：**

| 配置 | 值 |
|---|---|
| `diff.submodule` | `log` |
| `pager.branch` | `false` |
| `pull.rebase` | `false` |
| `color.ui` | `auto` |

**Git 别名（完整列表）：**

<details>
<summary>📋 点击展开 80+ 个别名</summary>

| 类别 | 别名 | 说明 |
|---|---|---|
| **配置** | `cfg` | 编辑全局配置 |
| | `cfl` | 列出配置列表 |
| | `cfs` | 按正则搜索配置 |
| | `cfw` | 写入配置项 |
| **日志** | `l` | 美化的一行日志 |
| | `la` | 按作者过滤日志 |
| | `lm` | 按日期过滤（since） |
| | `lma` | 按日期过滤（after） |
| | `lc` | 简短统计日志 |
| | `lg` | 图形化日志 |
| | `lgs` | 简短图形化日志 |
| | `lgt` | 带标签的图形化日志 |
| | `lgb` | 所有分支图形化日志 |
| | `lgr` | 远程日志 |
| | `lgtg` | 标签间日志 |
| **分支** | `b` | 列出分支 |
| | `br` | 重命名分支 |
| | `bv` | 详细分支信息 |
| | `bd` | 删除分支 |
| | `bD` | 强制删除分支 |
| | `bu` | 设置上游分支 |
| **拉取/推送** | `pl` | 拉取 |
| | `plrs` | 拉取（含子模块，--ff-only） |
| | `plrb` | 拉取并 rebase |
| | `pu` | 推送 |
| | `pm` | 推送镜像 |
| | `po` | 推送 origin |
| | `pof` | 强制推送 |
| | `pofs` | 带租约的强制推送 |
| | `poh` | 推送 HEAD |
| | `pot` | 推送标签 |
| | `poa` | 推送全部 |
| **提交** | `a` | `git add` |
| | `c` | `git commit` |
| | `ca` | 修改上次提交 |
| | `cm` | 带消息提交 |
| **检出** | `co` | 检出 |
| | `cb` | 检出新分支 |
| **克隆** | `cl` | 克隆 |
| | `cdf` | `git clean -df` |
| | `clrs` | 递归克隆（含子模块） |
| **Cherry-pick** | `pk` | 拣选提交 |
| | `pkc` | 继续拣选 |
| | `pka` | 终止拣选 |
| **Diff** | `d` | 查看 diff |
| | `dsm` | 子模块 diff |
| **合并** | `m` | 合并 |
| | `mc` | 继续合并 |
| | `ma` | 终止合并 |
| **状态** | `s` | 状态 |
| | `ss` | 简短状态 |
| **Stash** | `st` | 暂存 |
| | `sl` | 列出暂存 |
| | `sp` | 弹出暂存 |
| **标签** | `t` | 创建标签 |
| | `tl` | 列出标签 |
| | `td` | 删除标签 |
| **子模块** | `sm` | 子模块 |
| | `smi` | 初始化子模块 |
| | `smu` | 更新子模块 |
| | `sms` | 同步子模块 |
| | `smur` | 远程更新子模块 |
| **远程** | `r` | 列出远程 |
| | `ra` | 添加远程 |
| | `rv` | 查看远程详情 |
| | `rp` | 清理远程引用 |
| | `rpo` | 清理 origin 远程 |
| **恢复/重置** | `dp` | 放弃工作区修改 |
| | `re` | 恢复文件 |
| | `rst` | 重置 |
| | `rsth` | 硬重置到 HEAD |
| | `rvt` | 还原提交 |
| | `ic` | assume-unchanged |
| | `uic` | no-assume-unchanged |
| **Rebase** | `rb` | 变基 |
| | `rbc` | 继续变基 |
| | `rba` | 终止变基 |
| | `rbi` | 交互式变基 |
| | `rbir` | 交互式变基到根提交 |
| **Worktree** | `wt` | 工作树 |
| | `wta` | 添加工作树 |
| | `wtl` | 列出工作树 |
| | `wtr` | 移除工作树 |
| | `wtm` | 移动工作树 |
| | `wtp` | 清理工作树 |
| **补丁** | `fp` | 创建补丁 |
| | `fp1` | 创建最后一次提交的补丁 |
| | `ap` | 应用补丁（am） |
| **杂项** | `h` | 帮助/命令列表 |
| | `sh` | 显示 HEAD |

</details>

---

### Vim 模块

将 Vim 配置为功能完备的 IDE，写入 `~/.vimrc`，通过 vim-plug 管理 **19 个插件**。

**自动安装依赖：**
- **Node.js** — 缺失时自动安装（macOS 优先 Homebrew，否则通过 nvm 安装 LTS）
- **ripgrep** — 缺失时自动安装（支持 Homebrew、apt、dnf、yum、pacman、zypper、apk、cargo）
- **vim-plug** — 自动从 GitHub 下载

**编辑设置：**

| 类别 | 设置 |
|---|---|
| 基础 | `backspace=indent,eol,start`、`encoding=utf-8` |
| 备份 | `nobackup`、`noswapfile`、`undofile`（目录 `~/.vim/undo`） |
| 行号与光标 | `number`、`nowrap`、`ruler`、`cursorline` |
| 缩进 | `cindent`、`tabstop=4`、`shiftwidth=4`、`expandtab`、`smartindent`、`autoindent` |
| 搜索 | `ignorecase`、`smartcase`、`hlsearch`、`incsearch` |
| 显示 | `showmode`、`nofoldenable`、`splitbelow`、`splitright`、`clipboard=unnamedplus`、`mouse=a`、`termguicolors`、`signcolumn=yes` |
| 主题 | `syntax enable`、`background=dark`、colorscheme `murphy` |

**插件列表：**

<details>
<summary>📋 点击展开 19 个插件</summary>

| 类别 | 插件 | 说明 |
|---|---|---|
| **文件树** | [preservim/nerdtree](https://github.com/preservim/nerdtree) | 文件浏览器 (`<C-n>` 切换) |
| | [Xuyuanp/nerdtree-git-plugin](https://github.com/Xuyuanp/nerdtree-git-plugin) | 文件树 Git 状态指示器 |
| **状态栏** | [vim-airline/vim-airline](https://github.com/vim-airline/vim-airline) | 美观的状态栏 |
| | [vim-airline/vim-airline-themes](https://github.com/vim-airline/vim-airline-themes) | Airline 主题（papercolor） |
| **Git** | [tpope/vim-fugitive](https://github.com/tpope/vim-fugitive) | Git 集成 |
| | [airblade/vim-gitgutter](https://github.com/airblade/vim-gitgutter) | 侧边栏 Git diff 标记 |
| **注释** | [tpope/vim-commentary](https://github.com/tpope/vim-commentary) | 快速注释/取消注释 |
| **Markdown** | [preservim/vim-markdown](https://github.com/preservim/vim-markdown) | Markdown 语法高亮 |
| | [iamcco/markdown-preview.nvim](https://github.com/iamcco/markdown-preview.nvim) | 浏览器 Markdown 实时预览 |
| **HTML/CSS** | [mattn/emmet-vim](https://github.com/mattn/emmet-vim) | Emmet / Zen Coding |
| | [othree/html5.vim](https://github.com/othree/html5.vim) | HTML5 语法高亮 |
| | [hail2u/vim-css3-syntax](https://github.com/hail2u/vim-css3-syntax) | CSS3 语法高亮 |
| **JS/React** | [pangloss/vim-javascript](https://github.com/pangloss/vim-javascript) | JavaScript 语法高亮 |
| | [maxmellon/vim-jsx-pretty](https://github.com/maxmellon/vim-jsx-pretty) | JSX / React 语法高亮 |
| **代码检查** | [dense-analysis/ale](https://github.com/dense-analysis/ale) | 异步 Linting（ESLint + Stylelint） |
| **模糊搜索** | [junegunn/fzf](https://github.com/junegunn/fzf) | FZF 模糊查找器 |
| | [junegunn/fzf.vim](https://github.com/junegunn/fzf.vim) | FZF Vim 集成 |
| **代码补全** | [neoclide/coc.nvim](https://github.com/neoclide/coc.nvim) | LSP 驱动的代码补全（需 Node.js） |

</details>

**关键快捷键：**

| 快捷键 | 功能 |
|---|---|
| `<C-n>` | NERDTree 切换 |
| `gd` | 跳转到定义（coc.nvim） |
| `gr` | 查找引用（coc.nvim） |
| `gi` | 跳转到实现（coc.nvim） |
| `K` | 悬停文档（coc.nvim） |
| `<leader>mp` | Markdown 预览启动 |
| `<leader>ms` | Markdown 预览停止 |
| `<leader>mt` | Markdown 预览切换 |
| `<C-k>` / `<C-j>` | ALE 上下一条错误 |
| `<Tab>` / `<S-Tab>` | coc.nvim 补全弹出导航 |

> 注：`<leader>` 键已设置为空格键。

---

## 配置说明

EasyWork 的配置文件位于 `~/.easywork/config`。当你运行 `easywork git` 并选择 personal 或 work 身份后，EasyWork 会自动将身份信息写回该配置文件，下次无需重新输入。

示例配置内容：

```ini
GIT_PERSONAL_NAME="张三"
GIT_PERSONAL_EMAIL="zhangsan@example.com"
GIT_WORK_NAME="San Zhang"
GIT_WORK_EMAIL="san.zhang@company.com"
```

管理命令：
- `easywork config` — 查看配置
- `easywork config edit` — 编辑配置

---

## 目录结构

```
EasyWork/
├── bin/
│   └── easywork          # 主 CLI 入口
├── lib/
│   ├── common.sh         # 核心库（日志、系统检测、锁、配置管理、模块发现）
│   ├── shell.sh          # Shell 环境配置模块
│   ├── git.sh            # Git 配置模块
│   └── vim.sh            # Vim IDE 配置模块
├── tests/
│   ├── helpers/
│   │   └── mocks.bash    # 测试 mock 辅助
│   ├── test_cli.bats     # CLI 参数解析测试
│   ├── test_e2e.bats     # 端到端测试
│   ├── test_modules.bats # 模块功能测试
│   ├── test_noninteractive.bats # 非交互模式测试
│   └── test_unit.bats    # 单元测试
├── .github/workflows/
│   ├── ci.yml            # CI 流水线（lint + test + 格式检查）
│   └── release.yml       # 发布流水线
├── VERSION               # 版本号
├── MODULES               # 启用的模块列表
├── Makefile              # 开发命令集
├── easywork.conf.example # 配置文件示例
├── LICENSE               # MIT 许可证
└── README.md             # 本文档
```

---

## Makefile 命令

在项目目录下运行：

| 命令 | 说明 |
|---|---|
| `make lint` | ShellCheck 静态分析 |
| `make test` | 运行 BATS 测试 |
| `make fmt` | 自动格式化 shell 脚本（shfmt） |
| `make fmt-check` | 检查格式而不修改文件 |
| `make check` | lint + fmt-check + test（完整检查） |
| `make dry-run` | 预览安装效果 |
| `make install` | 安装 CLI 到 PATH |
| `make clean` | 清理临时文件 |
| `make help` | 显示帮助 |

---

## 从零开始

在一个全新的 macOS / Linux 环境中：

```bash
# 1. 安装基础工具（如尚未安装）
# macOS:
xcode-select --install

# Ubuntu/Debian:
sudo apt-get update && sudo apt-get install -y curl git

# 2. 安装 EasyWork CLI
curl -sL https://raw.githubusercontent.com/EasyIndie/EasyWork/main/bin/easywork | bash

# 3. 一键配置全部环境
easywork install

# 4. （可选）查看安装结果
easywork version
```

---

## 卸载

```bash
# 卸载全部组件，保留配置文件
easywork uninstall

# 卸载全部组件并删除配置文件
easywork uninstall --remove-config

# 卸载指定组件，保留其他
easywork uninstall shell

# 预览卸载操作
easywork uninstall --dry-run
```

卸载会：
- 移除从 `~/.vimrc`、`~/.gitconfig`、`~/.zshrc` / `~/.bashrc` 中注入的 EasyWork 标记段
- 删除 `~/.sh_config_custom`、`~/.easywork.manifest`
- 保留原始备份文件（`~/.gitconfig.bak`、`~/.vimrc.bak` 等）

---

## 贡献

欢迎贡献！流程：

1. Fork 本仓库
2. 创建特性分支（`git checkout -b feature/my-feature`）
3. 运行 `make check` 确保 lint 和测试通过
4. 提交 PR

开发要求：
- 遵循 ShellCheck 规范（已配置 `.shellcheckrc`）
- 使用 shfmt 格式化（`make fmt`）
- 为新增功能编写 BATS 测试
- 保持 bash 兼容性，支持 zsh 运行

---

## 许可证

[MIT](LICENSE) © EasyIndie
