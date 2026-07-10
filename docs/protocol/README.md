# Tyche 通信协议规范

**版本**: v1.0  
**状态**: 稳定  
**最后更新**: 2026-07-10

---

## 概述

Tyche Engine 采用 **ZMQ + SHM 双通道** 通信架构：

- **ZeroMQ 通道**：用于跨语言（Python / C++ / Rust）模块间通信，支持注册、事件广播、Job 路由、心跳监控等
- **共享内存 (SHM) 通道**：用于 C++ 模块间的高性能零拷贝通信，适用于行情 tick 等高频数据

```
┌─────────────────────────────────────────────────────────┐
│                    Tyche Engine (Broker)                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │ ROUTER   │  │ XPUB/XSUB│  │ ROUTER   │  │ PUB      │ │
│  │ 注册端口  │  │ 事件代理  │  │ Job路由   │  │ 心跳广播  │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘ │
└───────┼──────────────┼──────────────┼──────────────┼─────┘
        │              │              │              │
   ┌────┴────┐   ┌─────┴─────┐  ┌────┴────┐   ┌────┴────┐
   │ Module  │   │  Module   │  │ Module  │   │ Module  │
   │ (Python)│   │  (C++)    │  │ (Rust)  │   │ (C++)   │
   └─────────┘   └─────┬─────┘  └─────────┘   └────┬────┘
                        │                           │
                        └────── SHM 零拷贝 ──────────┘
```

## 协议文档索引

| 文档 | 说明 |
|------|------|
| [zmq-port-layout.md](./zmq-port-layout.md) | ZMQ 端口布局规范（base_port 偏移映射） |
| [message-format.md](./message-format.md) | msgpack 消息序列化格式规范 |
| [shm-wire-format.md](./shm-wire-format.md) | 共享内存线格式（FlatMessage / FlatQuoteTick） |
| [event-types.md](./event-types.md) | 事件类型注册表 |

## SDK 接口文档

| 文档 | 说明 |
|------|------|
| [../sdk/cpp-sdk-interface.md](../sdk/cpp-sdk-interface.md) | C++ SDK 公共头文件与接口规范 |
| [../sdk/python-sdk-interface.md](../sdk/python-sdk-interface.md) | Python SDK (tyche-core) 公共 API 规范 |

## 子仓库引用方式

各子仓库通过以下方式引用本协议规范：

- **tyche-core (Python)**：`from tyche.types import ...` / `from tyche.message import ...`
- **tyche-cpp-sdk**：`#include <tyche/types.h>` / `#include <tyche/message.h>`
- **网关模块**：实现本协议定义的 ZMQ 端口连接与消息格式
- **策略模块**：通过 `TycheModule` 基类自动适配协议

## 协议变更流程

1. 在本文档目录下创建变更提案（PR 形式）
2. 变更需同时更新 Python 和 C++ 两端实现
3. 所有破坏性变更需递增主版本号
4. 向后兼容的增量变更递增次版本号
5. 变更经合并后，各子仓库同步更新对应的 SDK 版本

## 版本兼容性

| 协议版本 | tyche-core (Python) | tyche-cpp-sdk | 说明 |
|---------|--------------------|--------------|------|
| v1.0    | >=1.0.0            | >=1.0.0      | 初始稳定版 |
