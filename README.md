# Tyche

Tyche 是一个分布式事件驱动交易引擎框架，采用 Python + C++ 混合技术栈，面向中国期货/期权交易系统。

## 架构

本项目是 Tyche 框架的聚合仓库，通过 Git Submodule 管理以下子项目：

| 子项目 | 路径 | 说明 |
|--------|------|------|
| [TycheCore-CPP](https://github.com/zt281/TycheCore-CPP) | `core/cpp` | C++ 高性能事件引擎核心 |
| [TycheEngine-Python](https://github.com/zt281/TycheEngine-Python) | `core/python` | Python 事件引擎核心 |
| [ctp-gateway-cpp](https://github.com/zt281/ctp-gateway-cpp) | `modules/ctp-gateway-cpp` | CTP 期货/期权网关 |
| [static-data](https://github.com/zt281/static-data) | `modules/static-data` | 市场静态数据服务 |
| [TycheTUI](https://github.com/zt281/TycheTUI) | `tui` | 终端 TUI 监控界面 |
| [TycheApp](https://github.com/zt281/TycheApp) | `app` | Electron 桌面 GUI |

## 快速开始

### 克隆（含所有子模块）

```bash
git clone --recurse-submodules https://github.com/zt281/Tyche.git
cd Tyche
```

### 构建 C++ 核心

```bash
cd core/cpp
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

### 安装 Python 核心

```bash
cd core/python
pip install -e ".[dev]"
```

### 启动引擎

```bash
# C++ 模式
./scripts/start-engine.sh cpp

# Python 模式
./scripts/start-engine.sh python
```

## 通信协议

详见 [docs/protocol/](docs/protocol/README.md)

## 开发者指南

详见 [AGENTS.md](AGENTS.md) 了解项目开发规范和工作流程。

## License

MIT
