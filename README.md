# EasyWork

[![CI](https://github.com/EasyIndie/EasyWork/actions/workflows/ci.yml/badge.svg)](https://github.com/EasyIndie/EasyWork/actions/workflows/ci.yml)
[![Release](https://github.com/EasyIndie/EasyWork/actions/workflows/release.yml/badge.svg)](https://github.com/EasyIndie/EasyWork/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**一条命令，配置好你的开发环境。**

---

## 快速开始

```bash
# 安装 CLI
curl -sL https://raw.githubusercontent.com/EasyIndie/EasyWork/main/bin/easywork | bash

# 一键配置全部环境
easywork install
```

> 系统要求：macOS 或 Linux，bash 或 zsh，已安装 curl 和 git。

---

## CLI 使用

```bash
easywork <命令> [参数] [选项]
```

| 命令 | 说明 |
|---|---|
| `install` | 一键安装全部组件 |
| `install <模块>` | 只安装指定组件 |
| `uninstall` | 卸载全部组件 |
| `uninstall <模块>` | 卸载指定组件 |
| `config` / `config edit` | 查看 / 编辑配置文件 |
| `completion` | 安装、移除或查看 shell 补全状态 |
| `version` | 查看版本和已安装组件 |
| `update` | 升级到最新版本 |
| `help` | 显示帮助信息 |

| 选项 | 说明 |
|---|---|
| `--dry-run` | 预览变更，不执行 |
| `--yes` `-y` | 跳过确认 |
| `--verbose` `-v` | 详细输出 |
| `--keep-config` / `--remove-config` | 卸载时保留 / 删除配置 |

---

## 模块

### Shell

配置 zsh / bash 环境，zsh 环境下自动安装 Oh My Zsh。

- 颜色变量、彩色提示符（含 Git 分支信息）
- 常用别名（`grep`、`mv`、`cp`、`rm` 加保护参数，`g` → `git`，`q` → `exit`）
- macOS 网络工具别名（`flushdns`、`net_list`、`vpn_list` 等）
- FFmpeg 简写别名（`ff`、`fp`、`fb`）

### Git

身份管理 + 80+ 个别名，涵盖 25 个类别：

日志、分支、提交、推送、变基、暂存、拣选、工作树、子模块等。

支持 personal / work / custom 三种身份，全局或本地仓库作用域。

### Vim

通过 vim-plug 管理 19 个插件，自动安装 Node.js、ripgrep 依赖。

NERDTree 文件树、Airline 状态栏、fzf 模糊搜索、coc.nvim 代码补全、ALE 语法检查、Markdown 预览、Git 集成等。

---

## 配置

配置文件 `~/.easywork/config`，安装时自动生成：

```ini
GIT_PERSONAL_NAME="张三"
GIT_PERSONAL_EMAIL="zhangsan@example.com"
GIT_WORK_NAME="San Zhang"
GIT_WORK_EMAIL="san.zhang@company.com"
```

---

## 卸载

```bash
easywork uninstall                 # 保留配置文件
easywork uninstall --remove-config # 完全移除
easywork uninstall shell           # 只卸载指定模块
```

---

## 开发

```bash
make check    # lint + 格式化检查 + 测试
make test     # 运行测试
make dry-run  # 预览安装
```

需要 ShellCheck、shfmt、BATS。详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

---

[MIT](LICENSE) © EasyIndie
