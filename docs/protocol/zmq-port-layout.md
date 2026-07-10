# ZMQ 端口布局规范

**协议版本**: v1.0  
**源文件**: `src/tyche/types.py`, `src/tyche/cpp/types.h`, `src/tyche/cpp/engine/main.cpp`

---

## 端口映射表

以 `base_port`（默认 5555）为基准，各端口偏移如下：

| 偏移 | 默认端口 | Socket 类型 | 方向 | 用途 |
|------|---------|------------|------|------|
| +0   | 5555    | ROUTER     | Engine ← Module (REQ) | 模块注册 |
| +1   | 5556    | XPUB       | Engine → Module (SUB) | 事件分发（模块订阅） |
| +2   | 5557    | XSUB       | Engine ← Module (PUB) | 事件汇聚（模块发布） |
| +3   | 5558    | ROUTER     | Engine ← TUI/工具 (REQ) | 管理查询（STATUS/MODULES/QUEUES 等） |
| +4   | 5559    | PUB        | Engine → Module (SUB) | 心跳广播 |
| +5   | 5560    | ROUTER     | Engine ← Module (DEALER) | 心跳接收（模块上报） |
| +6   | 5561    | —          | — | 预留 |
| +7   | 5562    | —          | — | 预留 |
| +8   | 5563    | —          | — | 预留 |
| +9   | 5564    | ROUTER     | Engine ↔ Module (DEALER) | Job 请求/响应路由 |

> **注意**：Admin 端口（+3）的默认值定义为 `ADMIN_PORT_DEFAULT = 5558`，Python 端和 C++ 端保持同步。

## 端口拓扑图

```
Engine (Broker)
├── [base_port+0] ROUTER  ←── Module REQ（一次性注册握手，注册后关闭）
├── [base_port+1] XPUB    ──→ Module SUB （事件订阅，topic = 事件名）
├── [base_port+2] XSUB    ←── Module PUB （事件发布，topic = 事件名）
├── [base_port+3] ROUTER  ←── TUI / Admin REQ（查询引擎状态）
├── [base_port+4] PUB     ──→ Module SUB （心跳信号）
├── [base_port+5] ROUTER  ←── Module DEALER（模块心跳上报）
└── [base_port+9] ROUTER  ↔── Module DEALER（Job 双向通信）
```

## 模块端 Socket 清单

每个模块在连接引擎时创建以下 Socket：

| Socket | 类型 | 连接目标 | 说明 |
|--------|------|---------|------|
| 注册 Socket | REQ | base_port+0 (ROUTER) | 一次性握手，收到 ACK 后关闭 |
| 事件发布 Socket | PUB | base_port+2 (XSUB) | 向引擎发布事件 |
| 事件订阅 Socket | SUB | base_port+1 (XPUB) | 订阅引擎分发的事件 |
| 心跳 Socket | DEALER | base_port+5 (ROUTER) | 定期发送心跳到引擎 |
| Job Socket | DEALER | base_port+9 (ROUTER) | 请求/响应式 Job 通信 |

## 注册 ACK 响应格式

引擎在注册 ACK 中返回以下端口信息，模块据此建立后续连接：

```python
{
    "status": "ok",
    "module_id": "openctp_gateway_a1b2c3",
    "event_pub_port": 5556,       # base_port+1，模块 SUB 连接此端口
    "event_sub_port": 5557,       # base_port+2，模块 PUB 连接此端口
    "job_port": 5564,             # base_port+9，模块 DEALER 连接此端口
    "heartbeat_recv_port": 5560,  # base_port+5，模块 DEALER 连接此端口
}
```

## 管理查询协议

Admin ROUTER（base_port+3）接受以下 msgpack 编码的查询字符串：

| 查询 | 返回字段 | 说明 |
|------|---------|------|
| `"STATUS"` | `status`, `uptime`, `module_count`, `event_count` | 引擎运行状态 |
| `"MODULES"` | `modules[]` (id, interfaces, liveness) | 已注册模块列表 |
| `"QUEUES"` | `queues[]` (name, size, capacity, dropped) | 队列状态 |
| `"JOBS"` | `jobs[]` (correlation_id, topic, handler_id) | 活跃 Job 列表 |
| `"DEAD_LETTERS"` | `dead_letters[]` (最近 100 条) | 死信记录 |
| `"STATS"` | `event_count`, `register_count`, `module_count` | 简要统计 |

## 跨平台一致性

Python 引擎 (`src/tyche/engine.py`) 与 C++ 引擎 (`src/tyche/cpp/engine/main.cpp`) 使用完全相同的端口映射：

```
Python: TycheEngine(registration_endpoint=Endpoint(host, base_port), ...)
C++:    Endpoint registration_ep{host, base_port};
        Endpoint event_ep{host, base_port + 1};
        Endpoint heartbeat_ep{host, base_port + 4};
        Endpoint heartbeat_recv_ep{host, base_port + 5};
        Endpoint admin_ep{host, base_port + 3};
        Endpoint job_ep{host, base_port + 9};
```

两端使用同一 `base_port` 启动时可互操作。
