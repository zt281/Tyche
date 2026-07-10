# Multi-Repository Architecture

## 背景与动机

TycheEngine 最初以单体仓库（monorepo）形式组织，所有组件——C++ 引擎核心、Python 引擎、CTP 网关、静态数据服务、TUI 终端监控和桌面 GUI——均在同一仓库中。随着项目规模增长，单体仓库暴露出以下问题：

1. **构建耦合**：C++ 和 Python 的构建流程差异大，单一 CI 流水线难以高效管理
2. **权限粒度不足**：不同模块的贡献者需要访问整个仓库，无法按模块隔离权限
3. **发布节奏不同**：引擎核心、网关和 UI 的迭代速度各异，强制同步发布限制了灵活性
4. **依赖管理复杂**：C++ 第三方库（ZMQ、msgpack）与 Python 依赖混在一起，子模块嵌套层次深

为解决这些问题，项目拆分为多仓库架构，通过一个聚合项目（Tyche）以 Git 子模块方式集成各独立仓库。

## 仓库关系图

```
Tyche (聚合项目)  https://github.com/zt281/Tyche
│
├── core/
│   ├── cpp/     → TycheCore-CPP          (C++ 引擎核心)
│   └── python/  → TycheEngine-Python     (Python 引擎核心)
│
├── modules/
│   ├── ctp-gateway-cpp/                  (CTP 网关模块)
│   └── static-data/                      (静态数据服务)
│
├── tui/         → TycheTUI              (终端监控界面)
├── app/         → TycheApp              (桌面 GUI 应用)
│
├── docs/                                 (跨项目文档与协议规范)
│   ├── architecture/                     (架构文档)
│   ├── migration/                        (迁移文档)
│   └── protocol/                         (通信协议规范)
│
├── third_party/                          (共享第三方依赖)
│   ├── cppzmq/
│   ├── libzmq/
│   ├── msgpack-c/
│   └── pybind11/
│
├── config/                               (运行时配置示例)
├── runtime/                              (运行时产物目录)
└── scripts/                              (启动与管理脚本)
```

## 各仓库职责边界

| 仓库 | 路径 | 职责 | 技术栈 | 独立 CI |
|------|------|------|--------|---------|
| **TycheCore-CPP** | `core/cpp` | C++ 高性能引擎核心：事件总线、SHM 通道、动态模块加载、线程调度 | C++17, CMake, ZMQ, msgpack | ✅ |
| **TycheEngine-Python** | `core/python` | Python 引擎核心：模块编排、事件分发、配置管理、心跳监控 | Python 3.10+, pyzmq | ✅ |
| **ctp-gateway-cpp** | `modules/ctp-gateway-cpp` | CTP 柜台网关：行情/交易接口对接、合约订阅、数据转发 | C++17, CMake, CTP SDK | ✅ |
| **static-data** | `modules/static-data` | 静态数据服务：合约信息、市场数据、交易日历管理 | Python 3.10+ | ✅ |
| **TycheTUI** | `tui` | 终端用户界面：实时监控、模块状态展示、日志浏览 | Python, Textual | ✅ |
| **TycheApp** | `app` | 桌面 GUI 应用：图形化管理界面 | Electron, Vue3, TypeScript | ✅ |

## 依赖关系

```
TycheCore-CPP ─────┐
                   ├──► ctp-gateway-cpp
                   │
TycheEngine-Python ┘──► static-data
       │
       ├──► TycheTUI (通过 ZMQ 订阅引擎事件)
       └──► TycheApp (通过 ZMQ/REST 与引擎交互)
```

- **TycheCore-CPP** 是最底层依赖，提供高性能通信基础设施
- **TycheEngine-Python** 依赖 TycheCore-CPP 的共享库（通过 pybind11 绑定或直接 ZMQ 通信）
- **ctp-gateway-cpp** 依赖 TycheCore-CPP 的 SHM/ZMQ 通信层
- **static-data** 依赖 TycheEngine-Python 的模块基类和事件系统
- **TycheTUI** 和 **TycheApp** 作为消费者，仅依赖引擎暴露的 ZMQ 接口

## 通信方式

| 通信方式 | 使用场景 | 说明 |
|----------|----------|------|
| **ZMQ (ZeroMQ)** | 引擎 ↔ 模块、引擎 ↔ UI | 跨语言消息总线，支持 PUB/SUB 和 REQ/REP 模式 |
| **SHM (Shared Memory)** | C++ 高性能通道 | C++ 模块间的低延迟数据传输，避免内核态拷贝 |
| **msgpack** | 序列化格式 | 跨语言二进制序列化，C++/Python/Rust 统一数据格式 |

### 通信协议规范

所有跨模块通信的协议规范定义在聚合项目的 `docs/protocol/` 目录下，各子仓库必须遵循：

- 消息格式定义
- 事件类型枚举
- 序列化/反序列化规则
- 版本兼容性要求

## 版本兼容性矩阵

| Tyche (聚合) | TycheCore-CPP | TycheEngine-Python | ctp-gateway-cpp | static-data | TycheTUI | TycheApp |
|--------------|---------------|---------------------|-----------------|-------------|----------|----------|
| v0.3.x       | v0.3.x        | v0.3.x              | v0.3.x          | v0.3.x      | v0.2.x   | v0.1.x   |
| v0.2.x       | v0.2.x        | v0.2.x              | v0.2.x          | v0.2.x      | v0.1.x   | —        |

> **注意**: 聚合项目的版本号不直接对应子项目版本号。聚合项目通过子模块引用（commit SHA）来锁定各子项目的具体版本。

## 相关文档

- [开发者指南](developer-guide.md) — 首次设置、构建流程和开发工作流
- [从单体仓库迁移](../migration/from-monorepo.md) — 迁移说明和目录映射
- [通信协议规范](../protocol/) — 跨模块通信协议定义
