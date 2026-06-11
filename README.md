# EasyWork

[![CI](https://github.com/EasyIndie/EasyWork/actions/workflows/ci.yml/badge.svg)](https://github.com/EasyIndie/EasyWork/actions/workflows/ci.yml)
[![Release](https://github.com/EasyIndie/EasyWork/actions/workflows/release.yml/badge.svg)](https://github.com/EasyIndie/EasyWork/actions/workflows/release.yml)

一条命令，配置好你的开发环境。

## 一键安装（macOS / Linux）

```bash
curl -sL https://raw.githubusercontent.com/EasyIndie/EasyWork/main/bin/easywork | bash -s -- install
```

## 使用

```bash
easywork install              # 一键配置全部
easywork shell                # 配置 Shell（bash/zsh 自动适配）
easywork git                  # 配置 Git
easywork vim                  # 配置 Vim
easywork config               # 查看配置
easywork config edit          # 编辑配置
easywork version              # 查看版本
easywork update               # 检查并升级
easywork uninstall            # 卸载
```

## 系统要求

macOS / Linux，bash 或 zsh，需已安装 curl、git。
