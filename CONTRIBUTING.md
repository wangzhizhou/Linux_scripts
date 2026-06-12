# 贡献指南

感谢你考虑为 EasyWork 贡献代码！

## 提 Issue

- 使用 GitHub Issues 提交 bug 报告或功能请求
- 请尽可能详细描述：复现步骤、期望行为、实际行为
- 如果涉及报错，请附上完整的错误输出

## 提 Pull Request

1. Fork 本仓库
2. 创建特性分支：
   ```bash
   git checkout -b feature/my-feature
   ```
3. 开发并确保质量通过：
   ```bash
   make check   # 运行 lint + fmt-check + test
   ```
4. 提交 PR 到 `main` 分支

## 开发环境

### 前置条件

- **ShellCheck** — 静态分析
- **shfmt** — 格式化
- **BATS** — 测试框架

```bash
# macOS
brew install shellcheck shfmt bats-core

# Ubuntu/Debian
sudo apt-get install -y shellcheck
go install mvdan.cc/sh/v3/cmd/shfmt@latest
git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats
sudo /tmp/bats/install.sh /usr/local
```

### 常用命令

| 命令 | 说明 |
|---|---|
| `make lint` | ShellCheck 静态分析 |
| `make test` | 运行 BATS 测试 |
| `make fmt` | 自动格式化代码 |
| `make fmt-check` | 检查格式 |
| `make check` | 完整质量检查 |
| `make dry-run` | 预览安装效果 |

### 本机测试

```bash
# 直接运行
./bin/easywork install --dry-run --yes

# 完整安装（注意会修改本机配置）
sudo make install
easywork install
```

## 编码规范

- **ShellCheck**: 所有 `.sh` 文件必须通过 ShellCheck 检查
- **shfmt**: 使用 `make fmt` 格式化（参数：`-i 4 -bn -ci -sr`）
- **兼容性**: 脚本需同时兼容 bash 和 zsh
- **测试**: 新增功能应添加对应的 BATS 测试
- **命名**: 函数名使用下划线分隔风格（如 `_validate_email`），常量使用大写
- **错误处理**: 关键操作检查返回值并给出明确的错误信息

## 许可证

贡献即表示你同意你的代码在 [MIT](LICENSE) 许可下发布。
