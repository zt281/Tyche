# 从单体仓库迁移到多仓库架构

本文档说明如何从原 TycheEngine 单体仓库迁移到新的多仓库架构。

## 迁移概览

TycheEngine 已从单体仓库拆分为多个独立仓库，通过 Tyche 聚合项目统一管理。开发者需要重新配置开发环境。

## 目录映射表

| 原路径（单体仓库） | 新仓库 | 新路径（聚合项目） |
|---------------------|--------|---------------------|
| `src/tyche/cpp/` | [TycheCore-CPP](https://github.com/zt281/TycheCore-CPP) | `core/cpp/` |
| `src/tyche/*.py`（引擎核心） | [TycheEngine-Python](https://github.com/zt281/TycheEngine-Python) | `core/python/` |
| `src/modules/ctp_gateway_cpp/` | [ctp-gateway-cpp](https://github.com/zt281/ctp-gateway-cpp) | `modules/ctp-gateway-cpp/` |
| `src/modules/static_data/` | [static-data](https://github.com/zt281/static-data) | `modules/static-data/` |
| `tui/` | [TycheTUI](https://github.com/zt281/TycheTUI) | `tui/` |
| `app/` | [TycheApp](https://github.com/zt281/TycheApp) | `app/` |
| `tests/cpp/` | [TycheCore-CPP](https://github.com/zt281/TycheCore-CPP) | `core/cpp/tests/` |
| `tests/unit/` | [TycheEngine-Python](https://github.com/zt281/TycheEngine-Python) | `core/python/tests/` |
| `third_party/` | 聚合项目（共享） | `third_party/` |
| `config/` | 聚合项目 | `config/` |
| `docs/` | 聚合项目 | `docs/` |
| `runtime/` | 聚合项目 | `runtime/` |

## 开发者迁移步骤

### 1. 重新克隆仓库

```bash
# 备份原仓库（可选）
mv TycheEngine TycheEngine-backup

# 克隆新的聚合项目
git clone --recurse-submodules https://github.com/zt281/Tyche.git
cd Tyche
```

### 2. 更新 IDE 工作区设置

#### VS Code

更新 `.vscode/settings.json` 中的路径配置：

```json
{
  "cmake.buildDirectory": "${workspaceFolder}/core/cpp/build",
  "python.analysis.extraPaths": [
    "core/python/src",
    "modules/static-data/src"
  ],
  "C_Cpp.default.compileCommands": "${workspaceFolder}/core/cpp/build/compile_commands.json"
}
```

更新 `.vscode/c_cpp_properties.json` 中的 include 路径：

```json
{
  "includePath": [
    "${workspaceFolder}/core/cpp/src/**",
    "${workspaceFolder}/third_party/cppzmq/include/**",
    "${workspaceFolder}/third_party/msgpack-c/include/**"
  ]
}
```

#### JetBrains (CLion / PyCharm)

- 重新导入项目根目录
- 更新 CMake profile 指向 `core/cpp/CMakeLists.txt`
- 更新 Python interpreter 和 source roots

### 3. 更新环境变量

如果原仓库配置了环境变量，需要更新路径：

```powershell
# Windows PowerShell — 更新 CTP 网关配置路径
$env:CTP_GATEWAY_CONFIG = "d:\dev\Tyche\runtime\gateway\ctp_gateway.json"

# 或永久设置（管理员权限）
[System.Environment]::SetEnvironmentVariable("CTP_GATEWAY_CONFIG", "d:\dev\Tyche\runtime\gateway\ctp_gateway.json", "User")
```

```bash
# Linux/macOS
export CTP_GATEWAY_CONFIG="/path/to/Tyche/runtime/gateway/ctp_gateway.json"
```

### 4. 更新脚本和工具中的路径引用

检查并更新以下内容中的路径引用：

- CI 配置文件（`.github/workflows/`）
- 启动脚本和构建脚本
- Docker 配置文件
- 文档中的示例路径
- 外部集成工具中的路径

### 5. 验证环境

```bash
# 构建 C++ 核心
cd core/cpp && cmake -B build && cmake --build build

# 安装 Python 核心
cd ../python && pip install -e ".[dev]"

# 运行测试
cd ../../
pytest core/python/tests/ -v
ctest --test-dir core/cpp/build
```

## 常见问题 FAQ

### Q: 原仓库还能用吗？

A: 原仓库已归档为只读状态，不再接受新的提交。所有新开发工作应在新的聚合项目中进行。

### Q: 我的未提交变更怎么办？

A: 在原仓库中将未提交的变更以 patch 形式导出，然后在新仓库中应用：

```bash
# 在原仓库中导出
cd TycheEngine-backup
git diff > my-changes.patch
git diff --cached > my-staged-changes.patch

# 在新仓库对应子模块中应用
cd Tyche/core/cpp
git apply ../../../TycheEngine-backup/my-changes.patch
```

### Q: 子模块更新后为什么编译失败？

A: 子模块更新后，可能需要重新安装依赖或重新构建：

```bash
# 更新所有子模块
git submodule update --init --recursive

# 重新构建 C++ 核心
cd core/cpp && cmake -B build && cmake --build build

# 重新安装 Python 包
cd ../python && pip install -e ".[dev]"
```

### Q: 如何在子模块中进行开发？

A: 子模块是独立的 Git 仓库，需要进入子模块目录进行操作：

```bash
cd core/cpp
git checkout -b feature/my-branch
# ... 修改、提交 ...
git push origin feature/my-branch

# 回到聚合项目更新引用
cd ../..
git add core/cpp
git commit -m "chore: update core/cpp submodule"
```

### Q: 我可以在聚合项目中直接修改子模块文件吗？

A: 技术上可以，但不推荐。直接在子模块目录中修改会使其处于 detached HEAD 状态。建议先进入子模块目录切换到功能分支再修改。

### Q: 多人协作时如何避免子模块冲突？

A: 建议团队约定：
1. 子模块版本更新统一由 Team Lead 在聚合项目中操作
2. 各开发者在自己分支中更新子模块引用
3. 合并前先更新子模块到最新，再创建 PR

## 相关文档

- [多仓库架构概览](../architecture/multi-repo-architecture.md)
- [开发者指南](../architecture/developer-guide.md)
