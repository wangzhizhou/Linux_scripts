# EasyWork

[![CI](https://github.com/EasyIndie/EasyWork/actions/workflows/ci.yml/badge.svg)](https://github.com/EasyIndie/EasyWork/actions/workflows/ci.yml)
[![Release](https://github.com/EasyIndie/EasyWork/actions/workflows/release.yml/badge.svg)](https://github.com/EasyIndie/EasyWork/actions/workflows/release.yml)

一条命令，配置好你的开发环境。

## 快速开始（macOS / Linux）

安装 CLI 工具：

```bash
curl -sL https://raw.githubusercontent.com/EasyIndie/EasyWork/main/bin/easywork | bash
```

然后配置你的开发环境：

```bash
easywork install              # 一键配置全部
```

## 使用

```bash
# 一键安装
easywork install              # 一键配置全部组件
easywork install <组件名>     # 只配置指定组件

# 组件快捷命令（可直接输入组件名单独安装）
easywork shell                # 配置 Shell 环境（bash/zsh 适配）
easywork git                  # 配置 Git 别名和身份
easywork vim                  # 配置 Vim IDE

# 配置管理
easywork config               # 查看配置文件元信息及完整内容
easywork config edit          # 编辑配置文件

# 版本与升级
easywork version              # 查看版本、安装日期和已安装组件
easywork update               # 检查并升级到最新版本

# 卸载
easywork uninstall [组件]     # 卸载（不指定则卸载全部）
```

> **提示**：`easywork <组件名>` 可单独安装该组件，组件列表由模块数量动态生成。

## 系统要求

macOS / Linux，bash 或 zsh，需已安装 curl、git。
