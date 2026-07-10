# Python SDK 接口规范

**版本**: v1.0  
**包名**: `tyche-core`  
**安装**: `pip install tyche-core`

---

## 概述

`tyche-core` 提供 Python 模块接入 Tyche Engine 所需的全部基础设施。包含引擎（Broker）、模块基类、消息序列化、类型定义、事件常量和心跳机制。

## 公共 API 清单

### `tyche.engine` — 引擎（Broker）

中央消息代理，管理模块注册、事件路由、心跳监控和 Job 分发。

```python
from tyche.engine import TycheEngine
from tyche.types import Endpoint

engine = TycheEngine(
    registration_endpoint=Endpoint("127.0.0.1", 5555),
    event_endpoint=Endpoint("127.0.0.1", 5556),
    heartbeat_endpoint=Endpoint("127.0.0.1", 5559),
    # 可选参数（有默认值）：
    heartbeat_receive_endpoint=None,  # 默认 heartbeat_port + 1
    admin_endpoint=None,             # 默认 ADMIN_PORT_DEFAULT (5558)
    job_endpoint=None,               # 默认 registration_port + 9
    queue_capacity=10000,
    data_dir="data",
)

engine.run()   # 阻塞直到 stop() 被调用
engine.stop()  # 优雅关闭
```

**公共方法**：
- `run()` — 启动所有 worker 线程并阻塞主线程
- `start_nonblocking()` — 启动但不阻塞（用于测试）
- `stop()` — 停止引擎，幂等
- `register_module(module_info)` — 手动注册模块
- `unregister_module(module_id)` — 注销模块
- `health_check_module(module_id)` — 检查模块健康
- `decommission_module(module_id)` — 优雅下线模块

---

### `tyche.module` — 模块基类

所有 Python 模块的基类，自动发现 `on_*`、`send_*`、`handle_*`、`request_*` 方法并注册为接口。

```python
from tyche.module import TycheModule
from tyche.types import Endpoint

class MyStrategy(TycheModule):
    def on_quote(self, payload: dict):
        """处理 quote 事件（自动注册为 ON 接口）"""
        print(f"收到行情: {payload}")

    def send_order_submit(self, order: dict):
        """声明将发布 order_submit 事件（自动注册为 SEND 接口）"""
        self.send_event("order_submit", order)

    def handle_compute(self, payload: dict) -> dict:
        """处理 compute Job 请求（自动注册为 HANDLE 接口）"""
        return {"result": payload["value"] * 2}

# 使用
module = MyStrategy(
    engine_endpoint=Endpoint("127.0.0.1", 5555),
    family_name="my_strategy",
)
module.run()   # 阻塞直到 stop()
module.stop()  # 优雅关闭
```

**公共方法**：
- `start()` — 启动模块（非阻塞）
- `run()` — 启动并阻塞
- `stop()` — 优雅关闭（幂等）
- `send_event(event, payload, recipient=None)` — 发布事件
- `request_event(event, payload, timeout=5.0)` — 发起 Job 请求并阻塞等待响应

**公共属性**：
- `module_id: str` — Engine 分配的唯一标识（注册前为 family_name）
- `family_name: str` — 模块家族名称
- `interfaces: List[Interface]` — 已发现的接口列表

---

### `tyche.module_base` — 模块协议基类

轻量级 Protocol 类，定义模块的最小契约。

```python
from tyche.module_base import ModuleBase

# ModuleBase 是一个 Protocol（runtime_checkable）
# 子类必须实现：
#   - module_id 属性
#   - start() 方法
#   - stop() 方法

# 默认提供的 admin 处理方法：
#   - _admin_health_check() → dict
#   - _admin_availability_check() → dict
#   - _admin_respawn() → dict
#   - _admin_decommission() → dict
```

---

### `tyche.message` — 消息序列化

```python
from tyche.message import Message, serialize, deserialize
from tyche.types import MessageType

# 创建消息
msg = Message(
    msg_type=MessageType.EVENT,
    sender="gateway_abc123",
    event="quote",
    payload={"instrument_id": "au2512", "price": 488.5},
)

# 序列化
data: bytes = serialize(msg)

# 反序列化
restored: Message = deserialize(data)

# Envelope（用于 ROUTER 路由）
from tyche.message import Envelope, serialize_envelope, deserialize_envelope
```

**公共函数**：
- `serialize(message: Message) -> bytes` — msgpack 序列化
- `deserialize(data: bytes) -> Message` — msgpack 反序列化
- `serialize_envelope(envelope: Envelope) -> List[bytes]` — 多帧序列化
- `deserialize_envelope(frames: List[bytes]) -> Envelope` — 多帧反序列化

---

### `tyche.types` — 类型定义

```python
from tyche.types import (
    # 常量
    HEARTBEAT_INTERVAL,        # 1.0 秒
    HEARTBEAT_LIVENESS,        # 3
    ADMIN_PORT_DEFAULT,        # 5558

    # 枚举
    EventType,                 # REQUEST, RESPONSE, EVENT, HEARTBEAT, REGISTER, ACK
    InterfacePattern,          # ON, SEND, HANDLE, REQUEST
    BackpressureStrategy,      # DROP_OLDEST, DROP_NEWEST, BLOCK_PRODUCER
    DurabilityLevel,           # BEST_EFFORT=0, ASYNC_FLUSH=1, SYNC_FLUSH=2
    MessageType,               # COMMAND, EVENT, HEARTBEAT, REGISTER, ACK, RESPONSE, REQUEST

    # 数据类
    Endpoint,                  # Endpoint(host, port) → str() 返回 "tcp://host:port"
    Interface,                 # 接口定义
    ModuleInfo,                # 模块注册信息

    # 工具类
    ModuleId,                  # ModuleId.generate("family") → "family_a1b2c3"
)
```

---

### `tyche.events` — 事件常量

```python
from tyche import events

# 行情数据
events.QUOTE           # "quote"
events.TRADE           # "trade"
events.BAR             # "bar"
events.ORDER_BOOK      # "orderbook"

# 订单流
events.ORDER_SUBMIT    # "order_submit"
events.ORDER_APPROVED  # "order_approved"
events.ORDER_REJECTED  # "order_rejected"
events.ORDER_EXECUTE   # "order_execute"
events.ORDER_CANCEL    # "order_cancel"
events.ORDER_UPDATE    # "order_update"

# 成交
events.FILL            # "fill"

# 组合
events.POSITION_UPDATE # "position_update"
events.ACCOUNT_UPDATE  # "account_update"

# 风控
events.RISK_ALERT      # "risk_alert"

# 系统
events.SYSTEM_CLOCK    # "system_clock"
events.SYSTEM_SHUTDOWN # "system_shutdown"
```

---

### `tyche.heartbeat` — 心跳机制

Paranoid Pirate Pattern 实现，提供可靠的节点存活检测。

```python
from tyche.heartbeat import HeartbeatManager, HeartbeatMonitor, HeartbeatSender

# 引擎端：管理多个模块的心跳
manager = HeartbeatManager(interval=1.0, liveness=3)
manager.register("module_abc")
manager.update("module_abc")       # 收到心跳
expired = manager.tick_all()       # 返回超时模块列表

# 模块端：发送心跳
sender = HeartbeatSender(socket, module_id, interval=1.0)
if sender.should_send():
    sender.send()

# 单节点监控
monitor = HeartbeatMonitor(interval=1.0, liveness=3)
monitor.update()
monitor.tick()
is_dead = monitor.is_expired()
```

**常量**：
- `HEARTBEAT_INTERVAL = 1.0` — 心跳间隔（秒）
- `HEARTBEAT_LIVENESS = 3` — 允许丢失次数（超过视为离线）
- 注册时有初始宽限期（liveness × 2）

## 安装方式

```bash
# 从 PyPI 安装（稳定版）
pip install tyche-core

# 从源码安装（开发模式）
cd tyche-core
pip install -e ".[dev]"
```

## 版本兼容性规则

| 变更类型 | 版本号影响 | 示例 |
|---------|----------|------|
| 新增公共类/函数 | 次版本 +1 | 新增 `MetricsCollector` 类 |
| 新增枚举值 | 次版本 +1 | MessageType 新增 `BATCH` |
| 删除或重命名公共 API | 主版本 +1 | 移除 `send_event` 参数 |
| 修改 Message 序列化格式 | 主版本 +1 | 字段键名变更 |
| 修改事件常量值 | 主版本 +1 | `QUOTE` 从 `"quote"` 改为 `"q"` |
| 修复 Bug（不改变接口） | 修订号 +1 | 内存泄漏修复 |

## Python 版本要求

- **最低**: Python 3.9
- **推荐**: Python 3.11+（性能更优）
- **依赖**:
  - `pyzmq` ≥ 25.0
  - `msgpack` ≥ 1.0
