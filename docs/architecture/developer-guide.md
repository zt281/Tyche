# Developer Guide

本指南帮助开发者在多仓库架构下快速设置开发环境、构建项目并进行日常开发。

## 首次设置

### 克隆聚合项目

```bash
git clone --recurse-submodules https://github.com/zt281/Tyche.git
cd Tyche
```

这将递归克隆所有子模块到对应目录。如果忘记加 `--recurse-submodules`，可以后续执行：

```bash
git submodule update --init --recursive
```

### 环境要求

| 组件 | 最低版本 | 说明 |
|------|----------|------|
| CMake | 3.16+ | C++ 项目构建 |
| C++ 编译器 | C++17 支持 | MSVC 2019+、GCC 9+、Clang 10+ |
| Python | 3.10+ | Python 引擎和模块 |
| pip | 最新版 | Python 包管理 |
| Node.js | 18+ | TycheApp 桌面应用（可选） |

## 构建全流程

### 1. 构建 C++ 核心

```bash
cd core/cpp
cmake -B build
cmake --build build
```

Windows 下指定 Visual Studio 生成器：

```powershell
cd core/cpp
cmake -B build -G "Visual Studio 17 2022"
cmake --build build --config Release
```

### 2. 安装 Python 核心

```bash
cd core/python
pip install -e ".[dev]"
```

### 3. 安装静态数据模块

```bash
cd modules/static-data
pip install -e ".[dev]"
```

### 4. 构建 CTP 网关

```bash
cd modules/ctp-gateway-cpp
cmake -B build -DCTP_USE_SUBMODULE=ON
cmake --build build
```

> **注意**: CTP 网关需要 CTP SDK。使用 `-DCTP_USE_SUBMODULE=ON` 从子模块加载 SDK，或通过 `-DCTP_SDK_DIR=<path>` 指定外部 SDK 路径。

### 5. 安装 TUI（可选）

```bash
cd tui
pip install -e ".[dev]"
```

### 6. 构建桌面应用（可选）

```bash
cd app
npm install
npm run dev
```

## 开发工作流

### 修改特定子项目

每个子模块是一个独立的 Git 仓库。修改子项目时：

```bash
# 1. 进入子模块目录
cd core/cpp

# 2. 创建功能分支
git checkout -b feature/my-change

# 3. 进行修改、提交
git add -A
git commit -m "feat: description of change"

# 4. 推送到子仓库远端
git push origin feature/my-change

# 5. 在子仓库创建 PR/MR
# （通过 GitHub/GitLab 界面操作）
```

### 在聚合项目中测试子项目变更

```bash
# 1. 子项目修改完成后，更新聚合项目的子模块引用
cd /path/to/Tyche
git submodule update --remote core/cpp

# 2. 运行集成测试验证
pytest core/python/tests/ modules/static-data/tests/

# 3. 提交聚合项目的子模块引用更新
git add core/cpp
git commit -m "chore: update TycheCore-CPP submodule reference"
```

### 跨仓库变更处理

当变更涉及多个子仓库时：

1. 在各子仓库分别创建功能分支和 PR
2. 在每个子仓库的 PR 描述中注明关联的其他 PR
3. 各子仓库的 PR 需通过各自的 CI 流水线
4. 最后更新聚合项目的子模块引用，确保集成兼容
5. 聚合项目的 CI 会验证所有子项目的集成兼容性

> **最佳实践**: 协议变更（`docs/protocol/`）应单独提交，并在所有依赖该协议的子项目更新后再合并。

## 测试

### C++ 单元测试

```bash
ctest --test-dir core/cpp/build
# 或指定构建配置
ctest --test-dir core/cpp/build -C Release
```

### Python 单元测试

```bash
# 引擎核心测试
pytest core/python/tests/ -v

# 静态数据模块测试
pytest modules/static-data/tests/ -v

# 运行所有 Python 测试
pytest core/python/tests/ modules/static-data/tests/ -v
```

### 集成测试

集成测试在聚合项目的 CI 流水线中运行，确保子项目间的兼容性：

```bash
# 本地运行集成测试（需要所有子项目已构建）
pytest tests/integration/ -v
```

## 常用脚本

聚合项目提供以下启动脚本：

| 脚本 | 说明 |
|------|------|
| `scripts/start-engine.ps1` | Windows 下启动引擎（PowerShell） |
| `scripts/start-engine.sh` | Linux/macOS 下启动引擎（Bash） |

```powershell
# Windows
.\scripts\start-engine.ps1
```

```bash
# Linux/macOS
./scripts/start-engine.sh
```

## 子模块管理

### 常用命令

```bash
# 初始化所有子模块（首次克隆后）
git submodule update --init --recursive

# 更新所有子模块到远端最新提交
git submodule update --remote

# 更新特定子模块
git submodule update --remote core/cpp

# 查看所有子模块状态
git submodule status

# 查看子模块的提交差异
git diff --submodule
```

### 注意事项

1. **子模块中的提交需要在子仓库中推送**：子模块是一个独立的 Git 仓库，在子模块目录中的 `git commit` 只创建了本地提交，还需要 `git push` 推送到子仓库的远端
2. **聚合项目记录子模块的 commit SHA**：聚合项目不跟踪子模块的分支，而是记录具体的 commit SHA。更新子模块后需要在聚合项目中提交新的引用
3. **避免在子模块中处于 detached HEAD 状态时提交**：进入子模块后先切换到功能分支再提交
4. **子模块 URL 变更**：如果子仓库地址变更，需要更新聚合项目的 `.gitmodules` 文件并通知所有开发者重新同步

### 新增子模块

```bash
git submodule add https://github.com/zt281/<repo-name>.git <target-path>
git commit -m "chore: add <repo-name> submodule"
```

## 问题排查

### 子模块状态不一致

```bash
# 重置子模块到聚合项目记录的版本
git submodule update --init --recursive --force
```

### 构建失败：找不到头文件

确保已初始化所有第三方库子模块：

```bash
git submodule update --init third_party/cppzmq third_party/msgpack-c third_party/libzmq
```

### Python 模块导入失败

确认 Python 核心已安装为开发模式：

```bash
cd core/python
pip install -e ".[dev]"
```

## 相关文档

- [多仓库架构概览](multi-repo-architecture.md) — 仓库结构、职责边界和通信方式
- [从单体仓库迁移](../migration/from-monorepo.md) — 迁移说明和常见问题
- [通信协议规范](../protocol/) — 跨模块通信协议定义
